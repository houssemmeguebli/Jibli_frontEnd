import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../core/theme/theme.dart';
import '../pages/customer_product_detail_page.dart';
import 'dart:ui';
class ProductListItem extends StatefulWidget {
  final Map<String, dynamic> product;
  final int? productId;
  final Uint8List? productImage;
  final VoidCallback onAddToCart;

  const ProductListItem({
    super.key,
    required this.product,
    required this.productId,
    this.productImage,
    required this.onAddToCart,
  });

  @override
  State<ProductListItem> createState() => _ProductListItemState();
}

class _ProductListItemState extends State<ProductListItem> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productName = widget.product['productName']?.toString() ?? 'Produit';
    final productPrice = (widget.product['productPrice'] ?? 0).toDouble();
    final discountPercentage = (widget.product['discountPercentage'] ?? 0).toDouble();
    final finalPrice = (widget.product['productFinalePrice'] ?? productPrice).toDouble();
    final isAvailable = widget.product['available'] == true || widget.product['available'] == 1;
    final savedAmount = productPrice - finalPrice;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: GestureDetector(
          onTap: () {
            if (widget.productId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailPage(productId: widget.productId!),
                ),
              );
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Main Content
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        // Product Image
                        _buildProductImage(),
                        const SizedBox(width: 14),
                        // Product Details
                        Expanded(
                          child: _buildProductDetails(
                            productName,
                            productPrice,
                            finalPrice,
                            discountPercentage,
                            isAvailable,
                            savedAmount,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Action Buttons
                        _buildActionButtons(isAvailable),
                      ],
                    ),
                  ),
                  // Discount Badge
                  if (discountPercentage > 0) _buildDiscountBadge(discountPercentage),
                  // Availability Overlay
                  if (!isAvailable) _buildUnavailableOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.productImage != null
          ? ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.memory(
          widget.productImage!,
          fit: BoxFit.cover,
        ),
      )
          : Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[100]!, Colors.grey[50]!],
          ),
        ),
        child: Icon(
          Icons.shopping_bag_outlined,
          color: Colors.grey[400],
          size: 44,
        ),
      ),
    );
  }

  Widget _buildProductDetails(
      String name,
      double originalPrice,
      double finalPrice,
      double discountPercentage,
      bool isAvailable,
      double savedAmount,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Product Name
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        // Price Section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${finalPrice.toStringAsFixed(2)} DT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isAvailable ? AppColors.primary : Colors.grey[500],
                    letterSpacing: -0.5,
                  ),
                ),
                if (discountPercentage > 0) ...[
                  const SizedBox(width: 2),
                  Text(
                    '${originalPrice.toStringAsFixed(2)} DT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.grey[400],
                      decorationThickness: 2,
                    ),
                  ),
                ],
              ],
            ),
            if (discountPercentage > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[50]!, Colors.green[100]!],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.savings_rounded,
                      size: 12,
                      color: Colors.green[700],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Économisez ${savedAmount.toStringAsFixed(2)} DT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.green[700],
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isAvailable) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 10),
        // Add to Cart Button
        _buildActionButton(
          icon: Icons.add_shopping_cart_rounded,
          backgroundColor: AppColors.primary,
          iconColor: Colors.white,
          isGradient: true,
          onTap: isAvailable ? widget.onAddToCart : null,
          tooltip: 'Ajouter',
          isEnabled: isAvailable,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    VoidCallback? onTap,
    required String tooltip,
    bool isGradient = false,
    bool isEnabled = true,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            gradient: isEnabled && isGradient
                ? LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: isEnabled ? (isGradient ? null : backgroundColor) : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
            boxShadow: isEnabled
                ? (isGradient
                ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ])
                : [],
          ),
          child: Icon(
            icon,
            color: isEnabled ? iconColor : Colors.grey[500],
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildDiscountBadge(double discountPercentage) {
    return Positioned(
      top: 10,
      right: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red[500]!, Colors.deepOrange[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_offer_rounded,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              '-${discountPercentage.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailableOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(18),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Rupture de stock',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}