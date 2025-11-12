import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../core/services/cart_service.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/category_service.dart';
import '../../../../core/services/cart_item_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/cart_notifier.dart';
import '../../../../core/services/auth_service.dart';
import 'dart:typed_data';
import '../../../../core/utils/PromotionBanner.dart';
import '../widgets/product_card.dart';
import 'product_detail_page.dart';
import 'company_page.dart';
import 'all_companies_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();
  final CartItemService _cartItemService = CartItemService();
  final AttachmentService _attachmentService = AttachmentService();
  final CartService _cartService = CartService();
  final CompanyService _companyService = CompanyService();
  final CartNotifier _cartNotifier = CartNotifier();
  final PaginationService _paginationService = PaginationService(itemsPerPage: 6);
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _featuredProducts = [];
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  Map<int, Uint8List> _productImages = {};
  Map<int, Uint8List> _companyImages = {};
  Map<int, Uint8List> _categoryImages = {};
  Map<int, bool> _loadedImageIds = {};
  bool _isLoading = true;
  bool _isInitialLoadComplete = false;
  int _selectedCategoryIndex = 0;
  int? _selectedCategoryId;
  String _selectedFilter = 'all';
  int? _currentUserId;

  int _currentPage = 1;
  bool _isLoadingMore = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _promotionRefreshController;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final Map<int, Future<Uint8List?>> _imageFutures = {};

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _promotionRefreshController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();

    _selectedCategoryId = 0;
    _initializeUser();
    _startPromotionRefreshTimer();
  }

  Future<void> _initializeUser() async {
    _currentUserId = await _authService.getUserId();
    _loadInitialData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _promotionRefreshController.dispose();
    _searchController.dispose();
    _imageFutures.clear();
    super.dispose();
  }

  void _startPromotionRefreshTimer() {
    Future.delayed(const Duration(seconds: 30)).then((_) {
      if (mounted) {
        setState(() {});
        _startPromotionRefreshTimer();
      }
    });
  }

  // OPTIMIZATION 1: Load critical data first, images async in background
  Future<void> _loadInitialData() async {
    setState(() {
      _featuredProducts = List.generate(8, (index) => {
        'productId': index,
        'productName': 'Produit skeleton',
        'productPrice': 25.99,
        'productFinalePrice': 19.99,
        'available': true,
      });
      _companies = List.generate(6, (index) => {
        'companyId': index,
        'companyName': 'Entreprise skeleton',
      });
    });

    try {
      // Load critical data in parallel
      final results = await Future.wait([
        _productService.getAllProducts(),
        _categoryService.getAllCategories(),
        _companyService.getActiveCompanies(),
      ], eagerError: false);

      final products = results[0] as List;
      final categories = results[1] as List;
      final companies = results[2] as List;

      setState(() {
        _products = List<Map<String, dynamic>>.from(products);
        _featuredProducts = _products.take(8).toList();

        _categories = [
          {
            'id': 0,
            'name': 'Tous',
            'icon': Icons.shopping_bag
          },
          ...categories.map((cat) => {
            'id': cat['categoryId'] ?? cat['id'],
            'name': cat['categoryName'] ?? cat['name'] ?? 'Catégorie',
            'icon': Icons.category_rounded,
          }).toList()
        ];

        _companies = List<Map<String, dynamic>>.from(companies);
        _filteredProducts = _products;
        _isInitialLoadComplete = true;
      });

      // OPTIMIZATION 2: Load images async with priority (don't block UI)
      _loadAllImagesAsync();
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isInitialLoadComplete = true;
      });
      _showErrorSnackBar('Erreur de chargement: $e');
    }
  }

  // OPTIMIZATION 3: Load images with prioritization (featured > companies > categories)
  void _loadAllImagesAsync() {
    _loadProductImagesAsync(_featuredProducts);
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadCompanyImagesAsync(_companies);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      _loadCategoryImagesAsync(_categories);
    });
  }

  Future<void> _loadProductImagesAsync(List<Map<String, dynamic>> products) async {
    for (var product in products) {
      final productId = product['productId'] as int?;
      if (productId == null || _loadedImageIds.containsKey(productId)) continue;

      _imageFutures[productId] ??= _fetchProductImage(productId);

      try {
        final imageData = await _imageFutures[productId];
        if (imageData != null && mounted) {
          setState(() {
            _productImages[productId] = imageData;
            _loadedImageIds[productId] = true;
          });
        }
      } catch (e) {
        debugPrint('⚠️ Error loading image for product $productId: $e');
      }
    }
  }

  Future<Uint8List?> _fetchProductImage(int productId) async {
    try {
      final attachments = await _attachmentService.findByProductProductId(productId);
      if (attachments.isNotEmpty) {
        final firstAttachment = attachments.first as Map<String, dynamic>;
        final attachmentId = firstAttachment['attachmentId'] as int?;

        if (attachmentId != null) {
          final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
          if (attachmentDownload.data.isNotEmpty) {
            return attachmentDownload.data;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching product image: $e');
    }
    return null;
  }

  Future<void> _loadCompanyImagesAsync(List<Map<String, dynamic>> companies) async {
    for (var company in companies) {
      final companyId = company['companyId'] as int?;
      if (companyId == null || _loadedImageIds.containsKey(companyId)) continue;

      try {
        final attachments = await _attachmentService.getAttachmentsByEntity('COMPANY', companyId);
        if (attachments.isNotEmpty) {
          final firstAttachment = attachments.first as Map<String, dynamic>;
          final attachmentId = firstAttachment['attachmentId'] as int?;

          if (attachmentId != null) {
            final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
            if (mounted) {
              setState(() {
                _companyImages[companyId] = attachmentDownload.data;
                _loadedImageIds[companyId] = true;
              });
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error loading image for company $companyId: $e');
      }
    }
  }

  Future<void> _loadCategoryImagesAsync(List<Map<String, dynamic>> categories) async {
    for (var category in categories) {
      final categoryId = category['id'] as int?;
      if (categoryId == null || categoryId == 0 || _loadedImageIds.containsKey(categoryId)) continue;

      try {
        final attachments = await _attachmentService.getAttachmentsByEntity('CATEGORY', categoryId);
        if (attachments.isNotEmpty) {
          final firstAttachment = attachments.first as Map<String, dynamic>;
          final attachmentId = firstAttachment['attachmentId'] as int?;

          if (attachmentId != null) {
            final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
            if (mounted) {
              setState(() {
                _categoryImages[categoryId] = attachmentDownload.data;
                _loadedImageIds[categoryId] = true;
              });
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error loading image for category $categoryId: $e');
      }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final productId = product['productId'] ?? product['id'];
    if (productId == null) return;

    try {
      if (_currentUserId == null) return;

      await _cartItemService.addProductToUserCart(_currentUserId!, {
        'productId': productId,
        'quantity': 1,
      });

      _cartNotifier.notifyCartChanged();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${product['productName'] ?? product['name'] ?? 'Produit'} ajouté au panier',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  void _searchProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      final lowerQuery = query.toLowerCase();
      _searchResults = _products
          .where((product) {
        final name = (product['productName'] ?? product['name'] ?? '').toLowerCase();
        final description = (product['productDescription'] ?? '').toLowerCase();
        return name.contains(lowerQuery) || description.contains(lowerQuery);
      })
          .toList();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }

  Future<void> _filterProductsByCategory(int? categoryId) async {
    if (categoryId == 0) {
      setState(() {
        _selectedCategoryId = 0;
        _filteredProducts = _products;
        _currentPage = 1;
      });
      return;
    }

    if (_selectedCategoryId == categoryId) {
      setState(() {
        _selectedCategoryId = 0;
        _filteredProducts = _products;
        _currentPage = 1;
      });
      return;
    }

    setState(() {
      _selectedCategoryId = categoryId;
      _currentPage = 1;
    });

    try {
      if (categoryId != null && categoryId != 0) {
        final products = await _productService.getProductByCategoryId(categoryId);
        setState(() {
          _filteredProducts = products;
        });
        _loadProductImagesAsync(products);
      }
    } catch (e) {
      setState(() {
        _filteredProducts = [];
        _selectedCategoryId = 0;
      });
      _showErrorSnackBar('Erreur de chargement: $e');
    }
  }

  List<Map<String, dynamic>> _getPaginatedProducts() {
    return _paginationService.getPageItems(_filteredProducts, _currentPage);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[600],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isLoading = true);
          await _loadInitialData();
          setState(() => _isLoading = false);
        },
        child: Skeletonizer(
          enabled: !_isInitialLoadComplete,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                _buildModernAppBar(isMobile),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      _buildSearchBarSection(),
                      if (_isSearching) ...[
                        const SizedBox(height: 24),
                        _buildSearchResults(isMobile),
                      ] else ...[
                        const SizedBox(height: 28),
                        _buildPromotionBanner(bannerIndex: 0),
                        const SizedBox(height: 32),
                        _buildCompanySection(),
                        const SizedBox(height: 32),
                        _buildPromotionBanner(bannerIndex: 1),
                        const SizedBox(height: 32),
                        _buildCategoriesSection(),
                        const SizedBox(height: 32),
                        _buildFilteredProductsSection(isMobile),
                        const SizedBox(height: 32),
                        _buildProductsSection(isMobile),
                        const SizedBox(height: 32),
                        _buildPromotionBanner(bannerIndex: 2),
                        const SizedBox(height: 32),
                        _buildBenefitsSection(isMobile)
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(bool isMobile) {
    return SliverAppBar(
      expandedHeight: isMobile ? 140 : 130,
      floating: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.75),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -40,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: -50,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: isMobile ? 60 : 70,
                            height: isMobile ? 60 : 70,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'lib/core/assets/jibli_logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ShaderMask(
                                  shaderCallback: (bounds) => LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.white.withOpacity(0.9),
                                    ],
                                  ).createShader(bounds),
                                  child: Text(
                                    'Jibli',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 28 : 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Tout ce que vous aimez, à portée de clic.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: isMobile ? 11 : 12,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.4,
                                      height: 1.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
        child: TextField(
          controller: _searchController,
          onChanged: _searchProducts,
          decoration: InputDecoration(
            hintText: 'Rechercher un produit...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 15,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.close_rounded),
              color: Colors.grey[400],
              onPressed: _clearSearch,
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          ),
          style: const TextStyle(color: Colors.black87, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résultats de recherche (${_searchResults.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (_searchResults.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun produit trouvé',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Essayez une autre recherche',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = isMobile ? 2 : 3;
                final childAspectRatio = isMobile ? 0.52 : 0.62;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final product = _searchResults[index];
                    return _buildProductCard(product);
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPromotionBanner({int bannerIndex = 0}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: !_isInitialLoadComplete
          ? Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
      )
          : PromotionBanner(bannerIndex: bannerIndex),
    );
  }

  Widget _buildCategoriesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Catégories',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (_categories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Aucune catégorie disponible',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final categoryId = category['id'] as int?;
                  final categoryName = category['name'] ?? 'Catégorie';
                  final categoryImage = categoryId != null ? _categoryImages[categoryId] : null;
                  final isSelected = _selectedCategoryId == categoryId;

                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: !_isInitialLoadComplete ? null : () async {
                        await _filterProductsByCategory(categoryId);
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                  ? Border.all(color: AppColors.primary, width: 3)
                                  : Border.all(color: Colors.transparent, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? AppColors.primary.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: !_isInitialLoadComplete
                                  ? Container(
                                color: Colors.grey[200],
                                width: double.infinity,
                                height: double.infinity,
                              )
                                  : categoryImage != null
                                  ? Image.memory(
                                categoryImage,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )
                                  : Container(
                                color: Colors.grey[100],
                                child: Icon(
                                  category['icon'] ?? Icons.category_rounded,
                                  size: 40,
                                  color: isSelected ? AppColors.primary : Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 100,
                            child: Text(
                              categoryName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                color: isSelected ? AppColors.primary : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilteredProductsSection(bool isMobile) {
    if (_selectedCategoryId == null) return const SizedBox.shrink();

    final paginatedProducts = _getPaginatedProducts();
    final categoryName = _categories.firstWhere(
          (cat) => cat['id'] == _selectedCategoryId,
      orElse: () => {'name': 'Catégorie'},
    )['name'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Produits - $categoryName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (_selectedCategoryId != null && _selectedCategoryId != 0)
                TextButton(
                  onPressed: () => _filterProductsByCategory(0),
                  child: const Text('Effacer', style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_filteredProducts.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun produit dans cette catégorie',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = isMobile ? 2 : 3;
                    final childAspectRatio = isMobile ? 0.52 : 0.62;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: paginatedProducts.length,
                      itemBuilder: (context, index) {
                        final product = paginatedProducts[index];
                        return _buildProductCard(product);
                      },
                    );
                  },
                ),
                if (_filteredProducts.length > 6)
                  _buildPaginationBar(
                    _filteredProducts.length,
                    _currentPage,
                        (page) {
                      if (mounted) setState(() => _currentPage = page);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(bool isMobile) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Produits populaires',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = isMobile ? 2 : 3;
              final childAspectRatio = isMobile ? 0.52 : 0.62;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                itemCount: _featuredProducts.length,
                itemBuilder: (context, index) {
                  final product = _featuredProducts[index];
                  return _buildProductCard(product);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final isAvailable = product['available'];
    final productId = product['productId'] as int?;
    final productImage = productId != null ? _productImages[productId] : null;

    return ProductCard(
      name: product['productName'] ?? product['name'] ?? 'Produit',
      price: (product['productPrice'] ?? 0).toDouble(),
      imageBytes: productImage,
      imageUrl: product['imageUrl'],
      discount: (product['discountPercentage'] ?? 0).toDouble(),
      finalPrice: product['productFinalePrice'],
      isAvailable: isAvailable == true || isAvailable == 1 || isAvailable == '1',
      onTap: !_isInitialLoadComplete ? null : () {
        if (productId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailPage(productId: productId),
            ),
          );
        }
      },
      onAddToCart: !_isInitialLoadComplete ? () {} : () => _addToCart(product),
    );
  }

  Widget _buildCompanySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nos Partenaires',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              TextButton(
                onPressed: !_isInitialLoadComplete ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllCompaniesPage(),
                    ),
                  );
                },
                child: Row(
                  children: const [
                    Text('Voir tout', style: TextStyle(fontSize: 13)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_companies.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Aucune entreprise disponible',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _companies.length,
                itemBuilder: (context, index) {
                  final company = _companies[index];
                  final companyId = company['companyId'] as int?;
                  final companyName = company['companyName'] ?? 'Entreprise';
                  final companyImage = companyId != null ? _companyImages[companyId] : null;

                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: !_isInitialLoadComplete ? null : () {
                        if (companyId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CompanyPage(companyId: companyId),
                            ),
                          );
                        }
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: !_isInitialLoadComplete
                                  ? Container(
                                color: Colors.grey[200],
                                width: double.infinity,
                                height: double.infinity,
                              )
                                  : companyImage != null
                                  ? Image.memory(
                                companyImage,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )
                                  : Container(
                                color: Colors.grey[100],
                                child: Icon(
                                  Icons.business_rounded,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 100,
                            child: Text(
                              companyName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection(bool isMobile) {
    final benefits = [
      {
        'icon': Icons.local_shipping_rounded,
        'title': 'Livraison rapide',
        'description': 'Livraison gratuite pour les commandes de plus de 50 €'
      },
      {
        'icon': Icons.verified_user_rounded,
        'title': 'Qualité garantie',
        'description': 'Des produits soigneusement sélectionnés et certifiés'
      },
      {
        'icon': Icons.sentiment_satisfied_alt_rounded,
        'title': 'Satisfaction assurée',
        'description': 'Nous faisons tout pour garantir votre satisfaction'
      },
      {
        'icon': Icons.headset_mic_rounded,
        'title': 'Service client réactif',
        'description': 'Une équipe à votre écoute pour toute demande'
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pourquoi nous choisir ?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.95,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                itemCount: benefits.length,
                itemBuilder: (context, index) {
                  final benefit = benefits[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.1),
                                AppColors.primary.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            benefit['icon'] as IconData,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          benefit['title'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          benefit['description'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600],
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar(int totalItems, int currentPage, Function(int) onPageChanged) {
    final totalPages = _paginationService.getTotalPages(totalItems);
    final startItem = (currentPage - 1) * 6 + 1;
    final endItem = (startItem + 5 > totalItems) ? totalItems : startItem + 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$startItem-$endItem sur $totalItems',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: currentPage > 1
                      ? () => onPageChanged(currentPage - 1)
                      : null,
                  icon: Icon(
                    Icons.chevron_left,
                    color: currentPage > 1 ? AppColors.primary : Colors.grey[300],
                  ),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '$currentPage / $totalPages',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: currentPage < totalPages
                      ? () => onPageChanged(currentPage + 1)
                      : null,
                  icon: Icon(
                    Icons.chevron_right,
                    color: currentPage < totalPages ? AppColors.primary : Colors.grey[300],
                  ),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}