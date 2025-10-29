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
  final ProductService _productService = ProductService();
  final CompanyService _companyService = CompanyService();
  final CategoryService _categoryService = CategoryService();
  final AttachmentService _attachmentService = AttachmentService();
  final PaginationService _paginationService = PaginationService();
  PaginationState _paginationState = PaginationState(currentPage: 1, totalItems: 0, itemsPerPage: 12);

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
    'name', 'price', 'company', 'category', 'stock'
  ];

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  final Map<int, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

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
      _companyMap = {for (var comp in companies)
        if (comp['companyName'] != null) comp['companyName'] as String: comp['companyId'] as int};

      _categories = ['Tous', ...categories
        .where((c) => c['name'] != null)
        .map((c) => c['name'] as String)];
      _companies = ['Toutes', ...companies
        .where((c) => c['companyName'] != null)
        .map((c) => c['companyName'] as String)];

      setState(() {
        _allProducts = products;
        _paginationState = _paginationState.copyWith(totalItems: products.length);
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

  Future<void> _preloadImages() async {
    _preloadImagesForProducts(_allProducts);
  }

  Future<void> _preloadImagesForProducts(List<Map<String, dynamic>> products) async {
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
        setState(() {
          _imageCache[attachmentId] = download.data;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _applyFilters() async {
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> baseProducts = [];

    // Step 1: Get base products (with full data including attachments)
    if (_selectedCompany != 'Toutes' && _companyMap.containsKey(_selectedCompany)) {
      final companyId = _companyMap[_selectedCompany]!;
      try {
        final data = await _companyService.getCompanyProducts(companyId);
        final rawProducts = (data?['products'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

        // Attach missing 'attachments' by fetching from ProductService
        baseProducts = await _enrichProductsWithAttachments(rawProducts);
      } catch (e) {
        baseProducts = [];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
        }
      }
    } else {
      baseProducts = List.from(_allProducts); // Already has attachments
    }

    // Step 2: Apply local filters
    final filtered = baseProducts.where((p) {
      final name = (p['productName'] ?? '').toString().toLowerCase();
      final desc = (p['productDescription'] ?? '').toString().toLowerCase();
      final cat = p['category']?['name'] ?? '';
      final price = (p['productPrice'] ?? 0).toDouble();

      return (name.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase())) &&
          (_selectedCategory == 'Tous' || cat == _selectedCategory) &&
          price >= _minPrice && price <= _maxPrice;
    }).toList();

    // Step 3: Sort
    filtered.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'price':
          cmp = (a['productPrice'] ?? 0).compareTo(b['productPrice'] ?? 0);
          break;
        case 'company':
          cmp = (a['company']?['companyName'] ?? '').compareTo(b['company']?['companyName'] ?? '');
          break;
        case 'category':
          cmp = (a['category']?['name'] ?? '').compareTo(b['category']?['name'] ?? '');
          break;
        case 'stock':
          cmp = (a['productQuantity'] ?? 0).compareTo(b['productQuantity'] ?? 0);
          break;
        default:
          cmp = (a['productName'] ?? '').compareTo(b['productName'] ?? '');
      }
      return _sortAscending ? cmp : -cmp;
    });

    // Step 4: Update UI
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

    // Step 5: Preload images
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

      // If already has attachments, skip
      if (product['attachments'] != null && (product['attachments'] as List).isNotEmpty) {
        enriched.add(product);
        continue;
      }

      try {
        final fullProduct = await _productService.getProductById(productId);
        if (fullProduct != null) {
          enriched.add(fullProduct);
        } else {
          enriched.add(product); // fallback
        }
      } catch (_) {
        enriched.add(product); // fallback
      }
    }

    return enriched;
  }
  Future<void> _preloadProductImages(List<Map<String, dynamic>> products) async {
    final start = (_paginationState.currentPage - 1) * _paginationState.itemsPerPage;
    final end = (start + _paginationState.itemsPerPage * 2).clamp(0, products.length);

    for (int i = start; i < end && i < products.length; i++) {
      final product = products[i];
      final attachments = product['attachments'] as List<dynamic>?;
      if (attachments == null || attachments.isEmpty) continue;

      final attachmentId = attachments[0]['attachmentId'] as int;
      if (_imageCache.containsKey(attachmentId)) continue;

      try {
        final result = await _attachmentService.downloadAttachment(attachmentId);
        if (mounted && result.data != null) {
          setState(() {
            _imageCache[attachmentId] = result.data;
          });
        }
      } catch (_) {}
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final paginationService = PaginationService(itemsPerPage: 12);
    final paginatedProducts = paginationService.getPageItems(
      _filteredProducts,
      _paginationState.currentPage
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildFiltersSection(),
          Expanded(
            child: _buildProductsContent(paginatedProducts),
          ),
          if (_filteredProducts.isNotEmpty) _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestion des Produits',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_filteredProducts.length} produits trouvés',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _isGridView = true),
                icon: Icon(
                  Icons.grid_view_rounded,
                  color: _isGridView ? AppColors.primary : AppColors.textSecondary,
                ),
                tooltip: 'Vue grille',
              ),
              IconButton(
                onPressed: () => setState(() => _isGridView = false),
                icon: Icon(
                  Icons.view_list_rounded,
                  color: !_isGridView ? AppColors.primary : AppColors.textSecondary,
                ),
                tooltip: 'Vue liste',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  onChanged: (value) async {
                    _searchQuery = value;
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
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    _selectedCategory = value!;
                    await _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCompany,
                  decoration: InputDecoration(
                    labelText: 'Entreprise',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _companies.map((company) {
                    return DropdownMenuItem(
                      value: company,
                      child: Text(company),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    _selectedCompany = value!;
                    await _applyFilters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
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
                      onChanged: (values) {
                        setState(() {
                          _minPrice = values.start;
                          _maxPrice = values.end;
                        });
                      },
                      onChangeEnd: (values) async => await _applyFilters(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              DropdownButton<String>(
                value: _sortBy,
                items: _sortOptions.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(_getSortLabel(option)),
                  );
                }).toList(),
                onChanged: (value) async {
                  _sortBy = value!;
                  await _applyFilters();
                },
              ),
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
          ),
        ],
      ),
    );
  }

  String _getSortLabel(String option) {
    switch (option) {
      case 'name': return 'Nom';
      case 'price': return 'Prix';
      case 'company': return 'Entreprise';
      case 'category': return 'Catégorie';
      case 'stock': return 'Stock';
      default: return option;
    }
  }

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
      padding: const EdgeInsets.all(24),
      child: _isGridView ? _buildGridView(products) : _buildListView(products),
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> products) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => _buildProductCard(products[index]),
        );
      },
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> products) {
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) => _buildProductListItem(products[index]),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final int? companyId = product['companyId'] ?? product['company']?['companyId'];
    final int? categoryId = product['categoryId'] ?? product['category']?['categoryId'];
    final int? attachmentId = (product['attachments'] as List<dynamic>?)?.firstOrNull?['attachmentId'] as int?;
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
              BoxShadow(color: AppColors.shadow.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      child: _buildProductImage(attachmentId),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isAvailable ? AppColors.success.withOpacity(0.9) : AppColors.danger.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isAvailable ? 'Disponible' : 'Rupture',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['productName'] ?? 'Sans nom',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$companyName • $categoryName',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${price.toStringAsFixed(2)} DT',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
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

// ---- Company cache helper (already added before) ----
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

// ---- NEW: Category cache helper ----
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

  Widget _buildProductListItem(Map<String, dynamic> product) {
    final int? companyId = product['companyId'] ?? product['company']?['companyId'];
    final int? categoryId = product['categoryId'] ?? product['category']?['categoryId'];
    final int? attachmentId = (product['attachments'] as List<dynamic>?)?.firstOrNull?['attachmentId'] as int?;
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: AppColors.shadow.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: _buildProductImage(attachmentId),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['productName'] ?? 'Produit sans nom',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$companyName • $categoryName',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${price.toStringAsFixed(2)} DT',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAvailable ? AppColors.success.withOpacity(0.1) : AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isAvailable ? 'Disponible' : 'Rupture',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isAvailable ? AppColors.success : AppColors.danger),
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

  Widget _buildProductImage(int? attachmentId) {
    if (attachmentId == null) {
      return _placeholderImage();
    }

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
              setState(() {
                _imageCache[attachmentId] = snapshot.data!.data;
              });
            }
          });
          return Image.memory(
            snapshot.data!.data,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        }

        if (snapshot.hasError) {
          return _placeholderImage(icon: Icons.broken_image_rounded);
        }

        return _placeholderImage(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }

  Widget _placeholderImage({IconData icon = Icons.inventory_2_outlined, Widget? child}) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: child ??
            Icon(icon, size: 40, color: AppColors.primary.withOpacity(0.3)),
      ),
    );
  }
  Widget _buildPaginationBar() {
    final paginationService = PaginationService(itemsPerPage: 12);
    final totalPages = paginationService.getTotalPages(_filteredProducts.length);
    final startItem = (_paginationState.currentPage - 1) * _paginationState.itemsPerPage + 1;
    final endItem = (_paginationState.currentPage * _paginationState.itemsPerPage).clamp(0, _filteredProducts.length);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage de $startItem à $endItem sur ${_filteredProducts.length} produits',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _paginationState.currentPage > 1
                    ? () => setState(() {
                        _paginationState = _paginationState.copyWith(
                          currentPage: _paginationState.currentPage - 1
                        );
                      })
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page ${_paginationState.currentPage} sur $totalPages',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: _paginationState.currentPage < totalPages
                    ? () => setState(() {
                        _paginationState = _paginationState.copyWith(
                          currentPage: _paginationState.currentPage + 1
                        );
                      })
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}