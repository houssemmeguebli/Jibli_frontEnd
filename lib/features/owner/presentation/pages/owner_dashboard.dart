import 'package:flutter/material.dart';
import 'package:frontend/features/owner/presentation/pages/add_product_page.dart';
import 'package:frontend/features/owner/presentation/pages/owner_products_page.dart';
import 'dart:typed_data';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../widgets/owner_dashboard_card.dart';
import 'owner_add_product_page.dart';
import 'owner_details_product_page.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard>
    with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();
  final AttachmentService _attachmentService = AttachmentService();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  static const int currentUserId = 2;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final Map<int, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadProducts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final products =
      await _productService.getProductByUserId(currentUserId);
      setState(() {
        _products = List<Map<String, dynamic>>.from(products);
        _isLoading = false;
      });

      for (int i = 0; i < (_products.length > 5 ? 5 : _products.length); i++) {
        final product = _products[i];
        final attachments = product['attachments'] as List<dynamic>?;
        if (attachments != null && attachments.isNotEmpty) {
          final firstAttachmentId = attachments[0]['attachmentId'] as int;
          if (!_imageCache.containsKey(firstAttachmentId)) {
            _preloadImage(firstAttachmentId);
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _preloadImage(int attachmentId) async {
    try {
      final bytes = await _attachmentService.downloadAttachment(attachmentId);
      if (mounted) {
        setState(() {
          _imageCache[attachmentId] = bytes as Uint8List;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    _imageCache.clear();
    await _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final bool isTablet =
        MediaQuery.of(context).size.width >= 600 &&
            MediaQuery.of(context).size.width < 1200;

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FB),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              _buildSliverAppBar(isMobile),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : isTablet ? 24 : 32,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsGrid(isMobile, isTablet),
                      const SizedBox(height: 32),
                      _buildRecentProductsHeader(context, isMobile),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _isLoading
                  ? const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              )
                  : _products.isEmpty
                  ? SliverToBoxAdapter(
                child: _buildEmptyState(isMobile),
              )
                  : SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : isTablet ? 24 : 32,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final product = _products[index];
                      return _buildProductCard(
                          product, isMobile, context);
                    },
                    childCount:
                    _products.length > 5 ? 5 : _products.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isMobile) {
    return SliverAppBar(
      expandedHeight: isMobile ? 120 : 140,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.85),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: isMobile ? 16 : 28,
              right: isMobile ? 16 : 28,
              top: isMobile ? 16 : 24,
              bottom: isMobile ? 16 : 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Tableau de bord',
                  style: TextStyle(
                    fontSize: isMobile ? 24 : 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gérez votre boutique',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(bool isMobile, bool isTablet) {
    final crossCount = isMobile ? 2 : isTablet ? 3 : 4;
    final childAspectRatio = isMobile ? 1.8 : isTablet ? 2.0 : 2.2;

    return GridView.count(
      crossAxisCount: crossCount,
      crossAxisSpacing: isMobile ? 12 : 14,
      mainAxisSpacing: isMobile ? 12 : 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: childAspectRatio,
      children: [
        _buildStatCard(
          title: 'Total Produits',
          value: '${_products.length}',
          icon: Icons.inventory_2_outlined,
          color: AppColors.primary,
          delay: 0,
          isMobile: isMobile,
        ),
        _buildStatCard(
          title: 'Commandes',
          value: '156',
          icon: Icons.shopping_bag_outlined,
          color: const Color(0xFF10B981),
          delay: 80,
          isMobile: isMobile,
        ),
        _buildStatCard(
          title: 'Revenus',
          value: '12 KDT',
          icon: Icons.trending_up,
          color: const Color(0xFFF59E0B),
          delay: 160,
          isMobile: isMobile,
        ),
        _buildStatCard(
          title: 'Clients',
          value: '89',
          icon: Icons.people_outline,
          color: const Color(0xFF3B82F6),
          delay: 240,
          isMobile: isMobile,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required int delay,
    required bool isMobile,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: 0.9 + (opacity * 0.1),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.98),
                  ],
                ),
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
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isMobile ? 8 : 10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            color: color,
                            size: isMobile ? 18 : 20,
                          ),
                        ),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                value,
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 22,
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
                                  fontSize: isMobile ? 11 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                  letterSpacing: 0.1,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  Widget _buildEmptyState(bool isMobile) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun produit trouvé',
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F2937),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Commencez par ajouter votre premier produit à votre catalogue',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddProductPage()),
              );
              _refresh();
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Ajouter un produit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentProductsHeader(BuildContext context, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Produits récents',
              style: TextStyle(
                fontSize: isMobile ? 22 : 26,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1F2937),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vos ${_products.length} produits actifs',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent,
                    AppColors.accent.withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AddProductDialog(
                      onProductAdded: _refresh,
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isMobile,
      BuildContext context) {
    final int productId = product['productId'] ?? 0;
    final attachments = product['attachments'] as List<dynamic>?;
    final int? firstAttachmentId = attachments != null && attachments.isNotEmpty
        ? attachments[0]['attachmentId'] as int
        : null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: 0.95 + (scale * 0.05),
          child: Opacity(
            opacity: scale,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () async {
                    final result =
                    await DetailsProductPage.showProductDetailsDialog(
                      context,
                      productId: productId,
                    );
                    if (result == true) {
                      _refresh();
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 14 : 18),
                    child: Row(
                      children: [
                        _buildProductImage(firstAttachmentId, isMobile),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProductInfo(product, isMobile),
                        ),
                        const SizedBox(width: 12),
                        _buildProductPrice(product, isMobile),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductImage(int? firstAttachmentId, bool isMobile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: isMobile ? 70 : 90,
        height: isMobile ? 70 : 90,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.primary.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: firstAttachmentId == null
            ? Icon(
          Icons.inventory_2_rounded,
          color: AppColors.primary,
          size: isMobile ? 32 : 40,
        )
            : _imageCache.containsKey(firstAttachmentId)
            ? Image.memory(
          _imageCache[firstAttachmentId]!,
          fit: BoxFit.cover,
        )
            : FutureBuilder<Uint8List>(
          future: _attachmentService
              .downloadAttachment(firstAttachmentId)
              .then((download) => download.data),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _imageCache[firstAttachmentId] = snapshot.data!;
                  });
                }
              });
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
              );
            } else if (snapshot.hasError) {
              return Icon(
                Icons.broken_image,
                color: Colors.grey.shade400,
                size: isMobile ? 32 : 40,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildProductInfo(Map<String, dynamic> product, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product['productName'] ?? 'Produit sans nom',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: isMobile ? 16 : 18,
            color: const Color(0xFF1F2937),
            letterSpacing: -0.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: product['available'] == true
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                product['available'] == true ? 'Disponible' : 'Indisponible',
                style: TextStyle(
                  color: product['available'] == true
                      ? const Color(0xFF10B981)
                      : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (product['discountPercentage'] != null &&
                (product['discountPercentage'] as num) > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department,
                        size: 12, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      '-${product['discountPercentage']}%',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (product['productDescription'] != null &&
            product['productDescription'].toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            product['productDescription'].toString().length > 60
                ? '${product['productDescription'].toString().substring(0, 60)}...'
                : product['productDescription'].toString(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isMobile ? 12 : 13,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildProductPrice(Map<String, dynamic> product, bool isMobile) {
    final hasDiscount = product['discountPercentage'] != null &&
        (product['discountPercentage'] as num) > 0;
    final originalPrice =
    (product['productPrice'] ?? 0).toDouble();
    final finalPrice = (product['productFinalePrice'] ?? originalPrice).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${finalPrice.toStringAsFixed(2)} DT',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: isMobile ? 17 : 19,
            color: AppColors.accent,
            letterSpacing: -0.3,
          ),
        ),
        if (hasDiscount) ...[
          const SizedBox(height: 2),
          Text(
            '${originalPrice.toStringAsFixed(2)} DT',
            style: TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}