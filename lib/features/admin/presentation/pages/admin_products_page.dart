import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/category_service.dart';
import '../../../../core/services/attachment_service.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  // ──────────────────────────────────────────────────────────────────────
  // Services & State
  // ──────────────────────────────────────────────────────────────────────
  final ProductService _productService = ProductService();
  final CompanyService _companyService = CompanyService();
  final CategoryService _categoryService = CategoryService();
  final AttachmentService _attachmentService = AttachmentService();

  PaginationState _paginationState =
  PaginationState(currentPage: 1, totalItems: 0, itemsPerPage: 12);

  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  String _selectedCompany = 'Toutes';
  double _minPrice = 0;
  double _maxPrice = 1000;
  String _sortBy = 'name';
  bool _sortAscending = true;
  bool _isGridView = true;
  bool _isLoading = true;

  List<String> _categories = ['Tous'];
  List<String> _companies = ['Toutes'];
  Map<String, int> _categoryMap = {};
  Map<String, int> _companyMap = {};

  final List<String> _sortOptions = [
    'name',
    'price',
    'company',
    'category',
    'stock',
  ];

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final Map<int, Uint8List> _imageCache = {};

  // ──────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --------------------------------------------------------------------
  // Data loading (unchanged – only minor UI tweaks later)
  // --------------------------------------------------------------------
  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final results = await Future.wait([
        _productService.getAllProducts(),
        _companyService.getAllCompanies(),
        _categoryService.getAllCategories(),
      ]);

      final products = results[0] as List<Map<String, dynamic>>;
      final companies = results[1] as List<Map<String, dynamic>>;
      final categories = results[2] as List<Map<String, dynamic>>;

      _categoryMap = {
        for (var cat in categories)
          if (cat['name'] != null) cat['name'] as String: cat['categoryId'] as int
      };
      _companyMap = {
        for (var comp in companies)
          if (comp['companyName'] != null)
            comp['companyName'] as String: comp['companyId'] as int
      };

      _categories = [
        'Tous',
        ...categories
            .where((c) => c['name'] != null)
            .map((c) => c['name'] as String)
      ];
      _companies = [
        'Toutes',
        ...companies
            .where((c) => c['companyName'] != null)
            .map((c) => c['companyName'] as String)
      ];

      setState(() {
        _allProducts = products;
        _paginationState =
            _paginationState.copyWith(totalItems: products.length);
        _isLoading = false;
      });

      await _applyFilters();
      _preloadImages();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  // --------------------------------------------------------------------
  // Image pre-loading (unchanged)
  // --------------------------------------------------------------------
  Future<void> _preloadImages() async => _preloadImagesForProducts(_allProducts);

  Future<void> _preloadImagesForProducts(
      List<Map<String, dynamic>> products) async {
    for (final product in products) {
      final attachments = product['attachments'] as List<dynamic>?;
      if (attachments != null && attachments.isNotEmpty) {
        final firstAttachmentId = attachments[0]['attachmentId'] as int;
        if (!_imageCache.containsKey(firstAttachmentId)) {
          _preloadImage(firstAttachmentId);
        }
      }
    }
  }

  Future<void> _preloadImage(int attachmentId) async {
    try {
      final download = await _attachmentService.downloadAttachment(attachmentId);
      if (mounted) {
        setState(() => _imageCache[attachmentId] = download.data);
      }
    } catch (_) {}
  }

  // --------------------------------------------------------------------
  // Filtering / sorting
  // --------------------------------------------------------------------
  Future<void> _applyFilters() async {
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> baseProducts = [];

    // ---------- Company filter (server side) ----------
    if (_selectedCompany != 'Toutes' && _companyMap.containsKey(_selectedCompany)) {
      final companyId = _companyMap[_selectedCompany]!;
      try {
        final data = await _companyService.getCompanyProducts(companyId);
        final rawProducts = (data?['products'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
            [];

        baseProducts = await _enrichProductsWithAttachments(rawProducts);
      } catch (e) {
        baseProducts = [];
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    } else {
      baseProducts = List.from(_allProducts);
    }

    // ---------- Local filters ----------
    final filtered = baseProducts.where((p) {
      final name = (p['productName'] ?? '').toString().toLowerCase();
      final desc = (p['productDescription'] ?? '').toString().toLowerCase();
      final cat = p['category']?['name'] ?? '';
      final price = (p['productPrice'] ?? 0).toDouble();

      return (name.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase())) &&
          (_selectedCategory == 'Tous' || cat == _selectedCategory) &&
          price >= _minPrice &&
          price <= _maxPrice;
    }).toList();

    // ---------- Sorting ----------
    filtered.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'price':
          cmp = (a['productPrice'] ?? 0).compareTo(b['productPrice'] ?? 0);
          break;
        case 'company':
          cmp = (a['company']?['companyName'] ?? '')
              .compareTo(b['company']?['companyName'] ?? '');
          break;
        case 'category':
          cmp = (a['category']?['name'] ?? '')
              .compareTo(b['category']?['name'] ?? '');
          break;
        case 'stock':
          cmp = (a['productQuantity'] ?? 0)
              .compareTo(b['productQuantity'] ?? 0);
          break;
        default:
          cmp = (a['productName'] ?? '').compareTo(b['productName'] ?? '');
      }
      return _sortAscending ? cmp : -cmp;
    });

    // ---------- UI update ----------
    if (mounted) {
      setState(() {
        _filteredProducts = filtered;
        _paginationState = _paginationState.copyWith(
          currentPage: 1,
          totalItems: filtered.length,
        );
        _isLoading = false;
      });
    }

    await _preloadProductImages(filtered);
  }

  Future<List<Map<String, dynamic>>> _enrichProductsWithAttachments(
      List<Map<String, dynamic>> products) async {
    final enriched = <Map<String, dynamic>>[];
    for (final product in products) {
      final productId = product['productId'] as int?;
      if (productId == null) {
        enriched.add(product);
        continue;
      }
      if (product['attachments'] != null &&
          (product['attachments'] as List).isNotEmpty) {
        enriched.add(product);
        continue;
      }
      try {
        final full = await _productService.getProductById(productId);
        enriched.add(full ?? product);
      } catch (_) {
        enriched.add(product);
      }
    }
    return enriched;
  }

  Future<void> _preloadProductImages(
      List<Map<String, dynamic>> products) async {
    final start = (_paginationState.currentPage - 1) *
        _paginationState.itemsPerPage;
    final end = (start + _paginationState.itemsPerPage * 2)
        .clamp(0, products.length);

    for (int i = start; i < end && i < products.length; i++) {
      final product = products[i];
      final attachments = product['attachments'] as List<dynamic>?;
      if (attachments == null || attachments.isEmpty) continue;

      final attachmentId = attachments[0]['attachmentId'] as int;
      if (_imageCache.containsKey(attachmentId)) continue;

      try {
        final result = await _attachmentService.downloadAttachment(attachmentId);
        if (mounted && result.data != null) {
          setState(() => _imageCache[attachmentId] = result.data);
        }
      } catch (_) {}
    }
  }

  // --------------------------------------------------------------------
  // UI – Main Scaffold
  // --------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final paginatedProducts = PaginationService(itemsPerPage: 12).getPageItems(
      _filteredProducts,
      _paginationState.currentPage,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          _buildFiltersSection(context),
          Expanded(child: _buildProductsContent(paginatedProducts)),
          if (_filteredProducts.isNotEmpty) _buildPaginationBar(),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Header – responsive
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: AppColors.textLight,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Title + count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestion des Produits',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_filteredProducts.length} produits trouvés',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // View toggle (desktop only)
          if (!isMobile)
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _isGridView = true),
                  icon: Icon(
                    Icons.grid_view_rounded,
                    color:
                    _isGridView ? AppColors.primary : AppColors.textSecondary,
                  ),
                  tooltip: 'Vue grille',
                ),
                IconButton(
                  onPressed: () => setState(() => _isGridView = false),
                  icon: Icon(
                    Icons.view_list_rounded,
                    color:
                    !_isGridView ? AppColors.primary : AppColors.textSecondary,
                  ),
                  tooltip: 'Vue liste',
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Filters – collapsible on mobile, row on larger screens
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildFiltersSection(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final isTablet = width < 900;

    // Collapsible panel for mobile
    if (isMobile) {
      return ExpansionTile(
        title: const Text('Filtres & Tri',
            style: TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          _buildCategoryDropdown(),
          const SizedBox(height: 12),
          _buildCompanyDropdown(),
          const SizedBox(height: 12),
          _buildPriceRange(),
          const SizedBox(height: 12),
          _buildSortRow(),
        ],
      );
    }

    // Tablet / Desktop – horizontal layout
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // First row: search + category + company
          Row(
            children: [
              Expanded(flex: 3, child: _buildSearchField()),
              const SizedBox(width: 12),
              if (!isTablet) ...[
                Expanded(child: _buildCategoryDropdown()),
                const SizedBox(width: 12),
                Expanded(child: _buildCompanyDropdown()),
              ] else
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildCategoryDropdown()),
                      const SizedBox(width: 8),
                      Expanded(child: _buildCompanyDropdown()),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Second row: price + sort
          Row(
            children: [
              Expanded(child: _buildPriceRange()),
              const SizedBox(width: 24),
              _buildSortRow(),
            ],
          ),
        ],
      ),
    );
  }

  // Individual filter widgets (extracted for reuse)
  Widget _buildSearchField() {
    return TextField(
      onChanged: (v) async {
        _searchQuery = v;
        await _applyFilters();
      },
      decoration: InputDecoration(
        hintText: 'Rechercher des produits...',
        prefixIcon: const Icon(Icons.search_rounded),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Catégorie',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _categories
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) async {
        _selectedCategory = v!;
        await _applyFilters();
      },
    );
  }

  Widget _buildCompanyDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCompany,
      decoration: InputDecoration(
        labelText: 'Entreprise',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _companies
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) async {
        _selectedCompany = v!;
        await _applyFilters();
      },
    );
  }

  Widget _buildPriceRange() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fourchette de prix: ${_minPrice.toInt()}DT - ${_maxPrice.toInt()}DT',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        RangeSlider(
          values: RangeValues(_minPrice, _maxPrice),
          min: 0,
          max: 1000,
          divisions: 100,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() {
            _minPrice = v.start;
            _maxPrice = v.end;
          }),
          onChangeEnd: (_) async => await _applyFilters(),
        ),
      ],
    );
  }

  Widget _buildSortRow() {
    return Row(
      children: [
        DropdownButton<String>(
          value: _sortBy,
          items: _sortOptions
              .map((o) => DropdownMenuItem(value: o, child: Text(_getSortLabel(o))))
              .toList(),
          onChanged: (v) async {
            _sortBy = v!;
            await _applyFilters();
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            _sortAscending = !_sortAscending;
            await _applyFilters();
          },
          icon: Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            color: AppColors.primary,
          ),
          tooltip: _sortAscending ? 'Croissant' : 'Décroissant',
        ),
      ],
    );
  }

  String _getSortLabel(String option) {
    switch (option) {
      case 'name':
        return 'Nom';
      case 'price':
        return 'Prix';
      case 'company':
        return 'Entreprise';
      case 'category':
        return 'Catégorie';
      case 'stock':
        return 'Stock';
      default:
        return option;
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Products content – responsive grid / list
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildProductsContent(List<Map<String, dynamic>> products) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun produit trouvé',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: _isGridView
          ? _buildResponsiveGrid(products)
          : _buildResponsiveList(products),
    );
  }

  // ---------- Grid ----------
  Widget _buildResponsiveGrid(List<Map<String, dynamic>> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossCount;
        if (constraints.maxWidth > 1200) {
          crossCount = 4;
        } else if (constraints.maxWidth > 900) {
          crossCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossCount = 2;
        } else {
          crossCount = 1;
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            childAspectRatio: crossCount == 1 ? 1.4 : 0.78,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (c, i) => _buildProductCard(products[i]),
        );
      },
    );
  }

  // ---------- List ----------
  Widget _buildResponsiveList(List<Map<String, dynamic>> products) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: products.length,
      itemBuilder: (c, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _buildProductListItem(products[i]),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Product Card (grid) – unchanged logic, only minor size tweaks
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildProductCard(Map<String, dynamic> product) {
    final int? companyId =
        product['companyId'] ?? product['company']?['companyId'];
    final int? categoryId =
        product['categoryId'] ?? product['category']?['categoryId'];
    final int? attachmentId =
    (product['attachments'] as List<dynamic>?)?.firstOrNull?['attachmentId']
    as int?;
    final price = (product['productPrice'] ?? 0).toDouble();
    final isAvailable = product['available'] ?? true;

    return FutureBuilder<List<Map<String, dynamic>?>>(
      future: Future.wait([
        companyId != null ? _getCompanyById(companyId) : Future.value(null),
        categoryId != null ? _getCategoryById(categoryId) : Future.value(null),
      ]),
      builder: (context, snapshot) {
        final company = snapshot.data?[0];
        final category = snapshot.data?[1];
        final companyName = company?['companyName'] ?? 'Inconnue';
        final categoryName = category?['name'] ?? 'Inconnue';

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: AppColors.shadow.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image + badge
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      child: _buildProductImage(attachmentId),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? AppColors.success.withOpacity(0.9)
                              : AppColors.danger.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isAvailable ? 'Disponible' : 'Rupture',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['productName'] ?? 'Sans nom',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$companyName • $categoryName',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${price.toStringAsFixed(2)} DT',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Product List Item (list view)
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildProductListItem(Map<String, dynamic> product) {
    final int? companyId =
        product['companyId'] ?? product['company']?['companyId'];
    final int? categoryId =
        product['categoryId'] ?? product['category']?['categoryId'];
    final int? attachmentId =
    (product['attachments'] as List<dynamic>?)?.firstOrNull?['attachmentId']
    as int?;
    final price = (product['productPrice'] ?? 0).toDouble();
    final isAvailable = product['available'] ?? true;

    return FutureBuilder<List<Map<String, dynamic>?>>(
      future: Future.wait([
        companyId != null ? _getCompanyById(companyId) : Future.value(null),
        categoryId != null ? _getCategoryById(categoryId) : Future.value(null),
      ]),
      builder: (context, snapshot) {
        final company = snapshot.data?[0];
        final category = snapshot.data?[1];
        final companyName = company?['companyName'] ?? 'Inconnue';
        final categoryName = category?['name'] ?? 'Inconnue';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: AppColors.shadow.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _buildProductImage(attachmentId),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['productName'] ?? 'Produit sans nom',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$companyName • $categoryName',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${price.toStringAsFixed(2)} DT',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isAvailable ? 'Disponible' : 'Rupture',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isAvailable ? AppColors.success : AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Image helper (unchanged)
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildProductImage(int? attachmentId) {
    if (attachmentId == null) return _placeholderImage();

    if (_imageCache.containsKey(attachmentId)) {
      return Image.memory(
        _imageCache[attachmentId]!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return FutureBuilder<AttachmentDownload>(
      future: _attachmentService.downloadAttachment(attachmentId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _imageCache[attachmentId] = snapshot.data!.data);
            }
          });
          return Image.memory(
            snapshot.data!.data,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        }
        if (snapshot.hasError) return _placeholderImage(icon: Icons.broken_image_rounded);
        return _placeholderImage(child: const CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }

  Widget _placeholderImage({IconData icon = Icons.inventory_2_outlined, Widget? child}) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: child ?? Icon(icon, size: 40, color: AppColors.primary.withOpacity(0.3)),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Company / Category cache helpers (unchanged)
  // ──────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _getCompanyById(int companyId) async {
    if (_companyMap.containsValue(companyId)) {
      final name = _companyMap.entries.firstWhere((e) => e.value == companyId).key;
      return {'companyId': companyId, 'companyName': name};
    }
    try {
      final company = await _companyService.getCompanyById(companyId);
      if (company != null && company['companyName'] != null) {
        _companyMap[company['companyName'] as String] = companyId;
        return company;
      }
    } catch (_) {}
    return {'companyId': companyId, 'companyName': 'Inconnue'};
  }

  Future<Map<String, dynamic>?> _getCategoryById(int categoryId) async {
    if (_categoryMap.containsValue(categoryId)) {
      final name = _categoryMap.entries.firstWhere((e) => e.value == categoryId).key;
      return {'categoryId': categoryId, 'name': name};
    }
    try {
      final category = await _categoryService.getCategoryById(categoryId);
      if (category != null && category['name'] != null) {
        _categoryMap[category['name'] as String] = categoryId;
        return category;
      }
    } catch (_) {}
    return {'categoryId': categoryId, 'name': 'Inconnue'};
  }

  // ──────────────────────────────────────────────────────────────────────
  // Pagination bar – responsive
  // ──────────────────────────────────────────────────────────────────────
  Widget _buildPaginationBar() {
    final totalPages = PaginationService(itemsPerPage: 12)
        .getTotalPages(_filteredProducts.length);
    final startItem =
        (_paginationState.currentPage - 1) * _paginationState.itemsPerPage + 1;
    final endItem = (_paginationState.currentPage * _paginationState.itemsPerPage)
        .clamp(0, _filteredProducts.length);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isMobile)
                Text(
                  'Affichage de $startItem à $endItem sur ${_filteredProducts.length} produits',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _paginationState.currentPage > 1
                        ? () => setState(() => _paginationState = _paginationState
                        .copyWith(currentPage: _paginationState.currentPage - 1))
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'Page ${_paginationState.currentPage} / $totalPages',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  IconButton(
                    onPressed: _paginationState.currentPage < totalPages
                        ? () => setState(() => _paginationState = _paginationState
                        .copyWith(currentPage: _paginationState.currentPage + 1))
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}