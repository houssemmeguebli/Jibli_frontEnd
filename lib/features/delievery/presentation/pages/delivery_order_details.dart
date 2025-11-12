import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../core/theme/theme.dart';
import '../../../../Core/services/order_item_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/order_service.dart';
import '../../../../core/services/company_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DeliveryOrderDetailsPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const DeliveryOrderDetailsPage({required this.order, super.key});

  @override
  State<DeliveryOrderDetailsPage> createState() => _DeliveryOrderDetailsPageState();
}

class _DeliveryOrderDetailsPageState extends State<DeliveryOrderDetailsPage> {
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
  bool _isLoadingCompany = true;

  @override
  void initState() {
    super.initState();
    _loadOrderItems();
    _loadCompanyInfo();
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
      final items = await _orderItemService.getOrderItemsByOrder(
        widget.order['orderId'],
      );

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
        _isLoading = false;
      });

      // Load images after order items are set
      await _loadProductImages();
    } catch (e) {
      print('Error loading order items: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProductImages() async {
    try {
      final Map<int, List<Uint8List>> images = {};
      final Map<int, int> selectedIndices = {};

      for (var item in _orderItems) {
        final product = item['product'] as Map<String, dynamic>?;
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
            selectedIndices[productId] = 0;
          }
        } catch (e) {
          debugPrint('⚠️ Error loading images for product $productId: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _productImages = images;
          _selectedImageIndex = selectedIndices;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading product images: $e');
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      final confirm = await _showConfirmDialog(
        'Confirmer le changement',
        'Êtes-vous sûr de vouloir changer le statut à "${_getStatusLabel(newStatus)}"?',
      );

      if (!confirm) return;

      if (mounted) {
        _showLoadingDialog('Mise à jour en cours...');
      }

      await _orderService.patchOrderStatus(widget.order['orderId'], newStatus);

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('Statut mis à jour avec succès');
        widget.order['orderStatus'] = newStatus;
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar('Erreur: ${e.toString()}');
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text(message),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _getStatusColor(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus == 'waiting') return '#FFA500';
    if (lowerStatus == 'accepted') return '#9C27B0';
    if (lowerStatus == 'picked_up') return '#3B82F6';
    if (lowerStatus == 'delivered') return '#10B981';
    if (lowerStatus == 'rejected') return '#EF4444';
    if (lowerStatus == 'in_preparation') return '#6B7280';
    return '#6B7280';
  }

  String _getStatusLabel(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus == 'waiting') return 'Assignée';
    if (lowerStatus == 'accepted') return 'Acceptée';
    if (lowerStatus == 'picked_up') return 'Récupérée';
    if (lowerStatus == 'delivered') return 'Livrée';
    if (lowerStatus == 'rejected') return 'Refusée';
    if (lowerStatus == 'in_preparation') return 'En préparation';
    return status;
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
          'Détails de la Livraison',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildSkeletonOrderDetails()
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildOrderHeader(),
            if (!_isLoadingCompany) _buildCompanyInfo(),
            _buildCustomerInfo(),
            _buildDeliveryStatus(),
            _buildOrderItemsList(),
            const SizedBox(height: 12),
            _buildSummary(),
            _buildActionButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    final orderId = widget.order['orderId'] ?? 'N/A';
    final orderDate = _formatDate(widget.order['orderDate']);
    final status = widget.order['orderStatus'] ?? 'Inconnu';

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
                  color: Color(int.parse(_getStatusColor(status).replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusLabel(status),
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

  Widget _buildCompanyInfo() {
    if (_companyInfo == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
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
            'Vendeur',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.business_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _companyInfo!['companyName'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Téléphone',
            value: _companyInfo!['companyPhone'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _companyInfo!['companyEmail'] ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Adresse',
            value: _companyInfo!['companyAddress'] ?? 'N/A',
            isMultiLine: true,
          ),
          if (_companyInfo!['companyWebsite'] != null && (_companyInfo!['companyWebsite'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.language_outlined,
              label: 'Site Web',
              value: _companyInfo!['companyWebsite'] ?? 'N/A',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerInfo() {
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
            label: 'Nom du Client',
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
        _showErrorSnackBar('Coordonnées non disponibles pour cette livraison');
        debugPrint('❌ Missing coordinates - lat: $lat, lng: $lng');
        return;
      }

      debugPrint('📍 Opening maps with backend coordinates: lat=$lat, lng=$lng');
    } catch (e) {
      debugPrint('❌ Error parsing coordinates: $e');
      _showErrorSnackBar('Erreur lors de la lecture des coordonnées');
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
        _showErrorSnackBar('Impossible d\'ouvrir Google Maps. Vérifiez votre connexion Internet.');
        debugPrint('❌ All attempts failed');
      }
    } catch (e) {
      debugPrint('❌ Error in _openInGoogleMaps: $e');
      _showErrorSnackBar('Erreur: ${e.toString()}');
    }
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

  Widget _buildDeliveryStatus() {
    final upperStatus = widget.order['orderStatus']?.toString().toUpperCase() ?? 'WAITING';

    final steps = [
      {
        'label': 'Assignée',
        'icon': Icons.assignment_rounded,
        'status': 'WAITING',
        'date': widget.order['waitingDate'],
        'completed': ['ACCEPTED', 'PICKED_UP', 'DELIVERED'].contains(upperStatus),
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': 'Acceptée',
        'icon': Icons.check_circle_rounded,
        'status': 'ACCEPTED',
        'date': widget.order['acceptedDate'],
        'completed': ['ACCEPTED', 'PICKED_UP', 'DELIVERED'].contains(upperStatus),
        'color': const Color(0xFF8B5CF6),
      },
      {
        'label': 'Récupérée',
        'icon': Icons.local_shipping_rounded,
        'status': 'PICKED_UP',
        'date': widget.order['pickedUpDate'],
        'completed': ['PICKED_UP', 'DELIVERED'].contains(upperStatus),
        'color': const Color(0xFF3B82F6),
      },
      {
        'label': 'Livrée',
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
              const SizedBox(width: 7),
              const Text(
                'Progression de la Livraison',
                style: TextStyle(
                  fontSize: 18,
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
          if (upperStatus == 'REJECTED')
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
                            'Livraison Refusée',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Le ${_formatDate(widget.order['rejectedDate'])}',
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
            'Articles à Livrer',
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
    final product = item['product'] as Map<String, dynamic>?;
    if (product == null) return const SizedBox.shrink();

    final productId = product['productId'];
    final productName = product['productName'] ?? 'Produit';
    final quantity = item['quantity'] ?? 1;
    final unitPrice = (item['unitPrice'] ?? 0).toDouble();

    final images = _productImages[productId] ?? [];
    final selectedIndex = _selectedImageIndex[productId] ?? 0;

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produit: $productName'),
            duration: const Duration(seconds: 2),
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
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.1),
                            Colors.grey[100]!,
                          ],
                        ),
                      ),
                      child: images.isNotEmpty && images[selectedIndex].isNotEmpty
                          ? Image.memory(
                        images[selectedIndex],
                        fit: BoxFit.cover,
                      )
                          : Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.grey[400],
                        size: 40,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${unitPrice.toStringAsFixed(2)} DT',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Quantité: $quantity',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(unitPrice * quantity).toStringAsFixed(2)} DT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (images.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImageIndex[productId] = index;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedImageIndex[productId] == index
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: images[index].isNotEmpty
                                ? Image.memory(
                              images[index],
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            )
                                : Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 24,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final subtotal = widget.order['totalAmount'] ?? 0.0;
    final deliveryFee = widget.order['deliveryFee'] ?? 0.0;
    final total = subtotal + deliveryFee;

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
        children: [
          _buildSummaryRow(
            'Sous-total',
            '${subtotal.toStringAsFixed(2)} DT',
            isTotal: false,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Livrasion',
            '${deliveryFee.toStringAsFixed(2)} DT',
            isTotal: false,
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Service',
            'Gratuit',
            isTotal: false,
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Total à Collecter',
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

  Widget _buildActionButtons() {
    final status = widget.order['orderStatus'] ?? 'WAITING';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          if (status == 'WAITING') ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateOrderStatus('REJECTED'),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Refuser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateOrderStatus('ACCEPTED'),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Accepter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else if (status == 'ACCEPTED')
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _updateOrderStatus('PICKED_UP'),
                icon: const Icon(Icons.local_shipping, size: 18),
                label: const Text('Récupérer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else if (status == 'PICKED_UP')
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateOrderStatus('DELIVERED'),
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Livré'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            else if (status == 'DELIVERED')
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Livraison Confirmée',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (status == 'REJECTED')
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Livraison Refusée',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
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
}
  Widget _buildSkeletonOrderDetails() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _buildSkeletonOrderHeader(),
          _buildSkeletonCompanyInfo(),
          _buildSkeletonCustomerInfo(),
          _buildSkeletonDeliveryStatus(),
          _buildSkeletonOrderItems(),
          _buildSkeletonSummary(),
          _buildSkeletonActionButtons(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSkeletonOrderHeader() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 140,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 100,
                    height: 13,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
              Container(
                width: 80,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonCompanyInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(3, (index) => 
            Padding(
              padding: EdgeInsets.only(bottom: index < 2 ? 12 : 0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(7),
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

  Widget _buildSkeletonCustomerInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 160,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(4, (index) => 
            Padding(
              padding: EdgeInsets.only(bottom: index < 3 ? 12 : 0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(7),
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

  Widget _buildSkeletonDeliveryStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 180,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...List.generate(4, (index) => 
            Padding(
              padding: EdgeInsets.only(bottom: index < 3 ? 28 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (index < 3)
                        Container(
                          width: 4,
                          height: 70,
                          margin: const EdgeInsets.only(top: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
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
                          Container(
                            width: 120,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: 100,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildSkeletonOrderItems() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(2, (index) => 
            Container(
              margin: EdgeInsets.only(bottom: index < 1 ? 12 : 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 15,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 80,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 70,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 60,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ],
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

  Widget _buildSkeletonSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(4, (index) => 
          Padding(
            padding: EdgeInsets.only(bottom: index < 3 ? 12 : 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 80,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                Container(
                  width: 60,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }