import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/product_service.dart';
import '../widgets/dashboard_card.dart';
import 'add_product_page.dart';
import 'details_product_page.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> with SingleTickerProviderStateMixin {
  final ProductService _productService = ProductService();
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  static const int currentUserId = 1;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
      final products = await _productService.getAllProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final double padding = isMobile ? 16 : 24;
    final double titleSize = isMobile ? 26 : 32;
    final double cardCrossCount = isMobile ? 2 : 4;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                  'Tableau de bord',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gérez votre boutique en un click',
                  style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cardCrossCount.toInt(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isMobile ? 2.2 : 3,
            ),
            delegate: SliverChildListDelegate([
              _buildAnimatedStatsCard(
                title: 'Total Produits',
                value: '${_products.length}',
                icon: Icons.inventory_2_outlined,
                color: AppColors.primary,
                delay: 0,
              ),
              _buildAnimatedStatsCard(
                title: 'Commandes',
                value: '156',
                icon: Icons.shopping_bag_outlined,
                color: AppColors.success,
                delay: 100,
              ),
              _buildAnimatedStatsCard(
                title: 'Revenus',
                value: '12.450 DT',
                icon: Icons.trending_up,
                color: AppColors.accent,
                delay: 200,
              ),
              _buildAnimatedStatsCard(
                title: 'Clients',
                value: '89',
                icon: Icons.people_outline,
                color: AppColors.info,
                delay: 300,
              ),
            ]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
        SliverToBoxAdapter(
          child: _buildRecentProductsHeader(context, isMobile),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
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
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  'Aucun produit trouvé',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Commencez par ajouter votre premier produit',
                  style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        )
            : SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final product = _products[index];
              return _buildProductCard(product, isMobile, context);
            },
            childCount: _products.length > 5 ? 5 : _products.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildAnimatedStatsCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - opacity)),
            child: DashboardCard(
              title: title,
              value: value,
              icon: icon,
              color: color,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentProductsHeader(BuildContext context, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Produits récents',
          style: TextStyle(
            fontSize: isMobile ? 20 : 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddProductPage()),
              );
              _refresh();
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(
              'Ajouter',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 14 : 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.textLight,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isMobile, BuildContext context) {
    final int productId = product['productId'] ?? 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.surfaceVariant.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsProductPage(productId: productId),
                  ),
                );
                _refresh();
              },
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Row(
                  children: [
                    Container(
                      width: isMobile ? 50 : 60,
                      height: isMobile ? 50 : 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.2),
                            AppColors.primary.withOpacity(0.05)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: AppColors.primary,
                        size: isMobile ? 28 : 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['productName'] ?? 'Produit sans nom',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: isMobile ? 15 : 16,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product['available'] == true ? 'Disponible' : 'Indisponible',
                            style: TextStyle(
                              color: product['available'] == true
                                  ? AppColors.success
                                  : Colors.red,
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (product['productDescription'] != null &&
                              product['productDescription'].toString().isNotEmpty)
                            Text(
                              product['productDescription'].toString().length > 50
                                  ? '${product['productDescription'].toString().substring(0, 50)}...'
                                  : product['productDescription'].toString(),
                              style: TextStyle(
                                color: AppColors.textSecondary.withOpacity(0.7),
                                fontSize: isMobile ? 12 : 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${product['productPrice']?.toStringAsFixed(2) ?? '0.00'} DT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 15 : 16,
                            color: AppColors.accent,
                          ),
                        ),
                        if (product['discountPercentage'] != null &&
                            (product['discountPercentage'] as num) > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '-${product['discountPercentage']}%',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}