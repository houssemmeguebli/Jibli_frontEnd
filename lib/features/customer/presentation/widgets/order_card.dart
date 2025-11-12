import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/order_item_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../../../../core/services/product_service.dart';
import '../pages/customer_order_details_page.dart';

class OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<int, Uint8List?>? productImages;

  const OrderCard({
    super.key,
    required this.order,
    this.productImages,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  final OrderItemService _orderItemService = OrderItemService();
  final AttachmentService _attachmentService = AttachmentService();
  final ProductService _productService = ProductService();

  List<Map<String, dynamic>> _orderItems = [];
  Map<int, Uint8List?> _productImages = {};
  bool _isLoadingItems = true;

  @override
  void initState() {
    super.initState();
    // Initialize with passed images or load them
    if (widget.productImages != null) {
      _productImages = Map.from(widget.productImages!);
    }
    _loadOrderItems();
  }

  Future<void> _loadOrderItems() async {
    try {
      final orderId = int.tryParse(_safeString(widget.order['orderId']));
      if (orderId == null) {
        setState(() => _isLoadingItems = false);
        return;
      }

      final items = await _orderItemService.getOrderItemsByOrder(orderId);

      // Load images only for products not already loaded
      for (var item in items) {
        final productId = item['productId'] as int?;
        if (productId != null && !_productImages.containsKey(productId)) {
          try {
            final attachments = await _attachmentService.findByProductProductId(productId);
            if (attachments.isNotEmpty) {
              try {
                final firstAttachment = attachments.first as Map<String, dynamic>;
                final attachmentId = firstAttachment['attachmentId'] as int?;
                if (attachmentId != null) {
                  final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
                  if (attachmentDownload.data.isNotEmpty) {
                    _productImages[productId] = attachmentDownload.data;
                  }
                }
              } catch (e) {
                debugPrint('⚠️ Error downloading attachment for product $productId: $e');
                _productImages[productId] = null;
              }
            } else {
              _productImages[productId] = null;
            }
          } catch (e) {
            debugPrint('⚠️ Error loading images for product $productId: $e');
            _productImages[productId] = null;
          }
        }
      }

      if (mounted) {
        setState(() {
          _orderItems = items;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading order items: $e');
      if (mounted) {
        setState(() => _isLoadingItems = false);
      }
    }
  }

  String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) return value.join(', ');
    return value.toString();
  }

  Color _getStatusColor(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'PENDING') return const Color(0xFFFFA500);
    if (upperStatus == 'IN_PREPARATION') return const Color(0xFF3B82F6);
    if (upperStatus == 'WAITING') return const Color(0xFF3B82F6);
    if (upperStatus == 'ACCEPTED') return const Color(0xFF3B82F6);
    if (upperStatus == 'REJECTED') return const Color(0xFF3B82F6);
    if (upperStatus == 'PICKED_UP') return const Color(0xFF8B5CF6);
    if (upperStatus == 'DELIVERED') return const Color(0xFF10B981);
    if (upperStatus == 'CANCELED') return const Color(0xFFEF4444);
    return const Color(0xFF6B7280);
  }

  String _getStatusLabel(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'PENDING') return 'En attente';
    if (upperStatus == 'IN_PREPARATION') return 'En traitement';
    if (upperStatus == 'WAITING') return 'En traitement';
    if (upperStatus == 'ACCEPTED') return 'En traitement';
    if (upperStatus == 'REJECTED') return 'En traitement';
    if (upperStatus == 'PICKED_UP') return 'En Route';
    if (upperStatus == 'DELIVERED') return 'Livré';
    if (upperStatus == 'CANCELED') return 'Annulé';
    return status;
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime dateTime;

      if (date is String) {
        final parts = date.replaceAll(' ', '').split(',');
        if (parts.length >= 3) {
          int year = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int day = int.parse(parts[2]);
          int hour = parts.length > 3 ? int.parse(parts[3]) : 0;
          int minute = parts.length > 4 ? int.parse(parts[4]) : 0;
          int second = parts.length > 5 ? int.parse(parts[5]) : 0;

          dateTime = DateTime(year, month, day, hour, minute, second);
        } else {
          return 'N/A';
        }
      } else if (date is List) {
        if (date.isEmpty) return 'N/A';

        int year = int.parse(date[0].toString());
        int month = int.parse(date[1].toString());
        int day = int.parse(date[2].toString());
        int hour = date.length > 3 ? int.parse(date[3].toString()) : 0;
        int minute = date.length > 4 ? int.parse(date[4].toString()) : 0;
        int second = date.length > 5 ? int.parse(date[5].toString()) : 0;

        dateTime = DateTime(year, month, day, hour, minute, second);
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return 'N/A';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} à ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _navigateToOrderDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsPage(order: widget.order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrent = !['delivered', 'cancelled', 'livré', 'annulé']
        .contains(_safeString(widget.order['orderStatus']).toLowerCase());

    return GestureDetector(
      onTap: () => _navigateToOrderDetails(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderHeader(),
                  const SizedBox(height: 16),
                  _buildOrderSummary(),
                  const SizedBox(height: 14),
                  _buildProductsPreview(),
                  if (isCurrent) ...[
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    final orderId = _safeString(widget.order['orderId']);
    final orderStatus = _safeString(widget.order['orderStatus']);
    final orderDate = _formatDate(widget.order['createdAt']);
    final statusColor = _getStatusColor(orderStatus);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commande #$orderId',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                orderDate,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor.withOpacity(0.2),
                statusColor.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.15),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            _getStatusLabel(orderStatus),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: statusColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    final totalAmount = double.tryParse(_safeString(widget.order['totalAmount'])) ?? 0.0;
    final deliveryFee = double.tryParse(_safeString(widget.order['deliveryFee'])) ?? 0.0;
    final totalProducts = int.tryParse(_safeString(widget.order['totalProducts'])) ?? 0;
    final quantity = int.tryParse(_safeString(widget.order['quantity'])) ?? 0;
    final discount = double.tryParse(_safeString(widget.order['discount'])) ?? 0.0;

    // ✅ Calculate subtotal (totalAmount - deliveryFee)
    final subtotal = totalAmount - deliveryFee;
    // ✅ Final total is already totalAmount (includes delivery fee)
    final finalTotal = totalAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$totalProducts produit${totalProducts > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  if (quantity > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Quantité: $quantity',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (discount > 0) ...[
                    Text(
                      '${(subtotal + discount).toStringAsFixed(2)} DT',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        decoration: TextDecoration.lineThrough,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    '${finalTotal.toStringAsFixed(2)} DT',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.primary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // ✅ ADD: Display delivery fee breakdown
          if (deliveryFee > 0) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.grey[300], height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Livraison',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '+ ${deliveryFee.toStringAsFixed(2)} DT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildProductsPreview() {
    if (_isLoadingItems) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const SizedBox(
          height: 40,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_orderItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Text(
          'Aucun produit',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      );
    }

    final itemsToShow = _orderItems.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_outlined,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Produits commandés',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...itemsToShow.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < itemsToShow.length - 1 ? 10 : 0),
            child: _buildProductItemPreview(item),
          );
        }).toList(),
        if (_orderItems.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+${_orderItems.length - 3} produit${_orderItems.length - 3 > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductItemPreview(Map<String, dynamic> item) {
    final quantity = int.tryParse(_safeString(item['quantity'])) ?? 1;
    final productId = int.tryParse(_safeString(item['productId']));
    final image = productId != null ? _productImages[productId] : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    Colors.grey[100]!,
                  ],
                ),
              ),
              child: image != null && image.isNotEmpty
                  ? Image.memory(
                image,
                fit: BoxFit.cover,
              )
                  : Icon(
                Icons.image_outlined,
                color: Colors.grey[400],
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _productService.getProductById(productId ?? 0),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text(
                    '$quantity x Produit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  );
                }

                final product = snapshot.data;
                final productName = _safeString(product?['productName'] ?? 'Produit');

                return Text(
                  '$quantity x $productName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: () => _navigateToOrderDetails(context),
        icon: const Icon(Icons.visibility_outlined, size: 18),
        label: const Text('Voir les détails'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.primary, width: 1.5),
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}