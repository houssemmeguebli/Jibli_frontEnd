import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/category_service.dart';
import '../../../../core/services/cart_item_service.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/promotion_banner.dart';
import '../widgets/product_card.dart';
import 'product_detail_page.dart';
import 'cart_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ProductService _productService = ProductService();
  final CategoryService _categoryService = CategoryService();
  final CartItemService _cartItemService = CartItemService('http://localhost:8080');

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _featuredProducts = [];
  bool _isLoading = true;
  int _selectedCategoryIndex = 0;
  String _selectedFilter = 'all';
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final products = await _productService.getAllProducts();
      final categories = await _categoryService.getAllCategories();

      setState(() {
        _products = products;
        _featuredProducts = products.take(6).toList();
        _categories = [{'id': 0, 'name': 'Tout', 'icon': Icons.shopping_bag}, ...categories];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    final productId = product['productId'] ?? product['id'];
    if (productId == null) return;

    try {
      await _cartItemService.createCartItem({
        'productId': productId,
        'quantity': 1,
        'cartId': 1,
      });

      setState(() {
        _cartItemCount++;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['productName'] ?? product['name'] ?? 'Produit'} ajouté au panier'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildModernAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildPromotionSection(),
                _buildProductsSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.categoryGrocery],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour ! 👋',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Découvrez nos meilleurs produits',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
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
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: IconButton(
                              icon: Stack(
                                children: [
                                  const Icon(
                                    Icons.shopping_cart_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  if (_cartItemCount > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          '$_cartItemCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CartPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildPromotionSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const PromotionBanner(),
    );
  }

  Widget _buildProductsSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Produits populaires',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.6,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
            ),
            itemCount: _featuredProducts.length,
            itemBuilder: (context, index) {
              final product = _featuredProducts[index];
              return _buildProductCard(product);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final isAvailable = product['available'];

    return ProductCard(
      name: product['productName'] ?? product['name'] ?? 'Produit',
      price: (product['productPrice'] ?? 0).toDouble(),
      imageUrl: product['imageUrl'],
      discount: product['discountPercentage'],
      finalPrice: product['productFinalePrice'],
      isAvailable: isAvailable == true || isAvailable == 1 || isAvailable == '1',
      onTap: () {
        final productId = product['productId'];
        if (productId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailPage(productId: productId),
            ),
          );
        }
      },
      onAddToCart: () => _addToCart(product),
    );
  }
}