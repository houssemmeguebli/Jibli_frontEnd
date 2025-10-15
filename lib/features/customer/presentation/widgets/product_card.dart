import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class ProductCard extends StatefulWidget {
  final String name;
  final double price;
  final double? finalPrice;
  final String? imageUrl;
  final bool isAvailable;
  final double discount;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    this.finalPrice,
    this.imageUrl,
    this.isAvailable = true,
    this.discount = 0,
    this.onTap,
    this.onAddToCart,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final displayPrice = widget.finalPrice ?? widget.price;
    final hasDiscount = widget.discount > 0;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Container(
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isPressed ? 0.05 : 0.08),
                blurRadius: _isPressed ? 8 : 12,
                offset: Offset(0, _isPressed ? 2 : 4),
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
                    _buildImage(),
                    _buildGradientOverlay(),
                    _buildAvailabilityBadge(),
                    if (widget.isAvailable && hasDiscount) _buildDiscountBadge(),
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
                      _buildProductName(),
                      const SizedBox(height: 10),
                      _buildPriceRow(displayPrice, hasDiscount),
                      const Spacer(),
                      if (widget.onAddToCart != null) _buildAddToCartButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.1),
              Colors.grey[100]!,
            ],
          ),
        ),
        child: widget.imageUrl != null
            ? Image.network(
          widget.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder();
          },
        )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 56,
        color: Colors.grey[300],
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.05),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge() {
    return Positioned(
      top: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: widget.isAvailable
              ? Colors.green.withOpacity(0.95)
              : Colors.red.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: (widget.isAvailable ? Colors.green : Colors.red)
                  .withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              widget.isAvailable ? 'Disponible' : 'Épuisé',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountBadge() {
    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange[600]!,
              Colors.deepOrange[600]!,
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department, size: 13, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              '-${widget.discount.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductName() {
    return Text(
      widget.name,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildPriceRow(double displayPrice, bool hasDiscount) {
    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDiscount) ...[
          Row(
            children: [
              Text(
                '${widget.price.toStringAsFixed(2)} DT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.grey[500],
                  decorationThickness: 2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange[600]!,
                      Colors.deepOrange[600]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '-${widget.discount.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                hasDiscount ? Colors.green.withOpacity(0.15) : AppColors.primary.withOpacity(0.1),
                hasDiscount ? Colors.green.withOpacity(0.08) : AppColors.primary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayPrice.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: hasDiscount ? Colors.green[700] : AppColors.primary,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                'DT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasDiscount ? Colors.green[700] : AppColors.primary,
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }
  Widget _buildAddToCartButton() {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.isAvailable ? widget.onAddToCart : null,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              gradient: widget.isAvailable
                  ? LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.85),
                ],
              )
                  : null,
              color: widget.isAvailable ? null : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
              boxShadow: widget.isAvailable
                  ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
                  : null,
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isAvailable ? Icons.add_shopping_cart : Icons.block,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.isAvailable ? 'Ajouter' : 'Épuisé',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}