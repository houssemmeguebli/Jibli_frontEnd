import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/order_service.dart';
import '../../../../core/services/product_service.dart';
import 'package:intl/intl.dart';

class OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const OrderCard({
    super.key,
    required this.order,
  });

  String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) return value.join(', ');
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrent = !['delivered', 'cancelled', 'livré', 'annulé']
        .contains(_safeString(order['orderStatus']).toLowerCase());
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderHeader(),
              const SizedBox(height: 16),
              _buildOrderSummary(),
              const SizedBox(height: 12),
              _buildProductsList(),
              const SizedBox(height: 12),
              _buildOrderInfo(),
              if (order['orderNotes']?.toString().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _buildOrderNotes(),
              ],
              if (isCurrent) ...[
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JB${_safeString(order['orderId']) != '' ? _safeString(order['orderId']) : 'N/A'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(order['orderDate']),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        _buildStatusChip(_safeString(order['orderStatus']) != '' ? _safeString(order['orderStatus']) : 'En cours'),
      ],
    );
  }

  Widget _buildOrderSummary() {
    final totalAmount = double.tryParse(_safeString(order['totalAmount'])) ?? 0.0;
    final totalProducts = int.tryParse(_safeString(order['totalProducts'])) ?? 0;
    final discount = double.tryParse(_safeString(order['discount'])) ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                '$totalProducts produit${totalProducts > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (discount > 0) ...[
                    Text(
                      '${(totalAmount + discount).toStringAsFixed(2)} DT',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    Text(
                      '-${discount.toStringAsFixed(2)} DT',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  Text(
                    '${totalAmount.toStringAsFixed(2)} DT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_safeString(order['quantity']).isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Quantité totale: ${_safeString(order['quantity'])}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderInfo() {
    return Column(
      children: [
        if (_safeString(order['customerAddress']).isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _safeString(order['customerAddress']),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            if (_safeString(order['shippedDate']).isNotEmpty) ...[
              Icon(
                Icons.local_shipping_outlined,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Expédié le ${_formatDate(_safeString(order['shippedDate']))}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              Icon(
                Icons.access_time_rounded,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                'Commandé le ${_formatDate(order['orderDate']?.toString())}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
            const Spacer(),
            if (order['last_updated']?.toString().isNotEmpty == true) ...[
              Text(
                'Mis à jour: ${_formatTime(order['lastUpdated']?.toString())}',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildOrderNotes() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.info.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.note_outlined,
            size: 16,
            color: AppColors.info,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              order['orderNotes']?.toString() ?? '',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.info,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
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
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _getOrderItems(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return Text(
                  'Aucun produit trouvé',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                );
              }
              
              final items = snapshot.data!;
              return Column(
                children: items.take(3).map((item) => _buildProductItem(item)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> item) {
    final productId = int.tryParse(_safeString(item['productId']));
    
    if (productId == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.info.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.image_not_supported, size: 20, color: AppColors.textTertiary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_safeString(item['quantity'])}x Produit',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Détails non disponibles',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: ProductService().getProductById(productId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Chargement...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.error_outline, size: 20, color: AppColors.danger),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_safeString(item['quantity'])}x Produit introuvable',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'ID: $productId',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final product = snapshot.data!;
          final productName = _safeString(product['productName']);
          final productDescription = _safeString(product['productDescription']);
          final productPrice = double.tryParse(_safeString(product['productPrice'])) ?? 0.0;
          final productImage = _safeString(product['attachments']);
          final quantity = int.tryParse(_safeString(item['quantity'])) ?? 1;

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: productImage.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            productImage,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.fastfood,
                              size: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.fastfood,
                          size: 20,
                          color: AppColors.primary,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${quantity}x $productName',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (productDescription.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          productDescription,
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${productPrice.toStringAsFixed(2)} DT',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getOrderItems() async {
    try {
      final orderService = OrderService();
      final orderId = int.tryParse(_safeString(order['orderId']));
      if (orderId != null) {
        return await orderService.getOrderItems(orderId);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.track_changes, size: 16),
            label: const Text('Suivre'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.phone, size: 16),
            label: const Text('Contacter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
      case 'en attente':
        backgroundColor = AppColors.warning.withOpacity(0.15);
        textColor = AppColors.warning;
        icon = Icons.schedule;
        break;
      case 'confirmed':
      case 'confirmé':
        backgroundColor = AppColors.info.withOpacity(0.15);
        textColor = AppColors.info;
        icon = Icons.check_circle_outline;
        break;
      case 'preparing':
      case 'en préparation':
        backgroundColor = AppColors.accent.withOpacity(0.15);
        textColor = AppColors.accent;
        icon = Icons.restaurant;
        break;
      case 'shipped':
      case 'expédié':
      case 'en route':
        backgroundColor = AppColors.info.withOpacity(0.15);
        textColor = AppColors.info;
        icon = Icons.local_shipping;
        break;
      case 'delivered':
      case 'livré':
        backgroundColor = AppColors.success.withOpacity(0.15);
        textColor = AppColors.success;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
      case 'annulé':
        backgroundColor = AppColors.danger.withOpacity(0.15);
        textColor = AppColors.danger;
        icon = Icons.cancel;
        break;
      default:
        backgroundColor = AppColors.textTertiary.withOpacity(0.15);
        textColor = AppColors.textTertiary;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            _translateStatus(status),
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'En attente';
      case 'confirmed':
        return 'Confirmé';
      case 'preparing':
        return 'En préparation';
      case 'shipped':
        return 'Expédié';
      case 'delivered':
        return 'Livré';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(date);
      // Format only the date part in French style
      final formatter = DateFormat('dd/MM/yyyy', 'fr_FR');
      return formatter.format(dateTime);
    } catch (e) {
      return date;
    }
  }

  String _formatTime(String? date) {
    if (date == null || date.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(date);
      // Format only the time part in 24-hour format
      final formatter = DateFormat('HH:mm', 'fr_FR');
      return formatter.format(dateTime);
    } catch (e) {
      return date;
    }
  }

  void _showOrderDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Détails de la commande',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Numéro de commande', 'JB${order['orderId']?.toString() ?? 'N/A'}'),
                      _buildDetailRow('Client', order['customerName']?.toString() ?? 'N/A'),
                      _buildDetailRow('Email', order['customerEmail']?.toString() ?? 'N/A'),
                      _buildDetailRow('Téléphone', order['customerPhone']?.toString() ?? 'N/A'),
                      _buildDetailRow('Adresse', order['customerAddress']?.toString() ?? 'N/A'),
                      _buildDetailRow('Date de commande', _formatDate(order['orderDate']?.toString())),
                      _buildDetailRow('Statut', _translateStatus(order['orderStatus']?.toString() ?? 'N/A')),
                      _buildDetailRow('Montant total', '${(double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)} TND'),
                      _buildDetailRow('Nombre de produits', '${order['totalProducts']?.toString() ?? '0'}'),
                      if ((double.tryParse(order['discount']?.toString() ?? '0') ?? 0.0) > 0)
                        _buildDetailRow('Remise', '${(double.tryParse(order['discount']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)} DT'),
                      if (order['shippedDate']?.toString().isNotEmpty == true)
                        _buildDetailRow('Date d\'expédition', _formatDate(order['shippedDate']?.toString())),
                      if (order['orderNotes']?.toString().isNotEmpty == true)
                        _buildDetailRow('Notes', order['orderNotes']?.toString() ?? ''),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}