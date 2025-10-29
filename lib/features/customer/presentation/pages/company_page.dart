import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../Core/services/user_service.dart';
import '../../../../core/services/cart_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/category_service.dart';
import '../../../../core/services/cart_item_service.dart';
import '../../../../core/services/review_service.dart';
import '../widgets/product_card.dart';
import 'product_detail_page.dart';

class CompanyPage extends StatefulWidget {
  final int companyId;

  const CompanyPage({required this.companyId, super.key});

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> with TickerProviderStateMixin {
  // Services
  final CompanyService _companyService = CompanyService();
  final AttachmentService _attachmentService = AttachmentService();
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();
  final CartItemService _cartItemService = CartItemService('http://192.168.1.216:8080');
  final UserService _userService = UserService('http://192.168.1.216:8080');
  final ReviewService _reviewService = ReviewService();

  // State variables
  Map<String, dynamic>? _company;
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [];
  List<Uint8List> _companyImages = [];
  Map<int, Uint8List> _productImages = {};
  List<Map<String, dynamic>> _reviews = [];

  bool _isLoading = true;
  bool _showFilters = false;
  bool _showOnlyAvailable = false;

  int _selectedImageIndex = 0;
  int _cartItemCount = 0;
  int? _selectedCategoryId;

  String _sortBy = 'latest';
  String _gridViewType = 'grid';
  double _rating = 5.0;

  // Controllers
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  static const int currentUserId = 1; // Current logged-in user ID
  bool _isLoadingReviews = false;
  bool _isSubmittingReview = false;
  bool _isEditingReview = false;

// Review state
  int? _userRating;
  Map<String, dynamic>? _userReview;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _searchController.addListener(_applyFilters);
    _loadCompanyData();
    _loadCartItemCount();
  }

  void _initializeControllers() {
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _reviewController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================================
  // DATA LOADING METHODS
  // ============================================================================

  Future<void> _loadCartItemCount() async {
    try {
      final cart = await CartService().getCartByUserId(currentUserId);
      if (cart != null && mounted) {
        final cartItems = (cart['cartItems'] as List<dynamic>?)?.length ?? 0;
        setState(() => _cartItemCount = cartItems);
      }
    } catch (e) {
      debugPrint('❌ Error loading cart count: $e');
    }
  }

  Future<void> _loadCompanyData() async {
    try {
      final company = await _companyService.getCompanyProducts(widget.companyId);

      if (company == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        setState(() {
          _company = company;
          _allProducts = (company['products'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ?? [];
          _filteredProducts = List.from(_allProducts);
        });
      }

      await Future.wait([
        _loadReviews(),
        _loadCategories(),
        _loadCompanyImages(),
        _loadProductImages(),
      ]);

      _fadeController.forward();
      if (mounted) setState(() => _isLoading = false);
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading company data: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReviews() async {
    try {
      final companyWithReviews = await _companyService.findByCompanyIdWithReviews(widget.companyId);

      if (mounted && companyWithReviews != null) {
        final reviewsData = companyWithReviews['reviews'];

        if (reviewsData is List) {
          final reviews = reviewsData
              .where((item) => item != null && item is Map)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

          // Load user details for each review
          for (var review in reviews) {
            final userId = review['userId'];
            if (userId != null) {
              try {
                final user = await _userService.getUserById(userId);
                if (user != null) {
                  review['fullName'] = user['fullName'] ?? 'Utilisateur';
                }
              } catch (e) {
                review['fullName'] = 'Utilisateur';
              }
            }
          }

          // Find user's review
          final userReview = reviews.firstWhere(
                (r) => r['userId'] == currentUserId,
            orElse: () => <String, dynamic>{},
          );

          if (mounted) {
            setState(() {
              _reviews = reviews;
              if (userReview.isNotEmpty) {
                _userReview = userReview;
                _userRating = userReview['rating'];
                _reviewController.text = userReview['comment'] ?? userReview['comment'] ?? '';
              }
            });
          }
        } else {
          if (mounted) setState(() => _reviews = []);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading reviews: $e');
      if (mounted) setState(() => _reviews = []);
    }
  }
  Future<void> _refreshReviews() async {
    setState(() => _isLoadingReviews = true);
    try {
      final companyWithReviews = await _companyService.findByCompanyIdWithReviews(widget.companyId);

      if (companyWithReviews != null) {
        final reviewsData = companyWithReviews['reviews'];

        if (reviewsData is List) {
          final reviews = reviewsData
              .where((item) => item != null && item is Map)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

          for (var review in reviews) {
            final userId = review['userId'];
            if (userId != null) {
              try {
                final user = await _userService.getUserById(userId);
                if (user != null) {
                  review['fullName'] = user['fullName'] ?? 'Utilisateur';
                }
              } catch (e) {
                review['fullName'] = 'Utilisateur';
              }
            }
          }

          final userReview = reviews.firstWhere(
                (r) => r['userId'] == currentUserId,
            orElse: () => <String, dynamic>{},
          );

          if (mounted) {
            setState(() {
              _reviews = reviews;
              _userReview = userReview.isNotEmpty ? userReview : null;
              if (_userReview != null) {
                _userRating = _userReview!['rating'];
                _reviewController.text = _userReview!['comment'] ?? _userReview!['comment'] ?? '';
              } else {
                _userRating = null;
                _reviewController.clear();
              }
              _isEditingReview = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur de rafraîchissement des avis: $e', isError: true);
      }
    } finally {
      setState(() => _isLoadingReviews = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final companyWithCategories = await _companyService.findByCompanyIdWithCategories(widget.companyId);

      if (mounted && companyWithCategories != null) {
        final categoriesData = companyWithCategories['categories'];

        if (categoriesData is List) {
          final categories = categoriesData
              .where((item) => item != null && item is Map)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

          if (mounted) {
            setState(() => _categories = categories);
            debugPrint('✅ Loaded ${categories.length} categories');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading categories: $e');
      if (mounted) setState(() => _categories = []);
    }
  }

  Future<void> _loadCompanyImages() async {
    try {
      if (_company == null) return;

      final attachments = await _attachmentService.getAttachmentsByEntity('COMPANY', widget.companyId);
      final List<Uint8List> images = [];

      for (var attach in attachments) {
        try {
          final attachmentId = attach['attachmentId'];
          if (attachmentId != null) {
            final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
            images.add(attachmentDownload.data);
          }
        } catch (e) {
          debugPrint('⚠️ Error downloading company attachment: $e');
        }
      }

      if (mounted) setState(() => _companyImages = images);
    } catch (e) {
      debugPrint('❌ Error loading company images: $e');
    }
  }

  Future<void> _loadProductImages() async {
    try {
      final Map<int, Uint8List> images = {};

      for (var product in _allProducts) {
        final productId = product['productId'] as int?;
        if (productId == null) continue;

        try {
          final attachments = await _attachmentService.findByProductProductId(productId);
          if (attachments.isNotEmpty) {
            final firstAttachment = attachments.first as Map<String, dynamic>;
            final attachmentId = firstAttachment['attachmentId'] as int?;

            if (attachmentId != null) {
              final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
              images[productId] = attachmentDownload.data;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error loading image for product $productId: $e');
        }
      }

      if (mounted) setState(() => _productImages = images);
    } catch (e) {
      debugPrint('❌ Error loading product images: $e');
    }
  }

  // ============================================================================
  // FILTER & SORT METHODS
  // ============================================================================

  void _applyFilters() {
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final productName = (product['productName'] ?? '').toString().toLowerCase();
        final searchQuery = _searchController.text.toLowerCase();
        final matchesSearch = searchQuery.isEmpty || productName.contains(searchQuery);

        final matchesCategory = _selectedCategoryId == null ||
            product['categoryId'] == _selectedCategoryId;

        final isAvailable = product['available'] == true || product['available'] == 1;
        final matchesAvailability = !_showOnlyAvailable || isAvailable;

        return matchesSearch && matchesCategory && matchesAvailability;
      }).toList();

      _sortProducts();
    });
  }

  void _sortProducts() {
    switch (_sortBy) {
      case 'price_low':
        _filteredProducts.sort((a, b) =>
            (a['productPrice'] ?? 0).compareTo(b['productPrice'] ?? 0));
        break;
      case 'price_high':
        _filteredProducts.sort((a, b) =>
            (b['productPrice'] ?? 0).compareTo(a['productPrice'] ?? 0));
        break;
      case 'popular':
        _filteredProducts.sort((a, b) =>
            (b['rating'] ?? 0).compareTo(a['rating'] ?? 0));
        break;
      default:
        break;
    }
  }

  // ============================================================================
  // ACTION METHODS - REVIEWS
  // ============================================================================

  Future<void> _submitReview() async {
    debugPrint('🔍 [REVIEW] Starting _submitReview method');
    
    if ((_userRating == null || _userRating == 0) && _reviewController.text.trim().isEmpty) {
      debugPrint('❌ [REVIEW] Validation failed: No rating or comment provided');
      _showSnackBar('Veuillez fournir une note ou un commentaire', isError: true, icon: Icons.warning_amber_rounded);
      return;
    }

    setState(() => _isSubmittingReview = true);
    try {
      debugPrint('📝 [REVIEW] Preparing review data...');
      final reviewData = {
        'rating': _userRating ?? 0,
        'comment': _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
        'companyId': widget.companyId,
        'userId': currentUserId,
      };
      
      debugPrint('📋 [REVIEW] Review data prepared: $reviewData');
      debugPrint('🔄 [REVIEW] User review exists: ${_userReview != null}');

      if (_userReview == null) {
        debugPrint('➕ [REVIEW] Creating new review...');
        await _reviewService.createReview(reviewData);
        debugPrint('✅ [REVIEW] Review created successfully');
      } else {
        debugPrint('✏️ [REVIEW] Updating existing review with ID: ${_userReview!['reviewId']}');
        await _reviewService.updateReview(_userReview!['reviewId'], reviewData);
        debugPrint('✅ [REVIEW] Review updated successfully');
      }

      debugPrint('🔄 [REVIEW] Refreshing reviews...');
      await _refreshReviews();
      debugPrint('✅ [REVIEW] Reviews refreshed successfully');

      if (mounted) {
        _showSnackBar(
          _userReview == null ? 'Avis publié avec succès' : 'Avis mis à jour avec succès',
          icon: Icons.check_circle,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [REVIEW] Error in _submitReview: $e');
      debugPrint('📍 [REVIEW] Stack trace: $stackTrace');
      if (mounted) {
        _showSnackBar('Erreur: $e', isError: true);
      }
    } finally {
      debugPrint('🏁 [REVIEW] Finishing _submitReview method');
      setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _deleteReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'avis', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet avis ? Cette action est irréversible.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || _userReview == null) return;

    try {
      await _reviewService.deleteReview(_userReview!['reviewId']);
      setState(() {
        _userReview = null;
        _userRating = null;
        _reviewController.clear();
        _isEditingReview = false;
      });
      await _refreshReviews();

      if (mounted) {
        _showSnackBar('Avis supprimé avec succès', icon: Icons.check_circle);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur lors de la suppression: $e', isError: true);
      }
    }
  }
  double _calculateAverageRating() {
    if (_reviews.isEmpty) return 0.0;
    final validReviews = _reviews.where((r) => r['rating'] != null && r['rating'] > 0).toList();
    if (validReviews.isEmpty) return 0.0;
    final sum = validReviews.fold<int>(0, (sum, review) => sum + (review['rating'] as int));
    return sum / validReviews.length;
  }
  bool _isUserReview(Map<String, dynamic> review) {
    final reviewUserId = review['userId'] as int?;
    return reviewUserId == currentUserId;
  }

  // ============================================================================
  // ACTION METHODS - CART
  // ============================================================================

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final productId = product['productId'] as int?;
    if (productId == null) return;

    try {
      await _cartItemService.createCartItem({
        'productId': productId,
        'quantity': 1,
        'cartId': 1,
      });

      setState(() => _cartItemCount++);

      if (mounted) {
        _showSnackBar(
            '${product['productName'] ?? 'Produit'} ajouté au panier',
            icon: Icons.check_circle
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur lors de l\'ajout au panier', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false, IconData? icon}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                icon ?? (isError ? Icons.error_outline : Icons.check_circle),
                color: Colors.white
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                )
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================================
  // UI BUILD METHODS
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_company == null) {
      return _buildErrorState();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildCompanyInfo(),
                    _buildTabSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chargement de l\'entreprise...',
              style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w500
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Entreprise'),
        backgroundColor: AppColors.primary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Entreprise non trouvée',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600]
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: _buildAppBarButton(
        icon: Icons.arrow_back,
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        _buildCartButton(),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildAppBarBackground(),
      ),
    );
  }

  Widget _buildAppBarButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCartButton() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
            if (_cartItemCount > 0)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Colors.red[400]!, Colors.red[600]!]
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 8
                      )
                    ],
                  ),
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  child: Text(
                    '$_cartItemCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        onPressed: () {},
      ),
    );
  }

  Widget _buildAppBarBackground() {
    if (_companyImages.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.6)],
          ),
        ),
        child: Center(
          child: Icon(
              Icons.business,
              size: 100,
              color: Colors.white.withOpacity(0.3)
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          itemCount: _companyImages.length,
          onPageChanged: (index) => setState(() => _selectedImageIndex = index),
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                ),
              ),
              child: Image.memory(
                  _companyImages[index],
                  fit: BoxFit.cover,
                  width: double.infinity
              ),
            );
          },
        ),
        if (_companyImages.length > 1) _buildImageIndicators(),
      ],
    );
  }

  Widget _buildImageIndicators() {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _companyImages.asMap().entries.map((entry) {
          final isSelected = _selectedImageIndex == entry.key;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isSelected ? 32 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isSelected ? Colors.white : Colors.white54,
              boxShadow: isSelected ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                )
              ] : null,
            ),
          );
        }).toList(),
      ),
    );
  }
  bool _isCompanyOpen(String? timeOpen, String? timeClose) {
    if (timeOpen == null || timeClose == null) return true; // Default to open if no times

    try {
      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);

      // Parse times - handle both "HH:mm" and "HH:mm:ss" formats
      final openParts = timeOpen.split(':');
      final closeParts = timeClose.split(':');

      final open = TimeOfDay(
        hour: int.parse(openParts[0]),
        minute: int.parse(openParts[1]),
      );

      final close = TimeOfDay(
        hour: int.parse(closeParts[0]),
        minute: int.parse(closeParts[1]),
      );

      // Convert to minutes for easier comparison
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final openMinutes = open.hour * 60 + open.minute;
      final closeMinutes = close.hour * 60 + close.minute;

      // Handle case where closing time is next day (e.g., 23:00 to 06:00)
      if (closeMinutes < openMinutes) {
        return currentMinutes >= openMinutes || currentMinutes < closeMinutes;
      } else {
        return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
      }
    } catch (e) {
      debugPrint('Error checking company hours: $e');
      return true; // Default to open if parsing fails
    }
  }
  Widget _buildCompanyInfo() {
    final averageRating = _company!['averageRating'] as double? ?? 0.0;
    final companyStatus = _company!['companyStatus']?.toString() ?? 'Active';
    final companyName = _company!['companyName']?.toString() ?? 'Entreprise';
    final companySector = _company!['companySector']?.toString() ?? 'Secteur non spécifié';
    final companyDescription = _company!['companyDescription']?.toString();
    final companyPhone = _company!['companyPhone']?.toString();
    final companyAddress = _company!['companyAddress']?.toString();
    final timeOpen = _company!['timeOpen']?.toString();
    final timeClose = _company!['timeClose']?.toString();

    // Check if company is currently open
    final isOpen = _isCompanyOpen(timeOpen, timeClose);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4)
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Colors.blue[50]!, Colors.blue[100]!]
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!, width: 1),
                      ),
                      child: Text(
                        companySector,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w600
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: isOpen
                          ? [Colors.green[50]!, Colors.green[100]!]
                          : [Colors.red[50]!, Colors.red[100]!]
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isOpen ? Colors.green[300]! : Colors.red[300]!,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: isOpen ? Colors.green[400] : Colors.red[400],
                          shape: BoxShape.circle
                      ),
                      child: Icon(
                        isOpen ? Icons.check : Icons.close,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOpen ? 'Ouvert' : 'Fermé',
                      style: TextStyle(
                        color: isOpen ? Colors.green[700] : Colors.red[700],
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (companyDescription != null && companyDescription.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              companyDescription,
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.6,
                  fontWeight: FontWeight.w500
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.star_rounded,
                  iconColor: Colors.amber[600]!,
                  backgroundColor: Colors.amber[50]!,
                  borderColor: Colors.amber[200]!,
                  title: averageRating.toStringAsFixed(1),
                  subtitle: '${_reviews.length} avis',
                ),
              ),
              if (companyPhone != null && companyPhone.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.phone,
                    iconColor: Colors.blue[600]!,
                    backgroundColor: Colors.blue[50]!,
                    borderColor: Colors.blue[200]!,
                    title: companyPhone,
                    isPhone: true,
                  ),
                ),
              ],
            ],
          ),
          if (timeOpen != null && timeClose != null) ...[
            const SizedBox(height: 14),
            _buildInfoCard(
              icon: Icons.access_time_rounded,
              iconColor: Colors.purple[600]!,
              backgroundColor: Colors.purple[50]!,
              borderColor: Colors.purple[200]!,
              title: '$timeOpen - $timeClose',
              subtitle: isOpen ? 'Actuellement ouvert' : 'Actuellement fermé',
              isFullWidth: true,
            ),
          ],
          if (companyAddress != null && companyAddress.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildInfoCard(
              icon: Icons.location_on_rounded,
              iconColor: Colors.red[600]!,
              backgroundColor: Colors.red[50]!,
              borderColor: Colors.red[200]!,
              title: companyAddress,
              isFullWidth: true,
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required String title,
    String? subtitle,
    bool isPhone = false,
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: isFullWidth ? 18 : 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isPhone || isFullWidth ? 13 : 18
                  ),
                  maxLines: isFullWidth ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w600
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2)
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.primary.withOpacity(0.1),
              ),
              padding: const EdgeInsets.all(6),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                          'BOUTIQUE',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5
                          )
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rate_review_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                          'AVIS',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5
                          )
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 650,
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildShopTab(),
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopTab() {
    return Column(
      children: [
        _buildSearchBar(),
        const SizedBox(height: 16),
        _buildFilterBar(),
        const SizedBox(height: 16),
        Expanded(
          child: _filteredProducts.isEmpty
              ? _buildEmptyProductsState()
              : _gridViewType == 'grid'
              ? _buildProductGrid()
              : _buildProductList(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12
          )
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher des produits...',
          hintStyle: TextStyle(
              color: Colors.grey[500],
              fontWeight: FontWeight.w500
          ),
          prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.grey[500],
              size: 24
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear_rounded, color: Colors.grey[500]),
            onPressed: () {
              _searchController.clear();
              _applyFilters();
            },
          )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
        ),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: 'Tous',
                selected: _selectedCategoryId == null,
                onTap: () {
                  setState(() => _selectedCategoryId = null);
                  _applyFilters();
                },
                icon: Icons.apps_rounded,
              ),
              ..._categories.map((category) {
                final categoryId = category['categoryId'] as int?;
                final categoryName = category['name']?.toString() ?? 'Catégorie';
                return _buildFilterChip(
                  label: categoryName,
                  selected: _selectedCategoryId == categoryId,
                  onTap: () {
                    setState(() => _selectedCategoryId = categoryId);
                    _applyFilters();
                  },
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildSortDropdown()),
            const SizedBox(width: 12),
            _buildViewToggle(),
            const SizedBox(width: 12),
            _buildAvailabilityFilter(),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  AppColors.primary.withOpacity(0.05)
                ]
            )
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary.withOpacity(0.4) : Colors.grey[200]!,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 8
              )
            ]
                : [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                    icon,
                    size: 18,
                    color: selected ? AppColors.primary : Colors.grey[600]
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : Colors.grey[700],
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8
          )
        ],
      ),
      child: DropdownButton<String>(
        value: _sortBy,
        isExpanded: true,
        underline: Container(),
        icon: Icon(Icons.unfold_more_rounded, color: AppColors.primary, size: 20),
        items: const [
          DropdownMenuItem(value: 'latest', child: Text('Plus récent')),
          DropdownMenuItem(value: 'price_low', child: Text('Prix: bas à haut')),
          DropdownMenuItem(value: 'price_high', child: Text('Prix: haut à bas')),
          DropdownMenuItem(value: 'popular', child: Text('Populaire')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _sortBy = value);
            _applyFilters();
          }
        },
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
                Icons.dashboard_rounded,
                color: _gridViewType == 'grid' ? AppColors.primary : Colors.grey[400],
                size: 20
            ),
            onPressed: () => setState(() => _gridViewType = 'grid'),
            splashRadius: 20,
          ),
          Container(width: 1, height: 20, color: Colors.grey[300]),
          IconButton(
            icon: Icon(
                Icons.list_rounded,
                color: _gridViewType == 'list' ? AppColors.primary : Colors.grey[400],
                size: 20
            ),
            onPressed: () => setState(() => _gridViewType = 'list'),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityFilter() {
    return FilterChip(
      label: const Text('Disponible'),
      selected: _showOnlyAvailable,
      onSelected: (selected) {
        setState(() => _showOnlyAvailable = selected);
        _applyFilters();
      },
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary.withOpacity(0.2),
      side: BorderSide(
        color: _showOnlyAvailable ? AppColors.primary : Colors.grey[200]!,
        width: _showOnlyAvailable ? 2 : 1,
      ),
      labelStyle: TextStyle(
        color: _showOnlyAvailable ? AppColors.primary : Colors.grey[600],
        fontWeight: _showOnlyAvailable ? FontWeight.w700 : FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  Widget _buildEmptyProductsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: Colors.grey[400]
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucun produit trouvé',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600]
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez d\'ajuster vos filtres',
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.52,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final productId = product['productId'] as int?;
        final productImage = productId != null ? _productImages[productId] : null;

        return ProductCard(
          name: product['productName']?.toString() ?? 'Produit',
          price: (product['productPrice'] ?? 0).toDouble(),
          imageBytes: productImage,
          discount: (product['discountPercentage'] ?? 0).toDouble(),
          finalPrice: product['productFinalePrice'],
          isAvailable: product['available'] == true || product['available'] == 1,
          onTap: () {
            if (productId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailPage(productId: productId),
                ),
              ).then((_) => _loadCartItemCount());
            }
          },
          onAddToCart: () => _addToCart(product),
        );
      },
    );
  }

  Widget _buildProductList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final productId = product['productId'] as int?;
        final productImage = productId != null ? _productImages[productId] : null;

        return _buildProductListItem(product, productId, productImage);
      },
    );
  }

  Widget _buildProductListItem(
      Map<String, dynamic> product,
      int? productId,
      Uint8List? productImage,
      ) {
    final productName = product['productName']?.toString() ?? 'Produit';
    final productPrice = (product['productPrice'] ?? 0).toDouble();
    final discountPercentage = (product['discountPercentage'] ?? 0).toDouble();
    final isAvailable = product['available'] == true || product['available'] == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: productImage != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(productImage, fit: BoxFit.cover),
            )
                : Icon(Icons.image, color: Colors.grey[300], size: 40),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${productPrice.toStringAsFixed(2)} DT',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    if (discountPercentage > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Colors.red[50]!, Colors.red[100]!]
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red[300]!, width: 1),
                        ),
                        child: Text(
                          '-${discountPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.red[600]
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isAvailable ? Colors.green[300]! : Colors.red[300]!,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isAvailable ? 'En stock' : 'Rupture',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isAvailable ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  if (productId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailPage(productId: productId),
                      ),
                    ).then((_) => _loadCartItemCount());
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: 20
                  ),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _addToCart(product),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)]
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8
                      ),
                    ],
                  ),
                  child: const Icon(
                      Icons.add_shopping_cart_rounded,
                      color: Colors.white,
                      size: 20
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildUserReviewSection(),
          const SizedBox(height: 24),
          if (_reviews.isNotEmpty)
            Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[200]!, Colors.grey[100]!],
                ),
              ),
            ),
          const SizedBox(height: 24),
          if (_isLoadingReviews)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
              ),
            )
          else if (_reviews.isEmpty)
            _buildEmptyReviewsState()
          else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Autres avis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildReviewsList(),
            ],
        ],
      ),
    );
  }
  Widget _buildEmptyReviewsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle
            ),
            child: Icon(
                Icons.rate_review_outlined,
                size: 64,
                color: Colors.grey[400]
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucun avis pour le moment',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600]
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Soyez le premier à partager votre avis!',
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    final otherReviews = _reviews.where((r) => r['userId'] != currentUserId).toList();

    if (otherReviews.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Aucun autre avis',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: otherReviews.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final review = otherReviews[index];
          return _buildReviewItem(review, false);
        },
      ),
    );
  }
  void _showAddReviewDialog() {
    double tempRating = _rating;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
              'Ajouter un avis',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22
              )
          ),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                        'Votre note:',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16
                        )
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        return IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: Icon(
                            Icons.star_rounded,
                            size: 32,
                            color: i < tempRating ? Colors.amber : Colors.grey[300],
                          ),
                          onPressed: () {
                            setDialogState(() {
                              tempRating = (i + 1).toDouble();
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _reviewController,
                  decoration: InputDecoration(
                    hintText: 'Partagez votre expérience...',
                    hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.5
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 4,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Annuler',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w700,
                    fontSize: 15
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _rating = tempRating;
                _addReview(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12
                ),
                elevation: 3,
              ),
              child: const Text(
                  'Publier',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15
                  )
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditReviewDialog(Map<String, dynamic> review) {
    // Pre-fill with existing review data
    final existingComment = review['comment']?.toString() ??
        review['reviewComment']?.toString() ?? '';
    final existingRating = review['rating'] is num
        ? (review['rating'] as num).toDouble()
        : 5.0;

    _reviewController.text = existingComment;
    double tempRating = existingRating;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
              'Modifier votre avis',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22
              )
          ),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                        'Votre note:',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16
                        )
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        return IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          icon: Icon(
                            Icons.star_rounded,
                            size: 32,
                            color: i < tempRating ? Colors.amber : Colors.grey[300],
                          ),
                          onPressed: () {
                            setDialogState(() {
                              tempRating = (i + 1).toDouble();
                            });
                          },
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _reviewController,
                  decoration: InputDecoration(
                    hintText: 'Partagez votre expérience...',
                    hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.5
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 4,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _reviewController.clear();
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Annuler',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w700,
                    fontSize: 15
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _rating = tempRating;
                _updateReview(review, dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12
                ),
                elevation: 3,
              ),
              child: const Text(
                  'Mettre à jour',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15
                  )
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addReview(BuildContext dialogContext) async {
    if (_reviewController.text.trim().isEmpty && _rating == 0) {
      _showSnackBar('Veuillez fournir une note ou un commentaire', isError: true);
      return;
    }

    try {
      final reviewData = {
        'rating': _rating.toInt(),
        'comment': _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
        'companyId': widget.companyId,
        'userId': currentUserId,
      };

      await _reviewService.createReview(reviewData);
      Navigator.pop(dialogContext);
      await _refreshReviews();
      _showSnackBar('Avis publié avec succès', icon: Icons.check_circle);
    } catch (e) {
      _showSnackBar('Erreur: $e', isError: true);
    }
  }

  Future<void> _updateReview(Map<String, dynamic> review, BuildContext dialogContext) async {
    try {
      final reviewData = {
        'rating': _rating.toInt(),
        'comment': _reviewController.text.trim().isEmpty ? null : _reviewController.text.trim(),
        'companyId': widget.companyId,
        'userId': currentUserId,
      };

      await _reviewService.updateReview(review['reviewId'], reviewData);
      Navigator.pop(dialogContext);
      await _refreshReviews();
      _showSnackBar('Avis mis à jour avec succès', icon: Icons.check_circle);
    } catch (e) {
      _showSnackBar('Erreur: $e', isError: true);
    }
  }

  Widget _buildUserReviewSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.rate_review_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Votre avis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_userReview != null) ...[
            _buildReviewItem(_userReview!, true),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vous n\'avez pas encore donné d\'avis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Partagez votre expérience avec cette entreprise',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddReviewDialog,
                    icon: const Icon(Icons.add_comment_rounded, size: 18),
                    label: const Text('Ajouter un avis'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewItem(Map<String, dynamic> review, bool isUserReview) {
    final rating = review['rating'] is num ? (review['rating'] as num).toInt() : 0;
    final comment = review['comment']?.toString() ?? review['comment']?.toString() ?? '';
    final userName = review['fullName']?.toString() ?? 'Utilisateur';
    final reviewDate = review['reviewDate']?.toString() ?? review['createdAt']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUserReview ? AppColors.primary.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUserReview ? AppColors.primary.withOpacity(0.2) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isUserReview ? AppColors.primary.withOpacity(0.1) : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: isUserReview ? AppColors.primary : Colors.grey[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (reviewDate != null)
                      Text(
                        _formatReviewDate(reviewDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              if (isUserReview) ...[
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditReviewDialog(review);
                    } else if (value == 'delete') {
                      _deleteReview();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Modifier'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Supprimer', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(
                    Icons.more_vert_rounded,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                Icons.star_rounded,
                size: 18,
                color: index < rating ? Colors.amber : Colors.grey[300],
              );
            }),
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatReviewDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'À l\'instant';
      }
    } catch (e) {
      return 'Date inconnue';
    }
  }
}