import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../Core/services/company_service.dart';
import '../../../../Core/services/user_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../Core/services/order_item_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/order_service.dart';
import 'package:url_launcher/url_launcher.dart';

class OwnerOrderDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback? onOrderUpdated;

  const OwnerOrderDetailsDialog({
    required this.order,
    this.onOrderUpdated,
    super.key,
  });

  @override
  State<OwnerOrderDetailsDialog> createState() =>
      _OwnerOrderDetailsDialogState();
}

class _OwnerOrderDetailsDialogState extends State<OwnerOrderDetailsDialog>
    with SingleTickerProviderStateMixin {
  final OrderItemService _orderItemService = OrderItemService();
  final AttachmentService _attachmentService = AttachmentService();
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();
  final UserService _userService = UserService();
  final CompanyService _companyService = CompanyService();

  List<Map<String, dynamic>> _orderItems = [];
  Map<int, List<Uint8List>> _productImages = {};
  bool _isLoading = true;
  late String _orderStatus;
  late AnimationController _slideController;
  Map<String, dynamic>? _deliveryData;
  Map<String, dynamic>? _companyInfo;
  bool _isLoadingCompany = true;

  @override
  void initState() {
    _loadDeliveryInfo();
    _loadCompanyInfo();
    super.initState();
    _orderStatus = widget.order['orderStatus'] ?? 'PENDING';
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController.forward();
    _loadOrderItems();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }
  Future<void> _loadDeliveryInfo() async {
    try {
      final deliveryId = widget.order['deliveryId'];
      if (deliveryId != null) {
        final data = await _userService.getUserById(deliveryId);
        if (mounted) {
          setState(() {
            _deliveryData = data;
          });
        }
      }
    } catch (e) {
      print('Error loading delivery info: $e');
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
            _isLoadingCompany = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingCompany = false);
        }
      }
    } catch (e) {
      print('Error loading company info: $e');
      if (mounted) {
        setState(() => _isLoadingCompany = false);
      }
    }
  }

  Future<void> _loadOrderItems() async {
    try {
      final items = widget.order['orderItems'] as List<dynamic>? ?? [];
      
      setState(() {
        _orderItems = List<Map<String, dynamic>>.from(items);
        _isLoading = false;
      });

      // Load images after order items are set
      await _loadProductImages();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProductImages() async {
    try {
      final Map<int, List<Uint8List>> images = {};

      for (var item in _orderItems) {
        final product = item['productDetails'] as Map<String, dynamic>?;
        if (product == null) continue;

        final productId = product['productId'] as int?;
        if (productId == null) continue;

        try {
          final attachments = await _attachmentService.findByProductProductId(productId);
          final List<Uint8List> productImages = [];

          for (var attachment in attachments) {
            try {
              final attachmentId = int.parse(attachment['attachmentId'].toString());
              final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
              if (attachmentDownload.data.isNotEmpty) {
                productImages.add(attachmentDownload.data);
              }
            } catch (e) {
              debugPrint('⚠️ Error loading image for attachment: $e');
              continue;
            }
          }

          if (productImages.isNotEmpty) {
            images[productId] = productImages;
          }
        } catch (e) {
          debugPrint('⚠️ Error loading images for product $productId: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _productImages = images;
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
    if (upperStatus == 'WAITING') return '#8B5CF6';
    if (upperStatus == 'ACCEPTED') return '#10B981';
    if (upperStatus == 'PICKED_UP') return '#F59E0B';
    if (upperStatus == 'DELIVERED') return '#10B981';
    if (upperStatus == 'REJECTED') return '#F97316';
    if (upperStatus == 'CANCELED') return '#EF4444';
    return '#6B7280';
  }

  String _getStatusLabel(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'PENDING') return 'En attente';
    if (upperStatus == 'IN_PREPARATION') return 'En préparation';
    if (upperStatus == 'WAITING') return 'Assigné';
    if (upperStatus == 'ACCEPTED') return 'Accepté';
    if (upperStatus == 'PICKED_UP') return 'En route';
    if (upperStatus == 'DELIVERED') return 'Livré';
    if (upperStatus == 'REJECTED') return 'Refusé';
    if (upperStatus == 'CANCELED') return 'Annulé';
    return status;
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      final orderId = widget.order['orderId'];
      await _orderService.patchOrderStatus(orderId, newStatus);

      setState(() {
        _orderStatus = newStatus;
      });

      widget.onOrderUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut mis à jour: ${_getStatusLabel(newStatus)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignDelivery() async {
    try {
      final deliveryUsers = await _userService.getUsersByUserRole('Delivery');

      if (deliveryUsers.isEmpty) {
        _showSnackBar('Aucun livreur disponible', isError: true);
        return;
      }

      final availableDeliverers = deliveryUsers
          .where((user) => user['available'] == true)
          .toList();

      if (availableDeliverers.isEmpty) {
        _showSnackBar('Aucun livreur disponible pour le moment', isError: true);
        return;
      }

      availableDeliverers.sort((a, b) {
        double aRating = (a['rating'] ?? 0).toDouble();
        double bRating = (b['rating'] ?? 0).toDouble();
        return bRating.compareTo(aRating);
      });

      final selectedDelivery = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _buildDeliverySelectionDialog(availableDeliverers),
      );

      if (selectedDelivery != null) {
        final orderId = widget.order['orderId'];
        await _orderService.patchOrderStatus(orderId, 'WAITING');
        
        setState(() {
          _orderStatus = 'WAITING';
        });
        
        widget.onOrderUpdated?.call();

        if (mounted) {
          _showSnackBar(
            '✓ Livreur "${selectedDelivery['fullName']}" assigné avec succès',
          );
        }
      }
    } catch (e) {
      _showSnackBar('Erreur: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxWidth = isMobile ? double.infinity : 700.0;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic)),
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: isMobile ? 12 : 32,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 50,
                offset: const Offset(0, 25),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(isMobile),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: _isLoading
                      ? const Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  )
                      : Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 28,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOrderHeader(),
                        const SizedBox(height: 20),
                        _buildCustomerInfo(),
                        const SizedBox(height: 20),
                        _buildCompanyInfo(),
                        const SizedBox(height: 20),
                        _buildDeliveryInfo(),
                        const SizedBox(height: 20),
                        _buildModernStatusTimeline(),
                        const SizedBox(height: 20),
                        _buildStatusActions(),
                        const SizedBox(height: 20),
                        _buildOrderItemsList(),
                        const SizedBox(height: 20),
                        _buildSummary(),
                      ],
                    ),
                  ),
                ),
              ),
              _buildFooterButtons(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.receipt_outlined,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Détails Commande',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Commande #${widget.order['orderId']}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButtons(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: EdgeInsets.symmetric(vertical: isMobile ? 13 : 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Fermer',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: isMobile ? 14 : 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    final orderId = widget.order['orderId'];
    final orderDate = _formatDate(widget.order['orderDate']);
    final revenue = widget.order['ownerRevenue'] ?? 0.0;

    return Container(
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
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(int.parse(_getStatusColor(_orderStatus)
                      .replaceFirst('#', '0xFF'))),
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Revenus',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${revenue.toStringAsFixed(2)} DT',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Container(
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Informations Client',
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

  Widget _buildCompanyInfo() {
    if (_isLoadingCompany) {
      return Container(
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
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.business_outlined,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Informations Entreprise',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_companyInfo != null) ...[
            _buildInfoRow(
              icon: Icons.business_outlined,
              label: 'Nom de l\'entreprise',
              value: _companyInfo!['companyName'] ?? 'N/A',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _companyInfo!['companyEmail'] ?? 'N/A',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.phone_outlined,
              label: 'Téléphone',
              value: _companyInfo!['companyPhone'] ?? 'N/A',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Adresse',
              value: _companyInfo!['companyAddress'] ?? 'N/A',
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Informations de l\'entreprise non disponibles',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
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

  Widget _buildDeliveryInfo() {
    final deliveryName = _deliveryData?['fullName'] ?? 'Non assigné';
    final deliveryPhone = _deliveryData?['phone'] ?? 'N/A';
    final deliveryEmail = _deliveryData?['email'] ?? 'N/A';
    final isDeliveryAssigned = _deliveryData != null && deliveryName != 'Non assigné';

    return Container(
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Informations Livraison',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isDeliveryAssigned) ...[
            _buildInfoRow(
              icon: Icons.person_outlined,
              label: 'Livreur',
              value: deliveryName,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.phone_outlined,
              label: 'Téléphone',
              value: deliveryPhone,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: deliveryEmail,
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aucun livreur n\'a été assigné à cette commande',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
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



  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
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
            size: 16,
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusActions() {
    final upperStatus = _orderStatus.toUpperCase();

    return Container(
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Actions de Commande',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (upperStatus == 'PENDING')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus('IN_PREPARATION'),
                    icon: const Icon(Icons.restaurant, size: 18),
                    label: const Text('Commencer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus('CANCELED'),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Refuser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
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
          if (upperStatus == 'IN_PREPARATION')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _assignDelivery,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Assigner un livreur'),
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
          if (upperStatus == 'WAITING')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.purple),
                  SizedBox(width: 8),
                  Text(
                    'En attente de la réponse du livreur',
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (upperStatus == 'REJECTED')
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cancel_outlined, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Livraison refusée par le livreur',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _assignDelivery,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Assigner un autre livreur'),
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
          if (upperStatus == 'PICKED_UP')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.delivery_dining, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Commande en cours de livraison',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (upperStatus == 'DELIVERED')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Commande livrée avec succès',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (upperStatus == 'CANCELED')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Commande annulée',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Vos Produits',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
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
    );
  }

  Widget _buildOrderItemCard(Map<String, dynamic> item) {
    final product = item['productDetails'] as Map<String, dynamic>?;
    if (product == null) return const SizedBox.shrink();

    final productId = product['productId'];
    final productName = product['productName'] ?? 'Produit';
    final quantity = item['quantity'] ?? 1;
    final unitPrice = (product['productFinalePrice'] ?? 0).toDouble();
    final itemTotal = _calculateItemTotalWithExtras(item);
    final toppings = _parseToppings(item['selectedToppings']);
    final extras = _parseExtras(item['selectedExtras']);

    final images = _productImages[productId] ?? [];

    return Container(
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
                    child: images.isNotEmpty && images[0].isNotEmpty
                        ? Image.memory(
                      images[0],
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
    );
  }

  Widget _buildSummary() {
    final revenue = widget.order['totalAmount'] ?? 0.0;
    final itemCount = widget.order['ownerItemCount'] ?? 0;
    final deliveryFee = widget.order['deliveryFee'] ?? 0.0;
    final finalRevenue = revenue + deliveryFee;

    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.monetization_on_outlined,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Résumé des Revenus',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            'Articles vendus',
            '$itemCount',
            isTotal: false,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Prix des articles',
            '${revenue.toStringAsFixed(2)} DT',
            isTotal: false,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Frais de livraison',
            '${deliveryFee.toStringAsFixed(2)} DT',
            isTotal: false,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Frais de service',
            '${0.00} DT',
            isTotal: false,
          ),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Total des revenus',
            '${finalRevenue.toStringAsFixed(2)} DT',
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
            color: isTotal ? Colors.green : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatusTimeline() {
    final upperStatus = _orderStatus.toUpperCase();

    final steps = [
      {
        'label': 'Commande Reçue',
        'icon': Icons.shopping_bag_rounded,
        'status': 'PENDING',
        'date': widget.order['orderDate'],
        'completed': true,
        'color': const Color(0xFF6366F1),
      },
      {
        'label': 'En Préparation',
        'icon': Icons.hourglass_bottom_rounded,
        'status': 'IN_PREPARATION',
        'date': widget.order['inPreparationDate'],
        'completed': upperStatus == 'IN_PREPARATION' ||
            upperStatus == 'WAITING' ||
            upperStatus == 'ACCEPTED' ||
            upperStatus == 'PICKED_UP' ||
            upperStatus == 'DELIVERED',
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Affecté au livreur',
        'icon': Icons.person_rounded,
        'status': 'WAITING',
        'date': widget.order['waitingDate'],
        'completed': upperStatus == 'WAITING' ||
            upperStatus == 'ACCEPTED' ||
            upperStatus == 'PICKED_UP' ||
            upperStatus == 'DELIVERED' ||
            upperStatus == 'REJECTED',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'label': 'Accepté par le livreur',
        'icon': Icons.check_circle_rounded,
        'status': 'ACCEPTED',
        'date': widget.order['acceptedDate'],
        'completed': upperStatus == 'ACCEPTED' ||
            upperStatus == 'PICKED_UP' ||
            upperStatus == 'DELIVERED',
        'color': const Color(0xFF10B981),
      },
      {
        'label': 'En Livraison',
        'icon': Icons.local_shipping_rounded,
        'status': 'PICKED_UP',
        'date': widget.order['pickedUpDate'],
        'completed': upperStatus == 'PICKED_UP' || upperStatus == 'DELIVERED',
        'color': const Color(0xFF3B82F6),
      },
      {
        'label': 'Livré',
        'icon': Icons.check_circle_rounded,
        'status': 'DELIVERED',
        'date': widget.order['deliveredDate'],
        'completed': upperStatus == 'DELIVERED',
        'color': const Color(0xFF10B981),
      },
    ];

    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
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
                    Icons.timeline_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Suivi de Commande',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
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
                              width: 60,
                              height: 60,
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
                                    color: stepColor.withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ]
                                    : [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
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
                                    size: 28,
                                  ),
                                  if (isCurrent)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: stepColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.access_time_rounded,
                                          color: Colors.white,
                                          size: 8,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 3,
                                height: 50,
                                margin: const EdgeInsets.only(top: 8),
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
                        const SizedBox(width: 20),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        step['label'] as String,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isCompleted
                                              ? AppColors.textPrimary
                                              : Colors.grey[600],
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    if (isCompleted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: stepColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Terminé',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: stepColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? stepColor.withOpacity(0.08)
                                        : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isCompleted
                                          ? stepColor.withOpacity(0.2)
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: isCompleted
                                            ? stepColor
                                            : Colors.grey[500],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatDate(step['date']),
                                        style: TextStyle(
                                          fontSize: 11,
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
                    if (!isLast) const SizedBox(height: 20),
                  ],
                );
              }),
            ),
            if (upperStatus == 'REJECTED')
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.1),
                        Colors.orange.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cancel_outlined,
                          color: Colors.orange[600],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Livraison Refusée',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange[700],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Le livreur a refusé cette commande',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (upperStatus == 'CANCELED')
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.1),
                        Colors.red.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cancel_rounded,
                          color: Colors.red[600],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commande Annulée',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.red[700],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Le ${_formatDate(widget.order['canceledDate'])}',
                              style: TextStyle(
                                fontSize: 11,
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

        ));
  }
  Widget _buildDeliverySelectionDialog(List<Map<String, dynamic>> deliveryUsers) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1024;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : (isTablet ? 40 : 80),
        vertical: isMobile ? 20 : 40,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? double.infinity : (isTablet ? 600 : 700),
          maxHeight: screenSize.height * (isMobile ? 0.9 : 0.85),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 20 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Icon(
                          Icons.delivery_dining_rounded,
                          color: Colors.white,
                          size: isMobile ? 26 : 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sélectionner un Livreur',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isMobile ? 20 : 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Commande #${widget.order['orderId']} • ${deliveryUsers.length} livreurs disponibles',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        iconSize: 24,
                        padding: const EdgeInsets.all(8),
                      ),
                    ],
                  ),
                  if (!isMobile) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.white.withOpacity(0.9), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Livreurs triés par note et disponibilité',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Flexible(
              child: deliveryUsers.isEmpty
                  ? _buildEmptyDeliveryState(isMobile)
                  : ListView.separated(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      itemCount: deliveryUsers.length,
                      separatorBuilder: (context, index) => SizedBox(height: isMobile ? 12 : 16),
                      itemBuilder: (context, index) {
                        final user = deliveryUsers[index];
                        return _buildDeliveryPersonCard(context, user, isMobile);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryPersonCard(BuildContext context, Map<String, dynamic> user, bool isMobile) {
    final fullName = user['fullName'] ?? 'Livreur';
    final email = user['email'] ?? 'Email non disponible';
    final phone = user['phoneNumber'] ?? 'Non spécifié';
    final isAvailable = user['available'] ?? false;
    final rating = (user['rating'] ?? 4.5).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAvailable 
              ? AppColors.primary.withOpacity(0.3) 
              : Colors.grey[300]!,
          width: isAvailable ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isAvailable
                ? AppColors.primary.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: isAvailable ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: isMobile ? 60 : 70,
                  height: isMobile ? 60 : 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isAvailable
                          ? [AppColors.primary.withOpacity(0.8), AppColors.primary.withOpacity(0.6)]
                          : [Colors.grey[400]!, Colors.grey[300]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isAvailable ? Colors.white : Colors.grey[200]!,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.delivery_dining_rounded,
                          color: Colors.white,
                          size: isMobile ? 28 : 32,
                        ),
                      ),
                      if (isAvailable)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              fullName,
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAvailable 
                                  ? Colors.green.withOpacity(0.15) 
                                  : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isAvailable ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAvailable ? 'Disponible' : 'Occupé',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isAvailable ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildContactItem(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildContactItem(
                    icon: Icons.phone_outlined,
                    label: 'Téléphone',
                    value: phone,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isAvailable 
                    ? () => Navigator.pop(context, user)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAvailable ? AppColors.primary : Colors.grey[300],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isAvailable ? 2 : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAvailable ? Icons.check_circle_outline : Icons.block,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isAvailable ? 'Assigner ce livreur' : 'Non disponible',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDeliveryState(bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 24 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delivery_dining_outlined,
                size: isMobile ? 48 : 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun livreur disponible',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tous les livreurs sont actuellement occupés.\nVeuillez réessayer plus tard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
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
    // Get coordinates from order backend data
    double? lat;
    double? lng;

    try {
      // Extract latitude from order
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

      // Extract longitude from order
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

      // Check if coordinates are valid
      if (lat == null || lng == null) {
        _showSnackBar('Coordonnées non disponibles pour cette livraison', isError: true);
        debugPrint('❌ Missing coordinates - lat: $lat, lng: $lng');
        return;
      }

      debugPrint('📍 Opening maps with backend coordinates: lat=$lat, lng=$lng');
    } catch (e) {
      debugPrint('❌ Error parsing coordinates: $e');
      _showSnackBar('Erreur lors de la lecture des coordonnées', isError: true);
      return;
    }

    await _openInGoogleMaps(lat!, lng!, address);
  }

  Future<void> _openInGoogleMaps(double lat, double lng, String address) async {
    try {
      debugPrint('🗺️ Attempting to open Google Maps with lat: $lat, lng: $lng');

      // Encode address for URL
      final encodedAddress = Uri.encodeComponent(address);

      // Try different URL schemes in order of preference
      final urls = [
        // Google Maps web URL (should work on all platforms)
        'https://www.google.com/maps/?q=$lat,$lng',
        // Google Maps API URL
        'https://maps.google.com/?q=$lat,$lng',
        // Google Maps with address
        'https://www.google.com/maps/search/$encodedAddress/@$lat,$lng,17z',
        // Apple Maps fallback
        'https://maps.apple.com/?q=$lat,$lng',
      ];

      bool opened = false;

      for (String urlString in urls) {
        try {
          debugPrint('🔄 Trying URL: $urlString');
          final uri = Uri.parse(urlString);

          if (await canLaunchUrl(uri)) {
            debugPrint('✅ URL is supported, launching: $urlString');
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            opened = true;
            break;
          } else {
            debugPrint('⚠️ canLaunchUrl returned false for: $urlString');
          }
        } catch (e) {
          debugPrint('❌ Error with URL $urlString: $e');
          continue;
        }
      }

      if (!opened) {
        debugPrint('❌ No URL schemes worked, trying direct launch...');
        // Last resort: try launching directly
        try {
          final fallbackUrl = Uri.parse('https://www.google.com/maps/?q=$lat,$lng');
          await launchUrl(fallbackUrl);
          opened = true;
        } catch (e) {
          debugPrint('❌ Fallback also failed: $e');
        }
      }

      if (!opened) {
        _showSnackBar('Impossible d\'ouvrir Google Maps. Vérifiez votre connexion Internet.', isError: true);
        debugPrint('❌ All attempts failed');
      }
    } catch (e) {
      debugPrint('❌ Error in _openInGoogleMaps: $e');
      _showSnackBar('Erreur: ${e.toString()}', isError: true);
    }
  }

  List<Map<String, dynamic>> _parseToppings(dynamic toppingsData) {
    if (toppingsData == null) return [];

    if (toppingsData is String) {
      try {
        final decoded = toppingsData.replaceAll('&quot;', '"');
        final List<dynamic> parsed = [];
        final regex = RegExp(r'\{"toppingId":\s*(\d+),\s*"toppingName":\s*"([^"]+)"\}');
        final matches = regex.allMatches(decoded);

        for (final match in matches) {
          parsed.add({
            'toppingId': int.parse(match.group(1)!),
            'toppingName': match.group(2)!
          });
        }
        return parsed.cast<Map<String, dynamic>>();
      } catch (e) {
        return [];
      }
    }

    if (toppingsData is List) {
      return toppingsData.cast<Map<String, dynamic>>();
    }

    return [];
  }

  List<Map<String, dynamic>> _parseExtras(dynamic extrasData) {
    if (extrasData == null) return [];

    if (extrasData is String) {
      try {
        final decoded = extrasData.replaceAll('&quot;', '"');
        final List<dynamic> parsed = [];
        final regex = RegExp(r'\{"extraId":\s*(\d+),\s*"extraName":\s*"([^"]+)",\s*"extraPrice":\s*([\d.]+)\}');
        final matches = regex.allMatches(decoded);

        for (final match in matches) {
          parsed.add({
            'extraId': int.parse(match.group(1)!),
            'extraName': match.group(2)!,
            'extraPrice': double.parse(match.group(3)!)
          });
        }
        return parsed.cast<Map<String, dynamic>>();
      } catch (e) {
        return [];
      }
    }

    if (extrasData is List) {
      return extrasData.cast<Map<String, dynamic>>();
    }

    return [];
  }

  Widget _buildToppingsSection(List<Map<String, dynamic>> toppings) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50] ?? Colors.blue.withOpacity(0.1), Colors.blue[25] ?? Colors.blue.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200] ?? Colors.blue.withOpacity(0.3), width: 1),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400] ?? Colors.blue, Colors.blue[600] ?? Colors.blue],
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
                  child: const Icon(Icons.restaurant_menu, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Garnitures • ${toppings.length} sélection${toppings.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[600] ?? Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: toppings.map<Widget>((topping) {
                final name = topping['toppingName']?.toString() ?? 'Garniture';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.blue[50] ?? Colors.blue.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[300] ?? Colors.blue.withOpacity(0.3), width: 0.8),
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
                      const SizedBox(width: 5),
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
    double totalExtraPrice = 0.0;
    for (var extra in extras) {
      totalExtraPrice += (extra['extraPrice'] ?? 0.0) as double;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50] ?? Colors.green.withOpacity(0.1), Colors.green[25] ?? Colors.green.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200] ?? Colors.green.withOpacity(0.3), width: 1),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green[400] ?? Colors.green, Colors.green[600] ?? Colors.green],
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
                  child: const Icon(Icons.add_circle, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Suppléments • ${extras.length} addition${extras.length > 1 ? 's' : ''} (+${totalExtraPrice.toStringAsFixed(2)} DT)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.green[600] ?? Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: extras.map<Widget>((extra) {
                final name = extra['extraName']?.toString() ?? 'Supplément';
                final price = (extra['extraPrice'] ?? 0.0) as double;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.green[50] ?? Colors.green.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[300] ?? Colors.green.withOpacity(0.3), width: 0.8),
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
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[500] ?? Colors.green, Colors.green[600] ?? Colors.green],
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
                      const SizedBox(width: 6),
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
    final product = item['productDetails'] as Map<String, dynamic>?;
    if (product == null) return 0.0;
    
    final quantity = item['quantity'] ?? 1;
    final basePrice = (product['productFinalePrice'] ?? 0).toDouble();
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
      } else {
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