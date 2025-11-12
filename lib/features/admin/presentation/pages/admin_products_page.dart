import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/theme/theme.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/category_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../widgets/CategoryDialog.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> with SingleTickerProviderStateMixin {
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
  int _selectedTabIndex = 0; // 0: Products, 1: Categories

  List<String> _categories = ['Tous'];
  List<String> _companies = ['Toutes'];
  Map<String, int> _categoryMap = {};
  Map<String, int> _companyMap = {};
  List<Map<String, dynamic>> _allCategories = [];

  final List<String> _sortOptions = ['name', 'price', 'company', 'category', 'stock'];

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  Map<int, Uint8List> _imageCache = {};
  Map<int, Uint8List> _categoryImageCache = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      _companyMap = {
        for (var comp in companies)
          if (comp['companyName'] != null)
            comp['companyName'] as String: comp['companyId'] as int
      };

      _categories = [
        'Tous',
        ...categories.where((c) => c['name'] != null).map((c) => c['name'] as String)
      ];
      _companies = [
        'Toutes',
        ...companies
            .where((c) => c['companyName'] != null)
            .map((c) => c['companyName'] as String)
      ];

      if (mounted) {
        setState(() {
          _allProducts = products;
          _allCategories = categories;
          _paginationState =
              _paginationState.copyWith(totalItems: products.length);
          _isLoading = false;
        });
      }

      await _applyFilters();
      await _loadProductImages();
      await _loadCategoryImages();
      _animationController.forward();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  // OPTIMIZED: Load product images with parallel fetching (same logic as owner product page)
  Future<void> _loadProductImages() async {
    try {
      final Map<int, Uint8List> images = {};

      if (_allProducts.isEmpty) {
        if (mounted) {
          setState(() {
            _imageCache = images;
          });
        }
        return;
      }

      // Get all attachment IDs for batch processing
      final Map<int, List<int>> productAttachments = {};

      for (var product in _allProducts) {
        final productId = product['productId'] as int?;
        if (productId == null) continue;

        try {
          final attachments = await _attachmentService.findByProductProductId(productId);
          if (attachments.isNotEmpty) {
            final attachmentIds = attachments
                .map((a) => int.tryParse(a['attachmentId'].toString()))
                .where((id) => id != null)
                .cast<int>()
                .toList();
            if (attachmentIds.isNotEmpty) {
              productAttachments[productId] = attachmentIds;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error loading attachments for product $productId: $e');
          continue;
        }
      }

      if (productAttachments.isEmpty) {
        if (mounted) {
          setState(() {
            _imageCache = images;
          });
        }
        return;
      }

      // OPTIMIZATION: Fetch all images in parallel using Future.wait
      final List<Future<dynamic>> allFutures = [];
      final List<int> productIds = [];

      for (var productId in productAttachments.keys) {
        for (var attachmentId in productAttachments[productId]!) {
          allFutures.add(_attachmentService.downloadAttachment(attachmentId));
          productIds.add(productId);
        }
      }

      try {
        final attachmentResults = await Future.wait(allFutures, eagerError: false);

        for (int i = 0; i < attachmentResults.length; i++) {
          final result = attachmentResults[i];
          if (result != null && result.data.isNotEmpty) {
            final productId = productIds[i];
            // Store only the first image per product to avoid duplicate entries
            if (!images.containsKey(productId)) {
              images[productId] = result.data;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error during parallel image fetch: $e');
      }

      if (mounted) {
        setState(() {
          _imageCache = images;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading product images: $e');
    }
  }

  Future<void> _loadCategoryImages() async {
    try {
      final Map<int, Uint8List> images = {};

      for (var category in _allCategories) {
        final categoryId = category['categoryId'] as int?;
        if (categoryId == null) continue;

        try {
          final attachments = await _attachmentService.getAttachmentsByEntity('CATEGORY', categoryId);
          if (attachments.isNotEmpty) {
            final firstAttachment = attachments.first as Map<String, dynamic>;
            final attachmentId = firstAttachment['attachmentId'] as int?;

            if (attachmentId != null) {
              final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
              if (attachmentDownload.data.isNotEmpty) {
                images[categoryId] = attachmentDownload.data;
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error loading image for category $categoryId: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _categoryImageCache = images;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading category images: $e');
    }
  }

  Future<void> _applyFilters() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    List<Map<String, dynamic>> baseProducts = [];

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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_isLoading && _selectedTabIndex == 0) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
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
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Chargement des données...',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final paginatedProducts = PaginationService(itemsPerPage: 12).getPageItems(
      _filteredProducts,
      _paginationState.currentPage,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeader(isMobile),
            _buildTabBar(isMobile),
            if (_selectedTabIndex == 0) ...[
              _buildFiltersSection(isMobile),
              Expanded(child: _buildProductsContent(paginatedProducts, isMobile)),
              if (_filteredProducts.isNotEmpty) _buildPaginationBar(isMobile),
            ] else ...[
              Expanded(child: _buildCategoriesSection(isMobile)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isMobile ? 12 : 16),
        left: isMobile ? 16 : 24,
        right: isMobile ? 16 : 24,
        bottom: isMobile ? 16 : 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: isMobile ? 24 : 32,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestion Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedTabIndex == 0
                      ? '${_filteredProducts.length} produits trouvés'
                      : '${_allCategories.length} catégories',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isMobile ? 12 : 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isMobile) {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _selectedTabIndex == 0 ? AppColors.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_rounded,
                      color: _selectedTabIndex == 0 ? AppColors.primary : Colors.grey[600],
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Produits',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _selectedTabIndex == 0 ? AppColors.primary : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _selectedTabIndex == 1 ? AppColors.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.category_rounded,
                      color: _selectedTabIndex == 1 ? AppColors.primary : Colors.grey[600],
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Catégories',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _selectedTabIndex == 1 ? AppColors.primary : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gestion des Catégories',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _allCategories.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune catégorie',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _allCategories.length,
              itemBuilder: (context, index) {
                final category = _allCategories[index];
                final categoryId = category['categoryId'] as int?;
                final categoryImage = categoryId != null ? _categoryImageCache[categoryId] : null;
                return _buildCategoryItem(category, categoryImage, isMobile);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category, Uint8List? image, bool isMobile) {
    final categoryId = category['categoryId'] as int?;
    final name = category['name'] ?? 'Sans nom';
    final description = category['description'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: image != null
                    ? Image.memory(image, fit: BoxFit.cover)
                    : Icon(Icons.category_rounded, color: Colors.grey[400], size: 40),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  ],
                ],
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Modifier'),
                      ],
                    ),
                    onTap: () => _showCategoryDialog(category: category),
                  ),
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Supprimer', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                    onTap: () => _deleteCategory(categoryId),
                  ),
                ],
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _showMobileCategoryMenu(category),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMobileCategoryMenu(Map<String, dynamic> category) {
    final categoryId = category['categoryId'] as int?;
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Modifier'),
            onTap: () {
              Navigator.pop(context);
              _showCategoryDialog(category: category);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_rounded, color: Colors.red),
            title: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteCategory(categoryId);
            },
          ),
        ],
      ),
    );
  }
  void _showCategoryDialog({Map<String, dynamic>? category}) {
    showDialog(
      context: context,
      builder: (context) => CategoryDialog(
        onCategorySaved: () {
          _loadData();
        },
        category: category,
        categoryService: _categoryService,
        attachmentService: _attachmentService,
      ),
    );
  }


  Future<void> _deleteCategory(int? categoryId) async {
    if (categoryId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette catégorie ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _categoryService.deleteCategory(categoryId);
      _showSnackBar('Catégorie supprimée avec succès');
      _loadData();
    } catch (e) {
      _showSnackBar('Erreur lors de la suppression: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // PRODUCTS SECTION WIDGETS (same as before)

  Widget _buildFiltersSection(bool isMobile) {
    final isTablet = MediaQuery.of(context).size.width < 900;

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

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
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

  Widget _buildSearchField() {
    return TextField(
      onChanged: (v) async {
        _searchQuery = v;
        await _applyFilters();
      },
      decoration: InputDecoration(
        hintText: 'Rechercher des produits...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () {
            setState(() => _searchQuery = '');
            _applyFilters();
          },
        )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
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
            color: Colors.grey[700],
          ),
        ),
        RangeSlider(
          values: RangeValues(_minPrice, _maxPrice),
          min: 0,
          max: 1000,
          divisions: 100,
          activeColor: AppColors.primary,
          onChanged: (v) {
            setState(() {
              _minPrice = v.start;
              _maxPrice = v.end;
            });
          },
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
              .map((o) => DropdownMenuItem(
              value: o, child: Text(_getSortLabel(o))))
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

  Widget _buildProductsContent(
      List<Map<String, dynamic>> products, bool isMobile) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: isMobile ? 56 : 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun produit trouvé',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: _buildResponsiveGrid(products, isMobile),
    );
  }

  Widget _buildResponsiveGrid(
      List<Map<String, dynamic>> products, bool isMobile) {
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
            childAspectRatio: crossCount == 1 ? 1.4 : 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (c, i) => TweenAnimationBuilder(
            duration: Duration(milliseconds: 300 + (i * 50)),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: _buildProductCard(products[i]),
          ),
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final int? companyId =
        product['companyId'] ?? product['company']?['companyId'];
    final int? categoryId =
        product['categoryId'] ?? product['category']?['categoryId'];
    final int? productId = product['productId'] as int?;
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
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
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: _buildProductImage(productId),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? Colors.green.withOpacity(0.9)
                              : Colors.red.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (isAvailable ? Colors.green : Colors.red)
                                  .withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Text(
                          isAvailable ? 'Disponible' : 'Rupture',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
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
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$companyName • $categoryName',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${price.toStringAsFixed(2)} DT',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
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

  Widget _buildProductImage(int? productId) {
    if (productId == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[100],
        child: Icon(
          Icons.inventory_2_rounded,
          size: 48,
          color: Colors.grey[400],
        ),
      );
    }

    if (_imageCache.containsKey(productId)) {
      return Image.memory(
        _imageCache[productId]!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[100],
      child: Icon(
        Icons.inventory_2_rounded,
        size: 48,
        color: Colors.grey[400],
      ),
    );
  }

  Future<Map<String, dynamic>?> _getCompanyById(int companyId) async {
    if (_companyMap.containsValue(companyId)) {
      final name = _companyMap.entries
          .firstWhere((e) => e.value == companyId)
          .key;
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
      final name = _categoryMap.entries
          .firstWhere((e) => e.value == categoryId)
          .key;
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

  Widget _buildPaginationBar(bool isMobile) {
    final totalPages =
    PaginationService(itemsPerPage: 12).getTotalPages(_filteredProducts.length);
    final startItem =
        (_paginationState.currentPage - 1) * _paginationState.itemsPerPage + 1;
    final endItem = (_paginationState.currentPage *
        _paginationState.itemsPerPage)
        .clamp(0, _filteredProducts.length);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: isMobile
          ? Row(
        children: [
          Text(
            'Affichage $startItem-$endItem sur ${_filteredProducts.length}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _paginationState.currentPage > 1
                    ? () => setState(() => _paginationState =
                    _paginationState.copyWith(
                        currentPage:
                        _paginationState.currentPage - 1))
                    : null,
                icon: const Icon(Icons.chevron_left),
                constraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
                iconSize: 20,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page ${_paginationState.currentPage} / $totalPages',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: _paginationState.currentPage < totalPages
                    ? () => setState(() => _paginationState =
                    _paginationState.copyWith(
                        currentPage:
                        _paginationState.currentPage + 1))
                    : null,
                icon: const Icon(Icons.chevron_right),
                constraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
                iconSize: 20,
              ),
            ],
          ),
        ],
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage $startItem-$endItem sur ${_filteredProducts.length}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _paginationState.currentPage > 1
                    ? () => setState(() => _paginationState =
                    _paginationState.copyWith(
                        currentPage:
                        _paginationState.currentPage - 1))
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Page précédente',
                constraints:
                const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page ${_paginationState.currentPage} / $totalPages',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: _paginationState.currentPage < totalPages
                    ? () => setState(() => _paginationState =
                    _paginationState.copyWith(
                        currentPage:
                        _paginationState.currentPage + 1))
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Page suivante',
                constraints:
                const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

