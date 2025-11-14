import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../Core/services/user_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../../../../core/services/cart_item_service.dart';
import '../../../../core/services/review_service.dart';
import '../../../../core/services/cart_notifier.dart';
import '../../../../core/services/auth_service.dart';
import '../widgets/product_list_item.dart';

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
  final CartItemService _cartItemService = CartItemService();
  final UserService _userService = UserService();
  final ReviewService _reviewService = ReviewService();
  final CartNotifier _cartNotifier = CartNotifier();
  final AuthService _authService = AuthService();

  // State variables
  Map<String, dynamic>? _company;
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [];
  List<Uint8List> _companyImages = [];
  Map<int, Uint8List> _productImages = {};
  List<Map<String, dynamic>> _reviews = [];
  
  // Category-based state
  Map<int?, List<Map<String, dynamic>>> _productsByCategory = {};
  List<int?> _categoryOrder = [];
  final ScrollController _productScrollController = ScrollController();
  String? _currentScrollCategory;

  bool _isLoading = true;
  bool _showFilters = false;

  int _selectedImageIndex = 0;
  int? _selectedCategoryId;

  String _sortBy = 'latest';

  double _rating = 5.0;

  // Controllers
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  int? _currentUserId;
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
    _productScrollController.addListener(_updateCurrentCategory);

    // Load user and company data in parallel - FASTER
    Future.wait([
      _initializeUser(),
    ]);
  }

  Future<void> _initializeUser() async {
    _currentUserId = await _authService.getUserId();
    _loadCompanyData();
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
    _filterDebounce?.cancel(); // ADD THIS LINE
    _tabController.dispose();
    _fadeController.dispose();
    _reviewController.dispose();
    _searchController.dispose();
    _productScrollController.dispose();
    super.dispose();
  }

  // ============================================================================
  // DATA LOADING METHODS
  // ============================================================================


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

      // Load categories FIRST, then other data
      await _loadCategories();

      // Load all other data in parallel
      await Future.wait([
        _loadReviews(),
        _loadCompanyImages(),
        _loadProductImages(),
      ], eagerError: false);

      // Now apply filters and group by category
      _applyFilters();
      _fadeController.forward();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error loading company data: $e');
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
          final userReview = _currentUserId != null ? reviews.firstWhere(
                (r) => r['userId'] == _currentUserId,
            orElse: () => <String, dynamic>{},
          ) : <String, dynamic>{};

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

          final userReview = _currentUserId != null ? reviews.firstWhere(
                (r) => r['userId'] == _currentUserId,
            orElse: () => <String, dynamic>{},
          ) : <String, dynamic>{};

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

            // Debug: Print all category IDs and names
            for (var category in categories) {
              debugPrint('📌 Category - ID: ${category['categoryId']}, Name: ${category['name']}');
            }

            // Debug: Check which product categories don't have matching category records
            final productCategoryIds = _allProducts
                .map((p) => p['categoryId'] as int?)
                .toSet();

            final categoryCategoryIds = _categories
                .map((c) => c['categoryId'] as int?)
                .toSet();

            final missingCategories = productCategoryIds.difference(categoryCategoryIds);
            if (missingCategories.isNotEmpty) {
              debugPrint('⚠️ Products reference these category IDs that don\'t exist: $missingCategories');
            }
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

      // Process images with concurrent requests (limit to 5 at a time)
      const int maxConcurrent = 5;
      for (int i = 0; i < _allProducts.length; i += maxConcurrent) {
        final batch = _allProducts.skip(i).take(maxConcurrent);
        await Future.wait(
          batch.map((product) async {
            final productId = product['productId'] as int?;
            if (productId == null) return;

            try {
              final attachments = await _attachmentService.findByProductProductId(productId);
              if (attachments.isNotEmpty) {
                final firstAttachment = attachments.first as Map<String, dynamic>;
                final attachmentId = firstAttachment['attachmentId'] as int?;

                if (attachmentId != null) {
                  final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
                  if (attachmentDownload.data.isNotEmpty) {
                    images[productId] = attachmentDownload.data;
                  }
                }
              }
            } catch (e) {
              debugPrint('⚠️ Error loading image for product $productId: $e');
            }
          }),
          eagerError: false,
        );
      }

      if (mounted) setState(() => _productImages = images);
    } catch (e) {
      debugPrint('❌ Error loading product images: $e');
    }
  }

  // ============================================================================
  // FILTER & SORT METHODS
  // ============================================================================

  Timer? _filterDebounce;

  void _applyFilters() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      setState(() {
        _filteredProducts = _allProducts.where((product) {
          final productName = (product['productName'] ?? '').toString().toLowerCase();
          final searchQuery = _searchController.text.toLowerCase();
          final matchesSearch = searchQuery.isEmpty || productName.contains(searchQuery);

          final productCategoryId = product['categoryId'] as int?;
          final matchesCategory = _selectedCategoryId == null || productCategoryId == _selectedCategoryId;

          return matchesSearch && matchesCategory;
        }).toList();

        _sortProducts();
        _groupProductsByCategory();
      });
    });
  }

  void _groupProductsByCategory() {
    _productsByCategory.clear();
    _categoryOrder.clear();

    for (var product in _filteredProducts) {
      final categoryId = product['categoryId'] as int?;

      // Check if this category ID exists in our categories list
      final categoryExists = _categories.any((c) => c['categoryId'] == categoryId);

      // Only add products that have valid categories
      if (categoryExists) {
        if (!_productsByCategory.containsKey(categoryId)) {
          _productsByCategory[categoryId] = [];
          _categoryOrder.add(categoryId);
        }
        _productsByCategory[categoryId]!.add(product);
      } else {
        // Log orphaned products
        debugPrint('⚠️ Skipping product "${product['productName']}" - Category ID $categoryId does not exist');
      }
    }

    // Debug output
    debugPrint('🔍 Product grouping (filtered):');
    for (var categoryId in _categoryOrder) {
      final count = _productsByCategory[categoryId]?.length ?? 0;
      final name = _getCategoryName(categoryId);
      debugPrint('  - $name (ID: $categoryId): $count products');
    }
  }
  String _getCategoryName(int? categoryId) {
    if (categoryId == null) return 'Sans catégorie';

    try {
      // Search for the category
      final category = _categories.firstWhere(
            (c) => c['categoryId'] == categoryId,
        orElse: () => <String, dynamic>{},
      );

      if (category.isEmpty) {
        debugPrint('⚠️ Category not found for ID: $categoryId');
        debugPrint('📋 Available categories: ${_categories.map((c) => 'ID: ${c['categoryId']}, Name: ${c['name']}').join(', ')}');
        return 'Catégorie inconnue';
      }

      final name = category['name']?.toString().trim();
      if (name == null || name.isEmpty) {
        return 'Catégorie inconnue';
      }

      return name;
    } catch (e) {
      debugPrint('❌ Error getting category name: $e');
      return 'Catégorie inconnue';
    }
  }

  void _updateCurrentCategory() {
    if (_productsByCategory.isEmpty) return;

    final scrollOffset = _productScrollController.offset;
    double currentOffset = 0.0;
    
    for (final categoryId in _categoryOrder) {
      final products = _productsByCategory[categoryId] ?? [];
      final categoryHeaderHeight = 60.0;
      final productItemHeight = 124.0;
      final categoryHeight = categoryHeaderHeight + (products.length * productItemHeight);
      
      if (scrollOffset >= currentOffset && scrollOffset < currentOffset + categoryHeight) {
        final categoryName = _getCategoryName(categoryId);
        if (mounted && categoryName != _currentScrollCategory) {
          setState(() {
            _currentScrollCategory = categoryName;
            _selectedCategoryId = categoryId;
          });
        }
        break;
      }
      currentOffset += categoryHeight;
    }
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
        'userId': _currentUserId,
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
    return reviewUserId == _currentUserId;
  }


  Future<void> _addToCart(Map<String, dynamic> product) async {
    final productId = product['productId'] as int?;
    if (productId == null) return;

    try {
      // Call backend to add product to the user's cart
      if (_currentUserId == null) return;

      await _cartItemService.addProductToUserCart(_currentUserId!, {
        'productId': productId,
        'quantity': 1,
      });

      // Notify cart changed
      _cartNotifier.notifyCartChanged();

      if (mounted) {
        _showSnackBar(
          '${product['productName'] ?? 'Produit'} ajouté au panier',
          icon: Icons.check_circle,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Erreur lors de l\'ajout au panier',
          isError: true,
        );
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
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Skeletonizer(
          enabled: true,
          child: CustomScrollView(
            slivers: [
              _buildSkeletonSliverAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildSkeletonCompanyInfo(),
                    _buildSkeletonTabSection(),
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
  bool _isCompanyOpen(dynamic timeOpen, dynamic timeClose) {
    if (timeOpen == null || timeClose == null) return true;

    try {
      final now = DateTime.now();
      final currentTime = TimeOfDay.fromDateTime(now);

      int openHour, openMinute, closeHour, closeMinute;

      // Handle List format [hour, minute]
      if (timeOpen is List && timeOpen.length >= 2) {
        openHour = timeOpen[0] as int;
        openMinute = timeOpen[1] as int;
      } else if (timeOpen is String) {
        final openParts = timeOpen.split(':');
        openHour = int.parse(openParts[0]);
        openMinute = int.parse(openParts[1]);
      } else {
        return true;
      }

      if (timeClose is List && timeClose.length >= 2) {
        closeHour = timeClose[0] as int;
        closeMinute = timeClose[1] as int;
      } else if (timeClose is String) {
        final closeParts = timeClose.split(':');
        closeHour = int.parse(closeParts[0]);
        closeMinute = int.parse(closeParts[1]);
      } else {
        return true;
      }

      // Convert to minutes for easier comparison
      final currentMinutes = currentTime.hour * 60 + currentTime.minute;
      final openMinutes = openHour * 60 + openMinute;
      final closeMinutes = closeHour * 60 + closeMinute;

      // Handle case where closing time is next day (e.g., 23:00 to 06:00)
      if (closeMinutes < openMinutes) {
        return currentMinutes >= openMinutes || currentMinutes < closeMinutes;
      } else {
        return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
      }
    } catch (e) {
      debugPrint('Error checking company hours: $e');
      return true;
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
    final timeOpen = _company!['timeOpen'];
    final timeClose = _company!['timeClose'];

    // Check if company is currently open
    final isOpen = _isCompanyOpen(timeOpen, timeClose);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
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
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        height: 1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Sector Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.blue[200]!,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.category_rounded,
                            color: Colors.blue[700],
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            companySector,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isOpen
                        ? [Colors.green[400]!, Colors.green[500]!]
                        : [Colors.red[400]!, Colors.red[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isOpen ? Colors.green[400] : Colors.red[400])!
                          .withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOpen ? Icons.check_circle : Icons.cancel,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOpen ? 'Ouvert' : 'Fermé',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Description
          if (companyDescription != null && companyDescription.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              companyDescription,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 16),

          // Info Cards Grid
          Row(
            children: [
              // Rating Card
              Expanded(
                child: _buildCompactInfoCard(
                  icon: Icons.star_rounded,
                  iconColor: Colors.amber[600]!,
                  backgroundColor: Colors.amber[50]!,
                  borderColor: Colors.amber[200]!,
                  title: averageRating.toStringAsFixed(1),
                  subtitle: '${_reviews.length} avis',
                ),
              ),
              const SizedBox(width: 10),
              // Phone Card
              if (companyPhone != null && companyPhone.isNotEmpty)
                Expanded(
                  child: _buildCompactInfoCard(
                    icon: Icons.phone_rounded,
                    iconColor: Colors.blue[600]!,
                    backgroundColor: Colors.blue[50]!,
                    borderColor: Colors.blue[200]!,
                    title: 'Appeler',
                    subtitle: companyPhone,
                    isClickable: true,
                  ),
                ),
            ],
          ),

          // Time & Address Cards
          if (timeOpen != null && timeClose != null) ...[
            const SizedBox(height: 10),
            _buildTimeAddressCard(
              icon: Icons.access_time_rounded,
              iconColor: Colors.purple[600]!,
              backgroundColor: Colors.purple[50]!,
              borderColor: Colors.purple[200]!,
              title: '${_formatTimeToAmPm(timeOpen)} - ${_formatTimeToAmPm(timeClose)}',
              status: isOpen ? 'Ouvert' : 'Fermé',
              isOpen: isOpen,
            ),
          ],

          if (companyAddress != null && companyAddress.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildTimeAddressCard(
              icon: Icons.location_on_rounded,
              iconColor: Colors.red[600]!,
              backgroundColor: Colors.red[50]!,
              borderColor: Colors.red[200]!,
              title: companyAddress,
              isLocation: true,
            ),
          ],
        ],
      ),
    );
  }

// Compact info card (for rating and phone)
  Widget _buildCompactInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required String title,
    required String subtitle,
    bool isClickable = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  backgroundColor.withOpacity(0.85),
                  backgroundColor.withOpacity(0.65),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row with Icon
                Row(
                  children: [
                    // Modern Icon Container with Gradient
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            iconColor.withOpacity(0.22),
                            iconColor.withOpacity(0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: iconColor.withOpacity(0.15),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.black87,
                            Colors.black54,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Subtitle with Enhanced Styling
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black54.withOpacity(0.8),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
// Compact time and address card
  Widget _buildTimeAddressCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required String title,
    String? status,
    bool isOpen = false,
    bool isLocation = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (status != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isOpen ? Colors.green[200]! : Colors.orange[200]!,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 9,
                        color: isOpen ? Colors.green[700] : Colors.orange[700],
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
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
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[400],
              indicatorColor: Colors.transparent,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.12),
                    AppColors.primary.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              labelPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              splashFactory: NoSplash.splashFactory,
              overlayColor: MaterialStateProperty.all(Colors.transparent),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_rounded, size: 18),
                      const SizedBox(width: 7),
                      Text(
                        'Boutique',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rate_review_rounded, size: 18),
                      const SizedBox(width: 7),
                      Text(
                        'Avis',
                        style: TextStyle(
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
          ),
          const SizedBox(height: 20),
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
              : _buildProductListByCategory(),
        ),
      ],
    );
  }
  String _formatTimeToAmPm(dynamic timeData) {
    try {
      if (timeData == null) return '--';
      
      int hour, minute;
      
      if (timeData is List && timeData.length >= 2) {
        hour = timeData[0] as int;
        minute = timeData[1] as int;
      } else if (timeData is String) {
        final parts = timeData.split(':');
        if (parts.length < 2) return timeData;
        hour = int.parse(parts[0]);
        minute = int.parse(parts[1]);
      } else {
        return timeData.toString();
      }
      
      String period = hour >= 12 ? 'PM' : 'AM';
      int displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      
      return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return timeData?.toString() ?? '--';
    }
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
        _buildSortDropdown(),
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


  Widget _buildProductList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _filteredProducts.length,
      // ADD cacheExtent
      cacheExtent: 500,
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final productId = product['productId'] as int?;
        final productImage = productId != null ? _productImages[productId] : null;

        return RepaintBoundary(
          child: ProductListItem(
            product: product,
            productId: productId,
            productImage: productImage,
            onAddToCart: () => _addToCart(product),
          ),
        );
      },
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
    final otherReviews = _reviews.where((r) => r['userId'] != _currentUserId).toList();

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
        cacheExtent: 500, // ADD THIS
        addRepaintBoundaries: true, // ADD THIS
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final review = otherReviews[index];
          return RepaintBoundary( // ADD THIS
            child: _buildReviewItem(review, false),
          );
        },
      ),
    );
  }
  void _showAddReviewDialog() {
    double tempRating = _rating;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'Ajouter un avis',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Rating section with better spacing
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[200]!,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Votre note:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (i) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        setDialogState(() {
                                          tempRating = (i + 1).toDouble();
                                        });
                                      },
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: AnimatedScale(
                                          scale: i < tempRating ? 1.2 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          child: Icon(
                                            Icons.star_rounded,
                                            size: 36,
                                            color: i < tempRating
                                                ? Colors.amber
                                                : Colors.grey[300],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Comment section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Votre commentaire:',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _reviewController,
                          decoration: InputDecoration(
                            hintText: 'Partagez votre expérience...',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          maxLines: 4,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(
                              'Annuler',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _rating = tempRating;
                              _addReview(dialogContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              elevation: 3,
                            ),
                            child: const Text(
                              'Publier',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditReviewDialog(Map<String, dynamic> review) {
    // Pre-fill with existing review data
    final existingComment = review['comment']?.toString() ??
        review['reviewComment']?.toString() ??
        '';
    final existingRating = review['rating'] is num
        ? (review['rating'] as num).toDouble()
        : 5.0;

    _reviewController.text = existingComment;
    double tempRating = existingRating;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'Modifier votre avis',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Rating section with better spacing
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[200]!,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Note:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (i) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        setDialogState(() {
                                          tempRating = (i + 1).toDouble();
                                        });
                                      },
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: AnimatedScale(
                                          scale: i < tempRating ? 1.2 : 1.0,
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          child: Icon(
                                            Icons.star_rounded,
                                            size: 36,
                                            color: i < tempRating
                                                ? Colors.amber
                                                : Colors.grey[300],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Comment section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Votre commentaire:',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _reviewController,
                          decoration: InputDecoration(
                            hintText: 'Partagez votre expérience...',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          maxLines: 4,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              _reviewController.clear();
                              Navigator.pop(dialogContext);
                            },
                            child: Text(
                              'Annuler',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _rating = tempRating;
                              _updateReview(review, dialogContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              elevation: 3,
                            ),
                            child: const Text(
                              'Mettre à jour',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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
        'userId': _currentUserId,
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
        'userId': _currentUserId,
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
    final reviewDate = review['createdAt']?.toString() ?? review['createdAt']?.toString();

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

  String _formatReviewDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime dateTime;

      print('Date type: ${date.runtimeType}, Date value: $date');

      // Handle string format with commas: "2025, 10, 14, 4, 43, 59"
      if (date is String) {
        // Remove spaces and split by comma
        final parts = date.replaceAll(' ', '').split(',');
        if (parts.length >= 3) {
          int year = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int day = int.parse(parts[2]);
          int hour = parts.length > 3 ? int.parse(parts[3]) : 0;
          int minute = parts.length > 4 ? int.parse(parts[4]) : 0;
          int second = parts.length > 5 ? int.parse(parts[5]) : 0;

          dateTime = DateTime(year, month, day, hour, minute, second);
        } else {
          return 'N/A';
        }
      }
      // Handle list format from LocalDateTime [year, month, day, hour, minute, second]
      else if (date is List) {
        if (date.isEmpty) return 'N/A';

        int year = int.parse(date[0].toString());
        int month = int.parse(date[1].toString());
        int day = int.parse(date[2].toString());
        int hour = date.length > 3 ? int.parse(date[3].toString()) : 0;
        int minute = date.length > 4 ? int.parse(date[4].toString()) : 0;
        int second = date.length > 5 ? int.parse(date[5].toString()) : 0;

        dateTime = DateTime(year, month, day, hour, minute, second);
      }
      // Handle DateTime object
      else if (date is DateTime) {
        dateTime = date;
      }
      else {
        print('Unknown date format: ${date.runtimeType}');
        return 'N/A';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} à ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error parsing date: $date, Error: $e');
      return 'N/A';
    }
  }

  // ============================================================================
  // SKELETON UI METHODS
  // ============================================================================

  Widget _buildSkeletonSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: _buildAppBarButton(
        icon: Icons.arrow_back,
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.6)],
            ),
          ),
          child: const Bone.square(size: double.infinity),
        ),
      ),
    );
  }

  Widget _buildSkeletonCompanyInfo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone.text(words: 2, fontSize: 24),
                    const SizedBox(height: 10),
                    Bone.button(width: 120, height: 30),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Bone.button(width: 80, height: 35),
            ],
          ),
          const SizedBox(height: 14),
          Bone.text(words: 15, fontSize: 13),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Bone.button(width: double.infinity, height: 60)),
              const SizedBox(width: 10),
              Expanded(child: Bone.button(width: double.infinity, height: 60)),
            ],
          ),
          const SizedBox(height: 10),
          Bone.button(width: double.infinity, height: 50),
          const SizedBox(height: 10),
          Bone.button(width: double.infinity, height: 50),
        ],
      ),
    );
  }

  Widget _buildSkeletonTabSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  Expanded(child: Bone.button(width: double.infinity, height: 40)),
                  const SizedBox(width: 8),
                  Expanded(child: Bone.button(width: double.infinity, height: 40)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 650,
            child: _buildSkeletonProductGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonProductGrid() {
    return Column(
      children: [
        Bone.button(width: double.infinity, height: 50),
        const SizedBox(height: 16),
        Row(
          children: [
            Bone.button(width: 80, height: 35),
            const SizedBox(width: 8),
            Bone.button(width: 100, height: 35),
            const SizedBox(width: 8),
            Bone.button(width: 90, height: 35),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.52,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => _buildSkeletonProductCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonProductCard() {
    return Container(
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
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Bone.square(size: double.infinity),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Bone.text(words: 2, fontSize: 14),
                  const SizedBox(height: 8),
                  Bone.text(words: 1, fontSize: 16),
                  const Spacer(),
                  Bone.button(width: double.infinity, height: 35),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Replace the _buildProductListByCategory and _buildCategoryHeader methods with this:

  Widget _buildProductListByCategory() {
    if (_productsByCategory.isEmpty) {
      return _buildEmptyProductsState();
    }

    return ListView.builder(
      controller: _productScrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _categoryOrder.length,
      itemBuilder: (context, categoryIndex) {
        final categoryId = _categoryOrder[categoryIndex];
        final products = _productsByCategory[categoryId] ?? [];
        final categoryName = _getCategoryName(categoryId);

        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Header
            _buildCategoryHeader(categoryName, products.length),

            // Products in this category
            ...products.asMap().entries.map((entry) {
              final productIndex = entry.key;
              final product = entry.value;
              final productId = product['productId'] as int?;
              final productImage = productId != null ? _productImages[productId] : null;

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: productIndex == 0 ? 8 : 4,
                ),
                child: RepaintBoundary(
                  child: ProductListItem(
                    product: product,
                    productId: productId,
                    productImage: productImage,
                    onAddToCart: () => _addToCart(product),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildCategoryHeader(String categoryName, int productCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.9),
                  AppColors.primary.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Animated Category Icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.35),
                              Colors.white.withOpacity(0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.category_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 14),

                // Category Name & Count with Modern Typography
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Title
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withOpacity(0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          categoryName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Product Count Text
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$productCount produit${productCount > 1 ? 's' : ''} disponible${productCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Modern Product Count Badge with Animation
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1).animate(
                    CurvedAnimation(
                      parent: AlwaysStoppedAnimation<double>(1),
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$productCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'items',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}