import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/order_service.dart';
import '../../../../core/services/order_item_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../../../../core/services/product_service.dart';
import 'package:intl/intl.dart';
import '../pages/customer_order_details_page.dart';

class OrderCard extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderCard({
    super.key,
    required this.order,
  });

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  final OrderService _orderService = OrderService();
  final OrderItemService _orderItemService = OrderItemService();
  final AttachmentService _attachmentService = AttachmentService();
  final ProductService _productService = ProductService();

  List<Map<String, dynamic>> _orderItems = [];
  Map<int, Uint8List> _productImages = {};
  bool _isLoadingItems = true;

  @override
  void initState() {
    super.initState();
    _loadOrderItemsAndImages();
  }

  Future<void> _loadOrderItemsAndImages() async {
    try {
      final orderId = int.tryParse(_safeString(widget.order['orderId']));
      if (orderId == null) {
        setState(() => _isLoadingItems = false);
        return;
      }

      final items = await _orderItemService.getOrderItemsByOrder(orderId);
      final Map<int, Uint8List> images = {};

      for (var item in items) {
        final productId = item['productId'] as int?;
        if (productId != null) {
          try {
            final product = await _productService.getProductById(productId);
            if (product != null) {
              final attachments = product['attachments'] as List<dynamic>? ?? [];
              if (attachments.isNotEmpty) {
                try {
                  final attachmentDownload = await _attachmentService.downloadAttachment(
                    attachments[0]['attachmentId'],
                  );
                  images[productId] = attachmentDownload.data;
                } catch (e) {
                  print('Error downloading attachment for product $productId: $e');
                }
              }
            }
          } catch (e) {
            print('Error loading product $productId: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _orderItems = items;
          _productImages = images;
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      print('Error loading order items: $e');
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

  String _getStatusColor(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'PENDING') return '#FFA500';
    if (upperStatus == 'IN_PREPARATION') return '#3B82F6';
    if (upperStatus == 'WAITING') return '#3B82F6';
    if (upperStatus == 'ACCEPTED') return '#3B82F6';
    if (upperStatus == 'PICKED_UP') return '#8B5CF6';
    if (upperStatus == 'DELIVERED') return '#10B981';
    if (upperStatus == 'CANCELED') return '#EF4444';
    return '#6B7280';
  }

  String _getStatusLabel(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'PENDING') return 'En attente';
    if (upperStatus == 'IN_PREPARATION') return 'En traitement';
    if (upperStatus == 'WAITING') return 'En traitement';
    if (upperStatus == 'ACCEPTED') return 'En traitement';
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
        // Remove spaces and split by comma
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
      }
      // Handle list format from LocalDateTime [year, month, day, hour, minute, second]
      else if (date is List) {
        if (date.isEmpty) return 'N/A';

        int year = int.parse(date[0].toString());
        int month = int.parse(date[1].toString());
        int day = int.parse(date[2].toString());
        int hour = date.length > 3 ? int.parse(date[3].toString()) : 0;
        int minute = date.length > 4 ? int.parse(date[4].toString()) : 0;
        int second = date.length > 5 ? int.parse(date[5].toString()) : 0;

        dateTime = DateTime(year, month, day, hour, minute, second);
      }
      // Handle DateTime object
      else if (date is DateTime) {
        dateTime = date;
      }
      else {
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrderHeader(),
                  const SizedBox(height: 16),
                  _buildOrderSummary(),
                  const SizedBox(height: 12),
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
    final orderDate = _formatDate(widget.order['orderDate']);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commande #$orderId',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                orderDate,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Color(int.parse(_getStatusColor(orderStatus).replaceFirst('#', '0xFF'))).withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Color(int.parse(_getStatusColor(orderStatus).replaceFirst('#', '0xFF'))).withOpacity(0.3),
            ),
          ),
          child: Text(
            _getStatusLabel(orderStatus),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(int.parse(_getStatusColor(orderStatus).replaceFirst('#', '0xFF'))),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary() {
    final totalAmount = double.tryParse(_safeString(widget.order['totalAmount'])) ?? 0.0;
    final totalProducts = int.tryParse(_safeString(widget.order['totalProducts'])) ?? 0;
    final quantity = int.tryParse(_safeString(widget.order['quantity'])) ?? 0;
    final discount = double.tryParse(_safeString(widget.order['discount'])) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$totalProducts produit${totalProducts > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              if (quantity > 0) ...[
                const SizedBox(height: 4),
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
                        fontSize: 11,
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
                  '${(totalAmount + discount).toStringAsFixed(2)} DT',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                '${totalAmount.toStringAsFixed(2)} DT',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsPreview() {
    if (_isLoadingItems) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Aucun produit',
          style: TextStyle(
            fontSize: 12,
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
            Icon(
              Icons.restaurant_menu,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Produits commandés',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '+${_orderItems.length - 3} produit${_orderItems.length - 3 > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  );
                }

                final product = snapshot.data;
                final productName = _safeString(product?['productName'] ?? 'Produit');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$quantity x $productName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _navigateToOrderDetails(context),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('Voir détails'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}