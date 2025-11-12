import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:frontend/Core/services/company_service.dart';
import 'package:frontend/core/services/cart_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/cart_item_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../../../../core/services/cart_notifier.dart';
import '../../../../core/services/auth_service.dart';
import 'cutomer_order_page.dart';
import 'product_detail_page.dart';
import 'dart:typed_data';

class CartPage extends StatefulWidget {
  final Function(int)? onCartUpdated;

  const CartPage({super.key, this.onCartUpdated});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with TickerProviderStateMixin {
  final CartService _cartService = CartService();
  final CartItemService _cartItemService = CartItemService();
  final ProductService _productService = ProductService();
  final CompanyService _companyService = CompanyService();
  final AttachmentService _attachmentService = AttachmentService();
  final CartNotifier _cartNotifier = CartNotifier();
  int? currentUserId;

  late List<Map<String, dynamic>> _groupedCarts;
  late Map<int, Uint8List?> _productImages;
  late bool _isLoading;
  late double _totalAmount;
  bool _isUpdatingInternally = false;

  @override
  void initState() {
    super.initState();
    _initializeState();
    _cartNotifier.addListener(_onCartChanged);
    _loadGroupedCarts();
  }

  @override
  void dispose() {
    _cartNotifier.removeListener(_onCartChanged);
    super.dispose();
  }

  void _initializeState() {
    _groupedCarts = [];
    _productImages = {};
    _isLoading = true;
    _totalAmount = 0.0;
  }

  Future<void> _loadGroupedCarts() async {
    if (!mounted) return;

    _setLoading(true);

    _updateState(() {
      _groupedCarts = List.generate(2, (index) => {
        'cartId': index + 1,
        'companyName': 'Entreprise skeleton ${index + 1}',
        'totalPrice': 45.99,
        'deliveryFee': 5.0,
        'cartItems': List.generate(2, (itemIndex) => {
          'cartItemId': itemIndex + 1,
          'productId': itemIndex + 1,
          'productName': 'Produit skeleton ${itemIndex + 1}',
          'quantity': 2,
          'productPrice': 25.99,
          'productFinalePrice': 19.99,
        }),
      });
    });

    try {
      final authService = AuthService();
      currentUserId = await authService.getUserId();

      if (currentUserId == null) {
        debugPrint('❌ User not logged in');
        throw Exception('Utilisateur non connecté');
      }

      debugPrint('🔍 Loading carts for user: $currentUserId');
      final groupedCarts = await _cartService.getUserCartsGroupedByCompany(currentUserId!);
      debugPrint('📦 Loaded ${groupedCarts.length} carts');

      double totalAmount = 0.0;
      for (var cart in groupedCarts) {
        final cartItems = cart['cartItems'] as List<dynamic>? ?? [];
        debugPrint('🛒 Cart ${cart['cartId']} has ${cartItems.length} items');
        totalAmount += (cart['totalPrice'] ?? 0.0).toDouble();
      }

      for (var cart in groupedCarts) {
        final cartItems = cart['cartItems'] as List<dynamic>? ?? [];
        for (var item in cartItems) {
          final productId = item['productId'] as int?;
          if (productId != null && !_productImages.containsKey(productId)) {
            await _loadProductImage(productId);
          }
        }
      }

      _updateState(() {
        _groupedCarts = groupedCarts;
        _totalAmount = totalAmount;
        _isLoading = false;
      });

      _notifyCartUpdate();

    } catch (e) {
      debugPrint('❌ Error loading grouped carts: $e');
      _updateState(() {
        _groupedCarts = [];
        _isLoading = false;
      });
      if (mounted && !e.toString().contains('endpoint may not exist')) {
        _showErrorSnackBar('Erreur de chargement du panier: $e');
      }
    }
  }

  Future<void> _loadProductImage(int productId) async {
    try {
      final attachments = await _attachmentService.findByProductProductId(productId);

      if (attachments.isNotEmpty) {
        try {
          final firstAttachment = attachments.first as Map<String, dynamic>;
          final attachmentId = firstAttachment['attachmentId'] as int?;

          if (attachmentId != null) {
            final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
            if (attachmentDownload.data.isNotEmpty) {
              _updateState(() {
                _productImages[productId] = attachmentDownload.data;
              });
            } else {
              _productImages[productId] = null;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error downloading attachment: $e');
          _productImages[productId] = null;
        }
      } else {
        _productImages[productId] = null;
      }
    } catch (e) {
      debugPrint('⚠️ Error loading product image for $productId: $e');
      _productImages[productId] = null;
    }
  }

  Future<void> _updateQuantity(int cartItemId, int newQuantity, int cartId) async {
    if (newQuantity <= 0) {
      await _removeItem(cartItemId);
      return;
    }

    try {
      final cartIndex = _groupedCarts.indexWhere((c) => c['cartId'] == cartId);
      if (cartIndex != -1) {
        final cartItems = _groupedCarts[cartIndex]['cartItems'] as List<dynamic>;
        final itemIndex = cartItems.indexWhere((item) => item['cartItemId'] == cartItemId);

        if (itemIndex != -1) {
          final item = cartItems[itemIndex] as Map<String, dynamic>;
          final productId = item['productId'] as int?;

          await _cartItemService.updateCartItem(cartItemId, {
            'productId': productId,
            'quantity': newQuantity,
            'cartId': cartId,
          });

          _isUpdatingInternally = true;
          _updateState(() {
            item['quantity'] = newQuantity;
            _recalculateTotals();
          });

          _notifyCartUpdate();
          _cartNotifier.notifyCartChanged();
          _isUpdatingInternally = false;

          if (mounted) {
            _showSnackBar('Quantité mise à jour', AppColors.primary,
                duration: const Duration(milliseconds: 800));
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating quantity: $e');
      if (mounted) {
        _showErrorSnackBar('Erreur de mise à jour: $e');
      }
    }
  }

  Future<void> _removeItem(int cartItemId) async {
    try {
      await _cartItemService.deleteCartItem(cartItemId);

      _isUpdatingInternally = true;
      _updateState(() {
        for (var cart in _groupedCarts) {
          final cartItems = cart['cartItems'] as List<dynamic>;
          cartItems.removeWhere((item) => item['cartItemId'] == cartItemId);
        }
        _groupedCarts.removeWhere((cart) => (cart['cartItems'] as List).isEmpty);
        _recalculateTotals();
      });

      _notifyCartUpdate();
      _cartNotifier.notifyCartChanged();
      _isUpdatingInternally = false;

      if (mounted) {
        _showSnackBar('Produit retiré du panier', Colors.orange,
            duration: const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('Error removing item: $e');
      if (mounted) {
        _showErrorSnackBar('Erreur de suppression: $e');
      }
    }
  }

  Future<void> _removeAllItemsFromCart(int cartId) async {
    try {
      final cartIndex = _groupedCarts.indexWhere((c) => c['cartId'] == cartId);
      if (cartIndex != -1) {
        final cartItems = _groupedCarts[cartIndex]['cartItems'] as List<dynamic>;
        for (var item in cartItems) {
          await _cartItemService.deleteCartItem(item['cartItemId']);
        }

        _isUpdatingInternally = true;
        _updateState(() {
          _groupedCarts.removeAt(cartIndex);
          _recalculateTotals();
        });

        _notifyCartUpdate();
        _cartNotifier.notifyCartChanged();
        _isUpdatingInternally = false;

        if (mounted) {
          _showSnackBar('Panier vidé', Colors.orange,
              duration: const Duration(seconds: 2));
        }
      }
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      if (mounted) {
        _showErrorSnackBar('Erreur de suppression: $e');
      }
    }
  }

  void _proceedToCheckoutForCompany(Map<String, dynamic> cart) {
    final cartItems = (cart['cartItems'] as List?) ?? [];
    if (cartItems.isEmpty) return;

    final double cartPrice = (cart['totalPrice'] is num)
        ? (cart['totalPrice'] as num).toDouble()
        : 0.0;
    final String companyName = cart['companyName']?.toString() ?? 'Magasin';
    final double deliveryFee = (cart['deliveryFee'] is num)
        ? (cart['deliveryFee'] as num).toDouble()
        : 0.0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerOrderPage(
          cartItems: cartItems.cast<Map<String, dynamic>>(),
          totalAmount: cartPrice,
          userId: currentUserId!,
          companyName: companyName,
          deliveryFee: deliveryFee,
        ),
      ),
    ).then((_) {
      _loadGroupedCarts();
    });
  }

  void _updateState(VoidCallback callback) {
    if (mounted) {
      setState(callback);
    }
  }

  void _setLoading(bool value) {
    _updateState(() {
      _isLoading = value;
    });
  }

  void _showErrorSnackBar(String message) {
    _showSnackBar(message, Colors.red);
  }

  void _showSnackBar(String message, Color backgroundColor,
      {Duration duration = const Duration(seconds: 1)}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.red
                  ? Icons.error_outline
                  : backgroundColor == Colors.orange
                  ? Icons.info_outline
                  : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _onCartChanged() {
    if (!_isUpdatingInternally) {
      _loadGroupedCarts();
    }
  }

  void _recalculateTotals() {
    _totalAmount = 0.0;
    for (var cart in _groupedCarts) {
      double cartTotal = 0.0;
      final cartItems = cart['cartItems'] as List<dynamic>;
      for (var item in cartItems) {
        final quantity = (item['quantity'] ?? 1) as int;
        final priceValue = item['productFinalePrice'];
        final price = (priceValue is int) ? priceValue.toDouble() : (priceValue as double);
        cartTotal += price * quantity;
      }
      cart['totalPrice'] = cartTotal;
      _totalAmount += cartTotal;
    }
  }

  void _notifyCartUpdate() {
    int totalItems = 0;
    for (var cart in _groupedCarts) {
      final items = cart['cartItems'] as List<dynamic>? ?? [];
      for (var item in items) {
        final quantity = item['quantity'] as int? ?? 1;
        totalItems += quantity;
      }
    }
    debugPrint('🔔 Notifying cart update: $totalItems items');
    widget.onCartUpdated?.call(totalItems);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: _buildModernAppBar(),
      body: Skeletonizer(
        enabled: _isLoading,
        child: _groupedCarts.isEmpty && !_isLoading
            ? _buildEmptyCart()
            : Column(
          children: [
            _buildCartHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _groupedCarts.length,
                itemBuilder: (context, index) {
                  final cart = _groupedCarts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildCompanySection(cart),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mon Panier',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          Text(
            '${_groupedCarts.length} vendeur${_groupedCarts.length > 1 ? 's' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        if (_groupedCarts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_sweep_outlined, color: Colors.red[600], size: 22),
              ),
              onPressed: _confirmClearAllCarts,
              tooltip: 'Vider le panier',
            ),
          ),
      ],
    );
  }

  Widget _buildCartHeader() {
    int totalItems = 0;
    for (var cart in _groupedCarts) {
      final items = cart['cartItems'] as List<dynamic>;
      totalItems += items.length;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.08), AppColors.primary.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  '$totalItems article${totalItems > 1 ? 's' : ''} • ${_groupedCarts.length} vendeur${_groupedCarts.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Total: ${_totalAmount.toStringAsFixed(2)} DT',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanySection(Map<String, dynamic> cart) {
    final companyName = cart['companyName'] ?? 'Magasin';
    final cartItems = cart['cartItems'] as List<dynamic>;
    final cartPrice = (cart['totalPrice'] ?? 0.0).toDouble();
    final deliveryFee = (cart['deliveryFee'] is num)
        ? (cart['deliveryFee'] as num).toDouble()
        : 0.0;
    final cartId = cart['cartId'];
    final totalWithDelivery = cartPrice + deliveryFee;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary.withOpacity(0.1), AppColors.primary.withOpacity(0.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.primary.withOpacity(0.2), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.store_outlined, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '${cartItems.length} article${cartItems.length > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
                if (cartItems.isNotEmpty)
                  InkWell(
                    onTap: () => _confirmClearCart(cartId, companyName),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.close, size: 18, color: Colors.red[600]),
                    ),
                  ),
              ],
            ),
          ),
          ...cartItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value as Map<String, dynamic>;
            return Column(
              children: [
                _buildCartItem(item, cartId),
                if (index < cartItems.length - 1)
                  Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
              ],
            );
          }).toList(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[100]!, width: 1)),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              spacing: 12,
              children: [
                _buildPriceRow('Sous-total', '${cartPrice.toStringAsFixed(2)} DT', Colors.grey[600]!),
                _buildPriceRow(
                  'Livraison',
                  deliveryFee > 0 ? '${deliveryFee.toStringAsFixed(2)} DT' : 'Gratuite',
                  deliveryFee > 0 ? Colors.grey[600]! : Colors.green,
                ),
                _buildPriceRow('Service', 'Gratuit', Colors.green),
                Divider(color: Colors.grey[200], height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${totalWithDelivery.toStringAsFixed(2)} DT',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: cartItems.isNotEmpty && !_isLoading
                        ? () => _proceedToCheckoutForCompany(cart)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 10,
                      children: [
                        const Text(
                          'Passer la commande',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item, int cartId) {
    final productId = item['productId'] as int?;
    final productName = item['productName'] ?? 'Produit';
    final quantity = item['quantity'] ?? 1;
    final cartItemId = item['cartItemId'] as int?;
    final productImage = _productImages[productId];
    final priceValue = item['productFinalePrice'] ?? item['productPrice'] ?? 0.0;
    final price = (priceValue is int) ? priceValue.toDouble() : (priceValue as double);
    final originalPriceValue = item['productPrice'] ?? price;
    final originalPrice = (originalPriceValue is int) ? originalPriceValue.toDouble() : (originalPriceValue as double);
    final itemTotal = price * quantity;
    final hasDiscount = price < originalPrice;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          GestureDetector(
            onTap: productId != null && !_isLoading
                ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailPage(productId: productId),
                ),
              ).then((_) {
                _loadGroupedCarts();
              });
            }
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.12), Colors.grey[100]!],
                  ),
                ),
                child: _isLoading
                    ? Container(color: Colors.grey[200])
                    : productImage != null
                    ? Image.memory(productImage, fit: BoxFit.cover)
                    : Icon(Icons.image_not_supported_outlined,
                    color: Colors.grey[400], size: 40),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Text(
                  productName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasDiscount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red[600]!, width: 0.5),
                    ),
                    child: Text(
                      '${originalPrice.toStringAsFixed(2)} DT',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[600],
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${price.toStringAsFixed(2)} DT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    if (hasDiscount)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[600],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PROMO',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Column(
              spacing: 8,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: cartItemId != null && quantity > 1 && !_isLoading
                            ? () => _updateQuantity(cartItemId, quantity - 1, cartId)
                            : null,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          child: Icon(Icons.remove, size: 16,
                              color: quantity > 1 ? AppColors.primary : Colors.grey[400]),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.grey[300],
                      ),
                      Expanded(
                        child: Center(
                          child: Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: Colors.grey[300],
                      ),
                      InkWell(
                        onTap: cartItemId != null && !_isLoading
                            ? () => _updateQuantity(cartItemId, quantity + 1, cartId)
                            : null,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          child: Icon(Icons.add, size: 16, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: cartItemId != null && !_isLoading
                      ? () => _confirmRemoveItem(cartItemId, productName)
                      : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red[600]!, width: 0.5),
                    ),
                    child: Icon(Icons.delete_outline, color: Colors.red[600], size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.primary),
            ),
            Text(
              'Votre panier est vide',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.grey[900]),
            ),
            Text(
              'Explorez nos produits et commencez\nvos achats dès maintenant',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.6, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveItem(int cartItemId, String productName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.delete_outline, color: Colors.red[600], size: 32),
              ),
              const Text(
                'Retirer du panier',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                'Êtes-vous sûr de vouloir retirer\n"$productName" de votre panier ?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 8),
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _removeItem(cartItemId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Retirer',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

  void _confirmClearCart(int cartId, String companyName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.warning_outlined, color: Colors.orange[600], size: 32),
              ),
              const Text(
                'Vider le panier',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                'Voulez-vous retirer tous les articles\nde $companyName de votre panier ?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 8),
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          final success = await _cartService.deleteCart(cartId);
                          if (success) {
                            _isUpdatingInternally = true;
                            _updateState(() {
                              _groupedCarts.removeWhere((c) => c['cartId'] == cartId);
                              _recalculateTotals();
                            });
                            _cartNotifier.notifyCartChanged();
                            _isUpdatingInternally = false;

                            if (mounted) {
                              _showSnackBar('Panier de $companyName vidé avec succès',
                                  Colors.green,
                                  duration: const Duration(seconds: 2));
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            _showErrorSnackBar('Erreur: ${e.toString()}');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Vider',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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

  void _confirmClearAllCarts() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.delete_sweep_outlined, color: Colors.red[600], size: 32),
              ),
              const Text(
                'Vider tout le panier',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                'Êtes-vous sûr de vouloir retirer tous\nles articles de votre panier ?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 8),
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        for (var cart in _groupedCarts) {
                          await _removeAllItemsFromCart(cart['cartId']);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Vider tout',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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