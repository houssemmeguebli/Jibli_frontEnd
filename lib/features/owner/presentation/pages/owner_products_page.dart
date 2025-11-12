import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import '../../../../core/services/pagination_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/category_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../../../../core/services/auth_service.dart';
import 'add_product_page.dart';
import 'owner_add_product_page.dart';
import 'owner_details_product_page.dart';

class OwnerProductsPage extends StatefulWidget {
  const OwnerProductsPage({super.key});

  @override
  State<OwnerProductsPage> createState() => _OwnerProductsPageState();
}

class _OwnerProductsPageState extends State<OwnerProductsPage> with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();
  final AttachmentService _attachmentService = AttachmentService();
  final AuthService _authService = AuthService();
  final PaginationService _paginationService = PaginationService(itemsPerPage: 10);

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'Tous';
  int _currentPage = 1;
  int? _currentUserId;
  Map<int, Uint8List> _imageCache = {};
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
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await _authService.getUserId();
    setState(() {
      _currentUserId = userId;
    });
    _loadProducts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoading = true);

      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final products = await _productService.getProductByUserId(_currentUserId!);
      setState(() {
        _products = List<Map<String, dynamic>>.from(products);
        _filteredProducts = _products;
        _isLoading = false;
      });

      await _loadProductImages();
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackBar('Erreur de chargement: $e', isError: true);
      }
    }
  }

  Future<void> _loadProductImages() async {
    try {
      final Map<int, Uint8List> images = {};

      for (var product in _products) {
        final productId = product['productId'] as int?;
        if (productId == null) continue;

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
          continue;
        }
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

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_products);

    // Apply availability filter
    if (_selectedFilter == 'Disponible') {
      filtered = filtered.where((product) => product['available'] == true).toList();
    } else if (_selectedFilter == 'Épuisé') {
      filtered = filtered.where((product) => product['available'] == false).toList();
    } else if (_selectedFilter == 'Promotion') {
      filtered = filtered.where((product) => (product['discountPercentage'] ?? 0) > 0).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        final name = (product['productName'] ?? '').toLowerCase();
        final description = (product['productDescription'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();
    }

    setState(() {
      _filteredProducts = filtered;
      _currentPage = 1;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Map<String, int> _getProductStats() {
    final total = _products.length;
    final available = _products.where((p) => p['available'] == true).length;
    final outOfStock = _products.where((p) => p['available'] == false).length;
    final onSale = _products.where((p) => (p['discountPercentage'] ?? 0) > 0).length;

    return {
      'total': total,
      'available': available,
      'outOfStock': outOfStock,
      'onSale': onSale,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? _buildLoadingState()
          : FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(isMobile)),
            if (!isMobile)
              SliverToBoxAdapter(child: _buildStatsCards(isMobile)),
            SliverToBoxAdapter(child: _buildFiltersSection(isMobile)),
            _filteredProducts.isEmpty
                ? SliverFillRemaining(child: _buildEmptyState(isMobile))
                : SliverPadding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              sliver: _buildProductsGrid(isMobile),
            ),
            if (!_isLoading && _filteredProducts.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: _buildPaginationBar(isMobile),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Skeletonizer(
        enabled: true,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(isMobile)),
            if (!isMobile)
              SliverToBoxAdapter(child: _buildSkeletonStatsCards(isMobile)),
            SliverToBoxAdapter(child: _buildFiltersSection(isMobile)),
            SliverPadding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              sliver: _buildSkeletonProductsGrid(isMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonStatsCards(bool isMobile) {
    final crossCount = isMobile ? 2 : 4;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: GridView.count(
        crossAxisCount: crossCount,
        crossAxisSpacing: isMobile ? 8 : 12,
        mainAxisSpacing: isMobile ? 8 : 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: isMobile ? 1.6 : 1.8,
        children: List.generate(4, (index) => _buildSkeletonStatCard(isMobile)),
      ),
    );
  }

  Widget _buildSkeletonStatCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: isMobile ? 32 : 40,
              height: isMobile ? 32 : 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isMobile ? 40 : 60,
                  height: isMobile ? 16 : 22,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 4),
                Container(
                  width: isMobile ? 60 : 80,
                  height: isMobile ? 10 : 12,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonProductsGrid(bool isMobile) {
    int crossAxisCount;
    if (isMobile) {
      crossAxisCount = 2;
    } else {
      final screenWidth = MediaQuery.of(context).size.width;
      if (screenWidth > 1200) {
        crossAxisCount = 4;
      } else if (screenWidth > 800) {
        crossAxisCount = 3;
      } else {
        crossAxisCount = 2;
      }
    }

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isMobile ? 10 : 16,
        mainAxisSpacing: isMobile ? 10 : 16,
        childAspectRatio: isMobile ? 0.65 : 0.75,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildSkeletonProductCard(isMobile),
        childCount: 8,
      ),
    );
  }

  Widget _buildSkeletonProductCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
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
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(isMobile ? 16 : 20),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: isMobile ? 14 : 16,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity * 0.7,
                    height: isMobile ? 11 : 12,
                    color: Colors.grey[300],
                  ),
                  const Spacer(),
                  Container(
                    width: isMobile ? 60 : 80,
                    height: isMobile ? 14 : 16,
                    color: Colors.grey[300],
                  ),
                ],
              ),
            ),
          ),
        ],
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
      child: Column(
        children: [
          Row(
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
                      'Produits',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 22 : 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_products.length} produits trouvé',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isMobile ? 12 : 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _loadProducts,
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 24),
                      tooltip: 'Actualiser',
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),

                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AddProductDialog(
                              onProductAdded: _loadProducts,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 10 : 12,
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: isMobile ? 20 : 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isMobile) {
    final stats = _getProductStats();
    final crossCount = isMobile ? 2 : 4;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: GridView.count(
        crossAxisCount: crossCount,
        crossAxisSpacing: isMobile ? 8 : 12,
        mainAxisSpacing: isMobile ? 8 : 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: isMobile ? 1.6 : 1.8,
        children: [
          _buildStatCard(
            icon: Icons.inventory_rounded,
            title: 'Total',
            value: '${stats['total']}',
            subtitle: 'produits',
            color: Colors.blue,
            gradient: [Colors.blue[400]!, Colors.blue[600]!],
            isMobile: isMobile,
          ),
          _buildStatCard(
            icon: Icons.check_circle_rounded,
            title: 'Dispo',
            value: '${stats['available']}',
            subtitle: 'en stock',
            color: Colors.green,
            gradient: [Colors.green[400]!, Colors.green[600]!],
            isMobile: isMobile,
          ),
          _buildStatCard(
            icon: Icons.local_offer_rounded,
            title: 'Promo',
            value: '${stats['onSale']}',
            subtitle: 'en promo',
            color: Colors.orange,
            gradient: [Colors.orange[400]!, Colors.orange[600]!],
            isMobile: isMobile,
          ),
          _buildStatCard(
            icon: Icons.warning_rounded,
            title: 'Épuisé',
            value: '${stats['outOfStock']}',
            subtitle: 'rupture',
            color: Colors.red,
            gradient: [Colors.red[400]!, Colors.red[600]!],
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required List<Color> gradient,
    required bool isMobile,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: 0.9 + (opacity * 0.1),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -15,
                    right: -15,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isMobile ? 6 : 10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            color: color,
                            size: isMobile ? 16 : 20,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value,
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1F2937),
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        );
      },
    );
  }

  Widget _buildFiltersSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 12 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: isMobile ? 13 : 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey[400],
                  size: isMobile ? 20 : 24,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey[400]),
                  onPressed: () {
                    setState(() => _searchQuery = '');
                    _applyFilters();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tous', _products.length, isMobile),
                const SizedBox(width: 8),
                _buildFilterChip('Disponible', _getProductStats()['available']!, isMobile),
                const SizedBox(width: 8),
                _buildFilterChip('Épuisé', _getProductStats()['outOfStock']!, isMobile),
                const SizedBox(width: 8),
                _buildFilterChip('Promotion', _getProductStats()['onSale']!, isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, bool isMobile) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = label);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 8 : 10,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 12 : 13,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 10 : 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 24 : 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 24 : 32),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchQuery.isNotEmpty || _selectedFilter != 'Tous'
                    ? Icons.search_off_rounded
                    : Icons.inventory_2_outlined,
                size: isMobile ? 56 : 80,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'Tous'
                  ? 'Aucun produit trouvé'
                  : 'Aucun produit disponible',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty || _selectedFilter != 'Tous'
                  ? 'Essayez de modifier vos filtres'
                  : 'Commencez à ajouter vos produits',
              style: TextStyle(
                fontSize: isMobile ? 13 : 15,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            if (_searchQuery.isEmpty && _selectedFilter == 'Tous')
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddProductPage(),
                    ),
                  );
                  _loadProducts();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter un produit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 24,
                    vertical: isMobile ? 12 : 14,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedFilter = 'Tous';
                  });
                  _applyFilters();
                },
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Réinitialiser les filtres'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 24,
                    vertical: isMobile ? 12 : 14,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid(bool isMobile) {
    int crossAxisCount;
    double childAspectRatio;

    if (isMobile) {
      crossAxisCount = 2;
      childAspectRatio = 0.65;
    } else {
      final screenWidth = MediaQuery.of(context).size.width;
      if (screenWidth > 1200) {
        crossAxisCount = 4;
        childAspectRatio = 0.75;
      } else if (screenWidth > 800) {
        crossAxisCount = 3;
        childAspectRatio = 0.75;
      } else {
        crossAxisCount = 2;
        childAspectRatio = 0.75;
      }
    }

    final paginatedProducts = _paginationService.getPageItems(_filteredProducts, _currentPage);

    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: isMobile ? 10 : 16,
        mainAxisSpacing: isMobile ? 10 : 16,
        childAspectRatio: childAspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          return TweenAnimationBuilder(
            duration: Duration(milliseconds: 300 + (index * 50)),
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
            child: _buildProductCard(paginatedProducts[index], isMobile),
          );
        },
        childCount: paginatedProducts.length,
      ),
    );
  }

  Widget _buildPaginationBar(bool isMobile) {
    final totalPages = _paginationService.getTotalPages(_filteredProducts.length);
    final startItem = (_currentPage - 1) * 10 + 1;
    final endItem = (startItem + 9 > _filteredProducts.length) ? _filteredProducts.length : startItem + 9;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isMobile
          ? Column(
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
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                iconSize: 20,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_currentPage / $totalPages',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Page précédente',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_currentPage / $totalPages',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Page suivante',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isMobile) {
    final productId = product['productId'] ?? 0;
    final hasDiscount = (product['discountPercentage'] ?? 0) > 0;
    final originalPrice = product['productPrice']?.toDouble() ?? 0.0;
    final finalPrice = product['productFinalePrice']?.toDouble() ?? originalPrice;
    final isAvailable = product['available'] ?? true;

    return GestureDetector(
      onTap: () async {
        final result = await DetailsProductPage.showProductDetailsDialog(
          context,
          productId: productId,
        );
        if (result == true) {
          _loadProducts();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
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
            // Image Section
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(isMobile ? 16 : 20),
                    ),
                    child: _buildProductImage(productId),
                  ),
                  // Status Badge
                  Positioned(
                    top: isMobile ? 8 : 12,
                    left: isMobile ? 8 : 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 10,
                        vertical: isMobile ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (isAvailable ? Colors.green : Colors.red).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        isAvailable ? 'Disponible' : 'Épuisé',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 9 : 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Discount Badge
                  if (hasDiscount)
                    Positioned(
                      top: isMobile ? 8 : 12,
                      right: isMobile ? 8 : 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red[400]!, Colors.red[600]!],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '-${product['discountPercentage']}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 10 : 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Content Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['productName'] ?? 'Produit sans nom',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isMobile ? 14 : 16,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (product['productDescription'] != null)
                      Expanded(
                        child: Text(
                          product['productDescription'].toString().length > 50
                              ? '${product['productDescription'].toString().substring(0, 50)}...'
                              : product['productDescription'].toString(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isMobile ? 11 : 12,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        if (hasDiscount) ...[
                          Expanded(
                            child: Text(
                              '${originalPrice.toStringAsFixed(2)} DT',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey[500],
                                fontSize: isMobile ? 11 : 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            hasDiscount
                                ? '${finalPrice.toStringAsFixed(2)} DT'
                                : '${originalPrice.toStringAsFixed(2)} DT',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: isMobile ? 14 : 16,
                              color: hasDiscount ? Colors.green[600] : AppColors.accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      ),
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

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AddCategoryDialog(
        onCategoryAdded: () {
          _showSnackBar('Catégorie ajoutée avec succès');
        },
      ),
    );
  }
}

class AddCategoryDialog extends StatefulWidget {
  final VoidCallback onCategoryAdded;

  const AddCategoryDialog({super.key, required this.onCategoryAdded});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final CategoryService _categoryService = CategoryService();
  final AttachmentService _attachmentService = AttachmentService();
  final ImagePicker _picker = ImagePicker();
  
  Uint8List? _selectedImageBytes;
  String? _selectedFileName;
  String? _selectedContentType;
  bool _isLoading = false;
  int? _currentUserId;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await _authService.getUserId();
    setState(() {
      _currentUserId = userId;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
        uploadInput.accept = 'image/*';
        uploadInput.click();

        uploadInput.onChange.listen((event) async {
          final files = uploadInput.files;
          if (files != null && files.isNotEmpty) {
            final file = files.first;
            final reader = html.FileReader();
            reader.readAsArrayBuffer(file);
            await reader.onLoadEnd.first;
            setState(() {
              _selectedImageBytes = reader.result as Uint8List;
              _selectedFileName = file.name.isEmpty ? 'category.jpg' : file.name;
              _selectedContentType = file.type.isEmpty ? 'image/jpeg' : file.type;
            });
          }
        });
      } else {
        final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedFileName = image.name.isEmpty ? 'category.jpg' : image.name;
            _selectedContentType = image.mimeType ?? 'image/jpeg';
          });
        }
      }
    } catch (e) {
      _showSnackBar('Erreur lors de la sélection de l\'image: $e', isError: true);
    }
  }

  Future<void> _createCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final categoryData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'userId': _currentUserId,
      };

      final createdCategory = await _categoryService.createCategory(categoryData);
      final categoryId = createdCategory['categoryId'] ?? createdCategory['id'];

      if (_selectedImageBytes != null && categoryId != null) {
        await _attachmentService.createAttachment(
          fileBytes: _selectedImageBytes!,
          fileName: _selectedFileName!,
          contentType: _selectedContentType!,
          entityType: 'CATEGORY',
          entityId: categoryId,
        );
      }

      widget.onCategoryAdded();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showSnackBar('Erreur lors de la création: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[400]!, Colors.orange[600]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.category_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Ajouter une catégorie',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la catégorie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: _selectedImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedImageBytes!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Ajouter une image (optionnel)',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createCategory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Créer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}