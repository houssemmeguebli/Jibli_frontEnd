import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../core/theme/theme.dart';
import '../../../../Core/services/order_item_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/order_service.dart';
import '../../../../Core/services/company_service.dart';
import 'customer_product_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsPage({required this.order, super.key});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final OrderItemService _orderItemService = OrderItemService();
  final AttachmentService _attachmentService = AttachmentService();
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();
  final CompanyService _companyService = CompanyService();

  List<Map<String, dynamic>> _orderItems = [];
  Map<int, List<Uint8List>> _productImages = {};
  Map<int, int> _selectedImageIndex = {};
  Map<String, dynamic>? _companyInfo;
  bool _isLoading = true;
  late String _orderStatus;

  @override
  void initState() {
    super.initState();
    _orderStatus = widget.order['orderStatus'] ?? 'PENDING';
    _loadOrderItems();
    _loadCompanyInfo();
  }


  Future<void> _loadOrderItems() async {
    try {
      final items = await _orderItemService.getOrderItemsByOrder(
        widget.order['orderId'],
      );



      // First, load all product details
      for (var item in items) {
        final productId = item['productId'];
        try {
          final product = await _productService.getProductById(productId);
          if (product != null) {
            item['product'] = product;
            print('Loaded product: ${product['productName']}');
          }
        } catch (e) {
          print('Error loading product $productId: $e');
        }
      }

      setState(() {
        _orderItems = List<Map<String, dynamic>>.from(items);
      });

      // Then load all images for all products
      await _loadProductImagesForAllItems();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading order items: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCompanyInfo() async {
    try {
      final companyId = widget.order['companyId'];
      if (companyId != null) {
        final company = await _companyService.getCompanyById(companyId);
        if (mounted) {
          setState(() {
            _companyInfo = company;
          });
        }
      }
    } catch (e) {
      print('Error loading company info: $e');
    }
  }
  Future<void> _loadProductImagesForAllItems() async {
    try {
      final Map<int, List<Uint8List>> images = {};

      for (var item in _orderItems) {
        final product = item['product'] as Map<String, dynamic>?;
        if (product == null) continue;

        final productId = product['productId'] as int?;
        if (productId == null || _productImages.containsKey(productId)) continue;

        final List<Uint8List> productImages = [];

        try {
          final attachments =
          await _attachmentService.findByProductProductId(productId);

          for (var attach in attachments) {
            try {
              final attachmentId = attach['attachmentId'] as int?;
              if (attachmentId != null) {
                final attachmentDownload =
                await _attachmentService.downloadAttachment(attachmentId);
                if (attachmentDownload.data.isNotEmpty) {
                  productImages.add(attachmentDownload.data);
                }
              }
            } catch (e) {
              debugPrint('⚠️ Error downloading attachment: $e');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching attachments for product $productId: $e');
        }

        if (productImages.isNotEmpty) {
          images[productId] = productImages;
        }
      }

      if (mounted && images.isNotEmpty) {
        setState(() {
          for (var entry in images.entries) {
            _productImages[entry.key] = entry.value;
            _selectedImageIndex[entry.key] = 0;
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading product images: $e');
    }
  }
  String _getStatusColor(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'PENDING') return '#FFA500';
    if (upperStatus == 'IN_PREPARATION') return '#3B82F6';
    if (upperStatus == 'WAITING') return '#3B82F6';
    if (upperStatus == 'ACCEPTED') return '#3B82F6';
    if (upperStatus == 'REJECTED') return '#3B82F6';
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
    if (upperStatus == 'REJECTED') return 'En traitement';
    if (upperStatus == 'PICKED_UP') return 'En Route';
    if (upperStatus == 'DELIVERED') return 'Livré';
    if (upperStatus == 'CANCELED') return 'Annulé';
    return status;
  }

  bool _canCancelOrder() {
    final upperStatus = _orderStatus.toUpperCase();
    return upperStatus == 'PENDING';
  }

  Future<void> _cancelOrder() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Annuler la commande'),
          content: const Text('Êtes-vous sûr de vouloir annuler cette commande?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Non'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performCancelOrder();
              },
              child: const Text('Oui', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performCancelOrder() async {
    try {
      final orderId = widget.order['orderId'];
      await _orderService.patchOrderStatus(orderId, 'CANCELED');

      setState(() {
        _orderStatus = 'CANCELED';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande annulée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error canceling order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'annulation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Détails de la Commande',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildOrderHeader(),
            _buildCustomerInfo(),
            if (_companyInfo != null) _buildCompanyInfo(),
            _buildModernStatusTimeline(),
            _buildOrderItemsList(),
            const SizedBox(height: 12),
            _buildSummary(),
            if (_canCancelOrder()) _buildCancelButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    final orderId = widget.order['orderId'];
    final orderDate = _formatDate(widget.order['createdAt']);

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commande #$orderId',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    orderDate,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(int.parse(_getStatusColor(_orderStatus).replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusLabel(_orderStatus),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations de Livraison',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.person_outlined,
            label: 'Nom',
            value: widget.order['customerName'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: widget.order['customerEmail'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Téléphone',
            value: widget.order['customerPhone'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildAddressRowWithMap(
            address: widget.order['customerAddress'] ?? 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiLine = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: isMultiLine ? 3 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyInfo() {
    if (_companyInfo == null) return const SizedBox.shrink();

    final companyName = _companyInfo!['companyName'] ?? 'Entreprise';
    final companyPhone = _companyInfo!['companyPhone'];
    final companyAddress = _companyInfo!['companyAddress'];
    final companySector = _companyInfo!['companySector'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.store_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Informations du Vendeur',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.business_outlined,
            label: 'Nom de l\'entreprise',
            value: companyName,
          ),
          if (companySector != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.category_outlined,
              label: 'Secteur',
              value: companySector,
            ),
          ],
          if (companyPhone != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.phone_outlined,
              label: 'Téléphone',
              value: companyPhone,
            ),
          ],
          if (companyAddress != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Adresse',
              value: companyAddress,
              isMultiLine: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernStatusTimeline() {
    final upperStatus = _orderStatus.toUpperCase();

    final steps = [
      {
        'label': 'Commande Passée',
        'icon': Icons.shopping_bag_rounded,
        'status': 'PENDING',
        'date': widget.order['createdAt'],
        'completed': true,
        'color': const Color(0xFF6366F1),
      },
      {
        'label': 'En Traitement',
        'icon': Icons.hourglass_bottom_rounded,
        'status': 'IN_PREPARATION',
        'date': widget.order['inPreparationDate'],
        'completed': upperStatus != 'PENDING' && upperStatus != 'CANCELED',
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'En Route',
        'icon': Icons.local_shipping_rounded,
        'status': 'PICKED_UP',
        'date': widget.order['pickedUpDate'],
        'completed': upperStatus == 'PICKED_UP' || upperStatus == 'DELIVERED',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'label': 'Livré',
        'icon': Icons.home_rounded,
        'status': 'DELIVERED',
        'date': widget.order['deliveredDate'],
        'completed': upperStatus == 'DELIVERED',
        'color': const Color(0xFF10B981),
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Suivi de Commande',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Column(
            children: List.generate(steps.length, (index) {
              final step = steps[index];
              final isCompleted = step['completed'] as bool;
              final isLast = index == steps.length - 1;
              final stepColor = step['color'] as Color;
              final isCurrent = index < steps.length - 1 &&
                  steps[index + 1]['completed'] == false &&
                  isCompleted;

              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: isCompleted
                                  ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  stepColor,
                                  stepColor.withOpacity(0.8),
                                ],
                              )
                                  : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.grey[200]!,
                                  Colors.grey[100]!,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: isCompleted
                                  ? [
                                BoxShadow(
                                  color: stepColor.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                                  : [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  step['icon'] as IconData,
                                  color: isCompleted
                                      ? Colors.white
                                      : Colors.grey[400],
                                  size: 36,
                                ),
                                if (isCurrent)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: stepColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.watch_later_rounded,
                                        color: Colors.white,
                                        size: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 4,
                              height: 70,
                              margin: const EdgeInsets.only(top: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    isCompleted
                                        ? stepColor
                                        : Colors.grey[300]!,
                                    steps[index + 1]['completed'] as bool
                                        ? (steps[index + 1]['color'] as Color)
                                        : Colors.grey[300]!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      step['label'] as String,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isCompleted
                                            ? AppColors.textPrimary
                                            : Colors.grey[600],
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  if (isCompleted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: stepColor.withOpacity(0.15),
                                        borderRadius:
                                        BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Complété',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: stepColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? stepColor.withOpacity(0.08)
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCompleted
                                        ? stepColor.withOpacity(0.25)
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 14,
                                      color: isCompleted
                                          ? stepColor
                                          : Colors.grey[500],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatDate(step['date']),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isCompleted
                                            ? stepColor
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isLast) const SizedBox(height: 28),
                ],
              );
            }),
          ),
          if (upperStatus == 'CANCELED')
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.12),
                      Colors.red.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cancel_rounded,
                        color: Colors.red[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Commande Annulée',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Le ${_formatDate(widget.order['canceledDate'])}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.red[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Articles Commandés',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._orderItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == _orderItems.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: _buildOrderItemCard(item),
            );
          }).toList(),
        ],
      ),
    );
  }


  Widget _buildOrderItemCard(Map<String, dynamic> item) {
    print('\n===== BUILDING ORDER ITEM CARD =====');
    print('Full item keys: ${item.keys.toList()}');
    print('Full item: $item');

    final product = item['product'] as Map<String, dynamic>?;
    if (product == null) return const SizedBox.shrink();

    final productId = product['productId'];
    final productName = product['productName'] ?? 'Produit';
    final quantity = item['quantity'] ?? 1;
    final unitPrice = (product['productFinalePrice'] ?? 0).toDouble();

    print('Item fields:');
    print('  - orderItemId: ${item['orderItemId']}');
    print('  - productId: ${item['productId']}');
    print('  - quantity: ${item['quantity']}');
    print('  - unitPrice: ${item['unitPrice']}');
    print('  - selectedToppingIds: ${item['selectedToppingIds']}');
    print('  - selectedExtraIds: ${item['selectedExtraIds']}');
    print('  - selectedToppings: ${item['selectedToppings']}');
    print('  - selectedExtras: ${item['selectedExtras']}');
    print('===== END ITEM DEBUG =====\n');

    final itemTotal = _calculateItemTotalWithExtras(item);

    // Get product toppings and extras for matching
    final List<Map<String, dynamic>>? productToppingsList =
    (product['toppings'] as List?)?.cast<Map<String, dynamic>>();
    final List<Map<String, dynamic>>? productExtrasList =
    (product['extras'] as List?)?.cast<Map<String, dynamic>>();

    // FIXED: Pass product toppings/extras for matching with IDs
    final toppings = _parseToppings(item['selectedToppings']);
    final extras = _parseExtras(item['selectedExtras']);
    final images = _productImages[productId] ?? [];
    final selectedIndex = _selectedImageIndex[productId] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailPage(productId: productId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.1),
                            Colors.grey[100]!,
                          ],
                        ),
                      ),
                      child: images.isNotEmpty
                          ? Image.memory(
                        images[selectedIndex],
                        fit: BoxFit.cover,
                      )
                          : Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.grey[400],
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Prix: ${unitPrice.toStringAsFixed(2)} DT',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Quantité: $quantity',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${itemTotal.toStringAsFixed(2)} DT',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (toppings.isNotEmpty || extras.isNotEmpty) ...[
                const SizedBox(height: 12),
                if (toppings.isNotEmpty) ...[
                  _buildToppingsSection(toppings),
                  if (extras.isNotEmpty) const SizedBox(height: 8),
                ],
                if (extras.isNotEmpty) _buildExtrasSection(extras),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final subtotal = widget.order['totalAmount'] ?? 0.0;
    final deliveryFee = (widget.order['deliveryFee'] ?? 0.0).toDouble();
    final total = (subtotal + deliveryFee).toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            'Sous-total',
            '${subtotal.toStringAsFixed(2)} DT',
            isTotal: false,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Livraison',
            deliveryFee == 0.0 ? 'Gratuite' : '${deliveryFee.toStringAsFixed(2)} DT',
            isTotal: false,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Service',
            'Gratuite',
            isTotal: false,
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Total',
            '${total.toStringAsFixed(2)} DT',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {required bool isTotal}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? AppColors.textPrimary : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isTotal ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _cancelOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Annuler la Commande',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressRowWithMap({required String address}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_on,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adresse de Livraison',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openLocationViewer(address),
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text('Voir dans Google Maps'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLocationViewer(String address) async {
    double? lat;
    double? lng;

    try {
      final latValue = widget.order['latitude'];
      if (latValue != null) {
        if (latValue is double) {
          lat = latValue;
        } else if (latValue is int) {
          lat = latValue.toDouble();
        } else if (latValue is String) {
          lat = double.tryParse(latValue);
        }
      }

      final lngValue = widget.order['longitude'];
      if (lngValue != null) {
        if (lngValue is double) {
          lng = lngValue;
        } else if (lngValue is int) {
          lng = lngValue.toDouble();
        } else if (lngValue is String) {
          lng = double.tryParse(lngValue);
        }
      }

      if (lat == null || lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coordonnées non disponibles pour cette livraison'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      debugPrint('📍 Opening maps with coordinates: lat=$lat, lng=$lng');
    } catch (e) {
      debugPrint('❌ Error parsing coordinates: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la lecture des coordonnées'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _openInGoogleMaps(lat!, lng!, address);
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final urls = [
        'https://www.google.com/maps/?q=$lat,$lng',
        'https://maps.google.com/?q=$lat,$lng',
        'https://www.google.com/maps/search/$encodedAddress/@$lat,$lng,17z',
        'https://maps.apple.com/?q=$lat,$lng',
      ];

      bool opened = false;
      for (String urlString in urls) {
        try {
          final uri = Uri.parse(urlString);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            opened = true;
            break;
          }
        } catch (e) {
          continue;
        }
      }

      if (!opened) {
        try {
          final fallbackUrl = Uri.parse('https://www.google.com/maps/?q=$lat,$lng');
          await launchUrl(fallbackUrl);
          opened = true;
        } catch (e) {
          debugPrint('❌ Fallback failed: $e');
        }
      }

      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir Google Maps'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  List<Map<String, dynamic>> _parseToppings(dynamic toppingsData) {
    print('🔍 _parseToppings called with data type: ${toppingsData.runtimeType}');

    if (toppingsData == null) {
      print('⚠️ Toppings data is null');
      return [];
    }

    // Handle List of topping objects from backend
    if (toppingsData is List) {
      print('📋 Toppings is a List with ${toppingsData.length} items');
      final List<Map<String, dynamic>> result = [];

      for (int i = 0; i < toppingsData.length; i++) {
        var topping = toppingsData[i];
        print('   Item $i type: ${topping.runtimeType}');

        if (topping is Map<String, dynamic>) {
          final toppingId = topping['toppingId'];
          final toppingName = topping['toppingName'];

          if (toppingId != null && toppingName != null) {
            result.add({
              'toppingId': toppingId,
              'toppingName': toppingName.toString(),
            });
            print('   ✅ Added: $toppingName');
          }
        }
      }

      if (result.isNotEmpty) {
        print('✅ Parsed ${result.length} toppings');
        return result;
      }
    }

    print('⚠️ No toppings found');
    return [];
  }
  List<Map<String, dynamic>> _parseExtras(dynamic extrasData) {
    print('🔍 _parseExtras called with data type: ${extrasData.runtimeType}');

    if (extrasData == null) {
      print('⚠️ Extras data is null');
      return [];
    }

    // Handle List of extra objects from backend
    if (extrasData is List) {
      print('📋 Extras is a List with ${extrasData.length} items');
      final List<Map<String, dynamic>> result = [];

      for (int i = 0; i < extrasData.length; i++) {
        var extra = extrasData[i];
        print('   Item $i type: ${extra.runtimeType}');
        print('   Item $i: $extra');

        if (extra is Map<String, dynamic>) {
          final extraId = extra['extraId'];
          final extraName = extra['extraName'];
          var extraPrice = extra['extraPrice'];

          print('   extraPrice raw: $extraPrice (type: ${extraPrice.runtimeType})');

          if (extraId != null && extraName != null && extraPrice != null) {
            double price = 0.0;
            if (extraPrice is double) {
              price = extraPrice;
            } else if (extraPrice is int) {
              price = extraPrice.toDouble();
            } else if (extraPrice is num) {
              price = extraPrice.toDouble();
            } else if (extraPrice is String) {
              price = double.tryParse(extraPrice) ?? 0.0;
            }

            print('   ✅ Converted price: $price');

            result.add({
              'extraId': extraId,
              'extraName': extraName.toString(),
              'extraPrice': price,
            });
            print('   ✅ Added: $extraName ($price DT)');
          }
        }
      }

      if (result.isNotEmpty) {
        print('✅ Parsed ${result.length} extras');
        for (var r in result) {
          print('   Final: ${r['extraName']} = ${r['extraPrice']} DT');
        }
        return result;
      }
    }

    print('⚠️ No extras found');
    return [];
  }

  Widget _buildToppingsSection(List<Map<String, dynamic>> toppings) {
    if (toppings.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue[50] ?? Colors.blue.withOpacity(0.1),
            Colors.blue[25] ?? Colors.blue.withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue[200] ?? Colors.blue.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue[400] ?? Colors.blue,
                        Colors.blue[600] ?? Colors.blue
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Garnitures • ${toppings.length} sélection${toppings.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700] ?? Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Toppings chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: toppings.map<Widget>((topping) {
                final name = topping['toppingName']?.toString() ?? 'Garniture';
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.blue[50] ?? Colors.blue.withOpacity(0.1)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue[300] ?? Colors.blue.withOpacity(0.3),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.blue[500] ?? Colors.blue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700] ?? Colors.blue,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtrasSection(List<Map<String, dynamic>> extras) {
    if (extras.isEmpty) return const SizedBox.shrink();

    double totalExtraPrice = 0.0;
    for (var extra in extras) {
      totalExtraPrice += (extra['extraPrice'] ?? 0.0) as double;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green[50] ?? Colors.green.withOpacity(0.1),
            Colors.green[25] ?? Colors.green.withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green[200] ?? Colors.green.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green[400] ?? Colors.green,
                        Colors.green[600] ?? Colors.green
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_circle,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Suppléments • ${extras.length} addition${extras.length > 1 ? 's' : ''} (+${totalExtraPrice.toStringAsFixed(2)} DT)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700] ?? Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Extras chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: extras.map<Widget>((extra) {
                final name = extra['extraName']?.toString() ?? 'Supplément';
                final price = (extra['extraPrice'] ?? 0.0) as double;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.green[50] ?? Colors.green.withOpacity(0.1)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green[300] ?? Colors.green.withOpacity(0.3),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green[500] ?? Colors.green,
                              Colors.green[600] ?? Colors.green
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '+${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[700] ?? Colors.green,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }


  double _calculateItemTotalWithExtras(Map<String, dynamic> item) {
    final product = item['product'] as Map<String, dynamic>?;
    if (product == null) return 0.0;

    final quantity = item['quantity'] ?? 1;
    final basePrice = (product['productFinalePrice'] ?? 0).toDouble();

    // Get product extras for price calculation
    final List<Map<String, dynamic>>? productExtrasList =
    (product['extras'] as List?)?.cast<Map<String, dynamic>>();

    // FIXED: Use selectedExtraIds and match with product extras
    final extras = _parseExtras(item['selectedExtras']);

    double extraPrice = 0.0;
    for (var extra in extras) {
      extraPrice += (extra['extraPrice'] ?? 0.0) as double;
    }

    return (basePrice + extraPrice) * quantity;
  }
  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime dateTime;

      print('Date type: ${date.runtimeType}, Date value: $date');

      // Handle string format with commas: "2025, 10, 14, 4, 43, 59"
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
        print('Unknown date format: ${date.runtimeType}');
        return 'N/A';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} à ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error parsing date: $date, Error: $e');
      return 'N/A';
    }
  }
}