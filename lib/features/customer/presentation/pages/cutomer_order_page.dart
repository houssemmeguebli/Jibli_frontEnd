import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/theme/theme.dart';
import '../../../../core/services/user_service.dart';
import '../../../../Core/services/order_service.dart';
import '../../../../Core/services/order_item_service.dart';
import '../../../../core/services/attachment_service.dart';
import 'customer_home_page.dart';
import '../widgets/location_picker_widget.dart';
import 'package:latlong2/latlong.dart';

class CustomerOrderPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalAmount;
  final double deliveryFee;
  final int userId;
  final String? companyName;
  final Map<String, dynamic>? company;

  const CustomerOrderPage({
    required this.cartItems,
    required this.totalAmount,
    required this.deliveryFee,
    required this.userId,
    this.companyName,
    this.company,
    super.key,
  });

  @override
  State<CustomerOrderPage> createState() => _CustomerOrderPageState();
}

class _CustomerOrderPageState extends State<CustomerOrderPage> {
  final UserService _userService = UserService();
  final OrderService _orderService = OrderService();
  final OrderItemService _orderItemService = OrderItemService();
  final AttachmentService _attachmentService = AttachmentService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _notesController;

  bool _isLoading = true;
  bool _isSubmitting = false;
  late Map<int, Uint8List?> _productImages;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _productImages = {};
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _notesController = TextEditingController();
    _loadUserData();
    _loadProductImages();
  }

  Future<void> _loadProductImages() async {
    try {
      for (var item in widget.cartItems) {
        final productId = item['productId'] as int?;
        if (productId != null && !_productImages.containsKey(productId)) {
          await _loadProductImage(productId);
        }
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading product images: $e');
    }
  }

  Future<void> _loadProductImage(int productId) async {
    try {
      final attachments =
      await _attachmentService.findByProductProductId(productId);

      if (attachments.isNotEmpty) {
        try {
          final firstAttachment = attachments.first as Map<String, dynamic>;
          final attachmentId = firstAttachment['attachmentId'] as int?;

          if (attachmentId != null) {
            final attachmentDownload =
            await _attachmentService.downloadAttachment(attachmentId);
            if (attachmentDownload.data.isNotEmpty) {
              _productImages[productId] = attachmentDownload.data;
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

  Future<void> _loadUserData() async {
    try {
      final user = await _userService.getUserById(widget.userId);
      if (user != null) {
        setState(() {
          _nameController.text = user['fullName'] ?? '';
          _emailController.text = user['email'] ?? '';
          _addressController.text = user['address'] ?? '';
          _phoneController.text = user['phoneNumber'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des données: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le nom est requis';
    }
    if (value.length < 3) {
      return 'Le nom doit contenir au moins 3 caractères';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Veuillez entrer un email valide';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le téléphone est requis';
    }
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.length != 8) {
      return 'Le numéro doit contenir 8 chiffres';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'adresse est requise';
    }
    if (value.length < 5) {
      return 'L\'adresse doit contenir au moins 5 caractères';
    }
    return null;
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Confirmation'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Êtes-vous sûr de vouloir passer cette commande ?',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withOpacity(0.08),
                      AppColors.primary.withOpacity(0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConfirmDetailRow('Nom', _nameController.text),
                    const SizedBox(height: 12),
                    if (_emailController.text.isNotEmpty) ...[
                      _buildConfirmDetailRow('Email', _emailController.text),
                      const SizedBox(height: 12),
                    ],
                    _buildConfirmDetailRow('Téléphone', _phoneController.text),
                    const SizedBox(height: 12),
                    _buildConfirmDetailRow('Adresse', _addressController.text),
                    Divider(color: Colors.grey[300], height: 24),
                    _buildConfirmDetailRow(
                      'Articles',
                      '${widget.cartItems.length}',
                      isHighlight: true,
                    ),
                    const SizedBox(height: 8),
                    _buildConfirmDetailRow(
                      'Livraison',
                      widget.deliveryFee > 0
                          ? '${widget.deliveryFee.toStringAsFixed(2)} DT'
                          : 'Gratuite',
                      isDelivery: true,
                    ),
                    const SizedBox(height: 8),
                    _buildConfirmDetailRow(
                      'Montant Total',
                      '${(widget.totalAmount+widget.deliveryFee).toStringAsFixed(2)} DT',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final deliveryFee = (widget.company?['deliveryFee'] ?? 0.0) as num;
              _createOrder(widget.deliveryFee);
              },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 20),
                SizedBox(width: 8),
                Text('Confirmer'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmDetailRow(
      String label,
      String value, {
        bool isTotal = false,
        bool isHighlight = false,
        bool isDelivery = false,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal || isHighlight ? FontWeight.w700 : FontWeight.w600,
              color: isDelivery && value == 'Gratuite'
                  ? Colors.green
                  : isTotal
                  ? AppColors.primary
                  : isHighlight
                  ? AppColors.primary.withOpacity(0.8)
                  : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createOrder(double deliveryFee) async {
    setState(() => _isSubmitting = true);

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Création de la commande...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Veuillez patienter',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );

      final DateTime now = DateTime.now();
      final finalTotal = widget.totalAmount + widget.deliveryFee;
      final totalProducts = widget.cartItems.length;
      final totalQuantity = widget.cartItems.fold<int>(
        0,
            (sum, item) => sum + (item['quantity'] as int),
      );

      int companyId = 1;
      if (widget.cartItems.isNotEmpty) {
        final firstItem = widget.cartItems.first;
        if (firstItem.containsKey('companyId')) {
          companyId = firstItem['companyId'];
        }
      }

      final orderData = {
        'userId': widget.userId,
        'companyId': companyId,
        'customerName': _nameController.text,
        'customerEmail': _emailController.text,
        'customerAddress': _addressController.text,
        'customerPhone': _phoneController.text,
        'orderNotes': _notesController.text,
        'totalProducts': totalProducts,
        'quantity': totalQuantity,
        'discount': 0,
        'totalAmount': widget.totalAmount,
        'deliveryFee': deliveryFee,
        'orderStatus': 'PENDING',
        'orderItemIds': [],
        'latitude': _selectedLocation?.latitude,
        'longitude': _selectedLocation?.longitude,
      };

      debugPrint('📦 Creating order with data: $orderData');
      final createdOrder = await _orderService.createOrder(orderData);
      final orderId = createdOrder['orderId'];
      debugPrint('✅ Order created with ID: $orderId');

      final List<int> orderItemIds = [];
      for (var cartItem in widget.cartItems) {
        final productId = cartItem['productId'] as int?;
        final quantity = cartItem['quantity'] as int?;

        if (productId != null && quantity != null) {
          final unitPrice = (cartItem['unitPrice'] ?? cartItem['productFinalePrice'] ?? cartItem['productPrice'] ?? 0.0) as num;

          // Extract clean lists of IDs
          final toppingIds = _extractToppingIds(cartItem['selectedToppings']);
          final extraIds = _extractExtraIds(cartItem['selectedExtras']);

          debugPrint('🛒 Cart Item - Product: $productId, Qty: $quantity, Price: $unitPrice');
          debugPrint('   Toppings IDs: $toppingIds');
          debugPrint('   Extras IDs: $extraIds');

          final orderItemData = {
            'orderId': orderId,
            'productId': productId,
            'quantity': quantity,
            'unitPrice': unitPrice.toDouble(),
            'selectedToppingIds': toppingIds,
            'selectedExtraIds': extraIds,
          };

          debugPrint('📝 Order item payload: $orderItemData');

          try {
            final orderItem = await _orderItemService.createOrderItem(orderItemData);
            final orderItemId = orderItem['orderItemId'];
            orderItemIds.add(orderItemId);
            debugPrint('✅ Order item created: $orderItemId');
          } catch (e) {
            debugPrint('❌ Error creating order item: $e');
            throw Exception('Erreur lors de la création de l\'article: $e');
          }
        }
      }

      debugPrint('📋 All order items created: $orderItemIds');

      if (orderItemIds.isNotEmpty) {
        final updatedOrderData = Map<String, dynamic>.from(orderData);
        updatedOrderData['orderItemIds'] = orderItemIds;
        await _orderService.updateOrder(orderId, updatedOrderData);
        debugPrint('✅ Order updated with item IDs');
      }

      if (mounted) Navigator.pop(context);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.withOpacity(0.15),
                          Colors.green.withOpacity(0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Commande Créée',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Votre commande #$orderId',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Articles:',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                            Text(
                              '${widget.cartItems.length}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total:',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                            Text(
                              '${finalTotal.toStringAsFixed(2)} DT',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retour à l\'accueil'),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      setState(() => _isSubmitting = false);
    } catch (e) {
      debugPrint('❌ Order creation failed: $e');
      if (mounted) Navigator.pop(context);
      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  /// Extract topping IDs from various formats
  List<int> _extractToppingIds(dynamic toppingsData) {
    if (toppingsData == null) return [];

    debugPrint('🔍 Extracting topping IDs from: $toppingsData (type: ${toppingsData.runtimeType})');

    // Already a List<int>
    if (toppingsData is List && toppingsData.isNotEmpty) {
      if (toppingsData.first is int) {
        debugPrint('✅ Toppings is already List<int>: $toppingsData');
        return List<int>.from(toppingsData);
      }

      // List of maps with toppingId
      if (toppingsData.first is Map) {
        final ids = toppingsData
            .whereType<Map<String, dynamic>>()
            .map((t) => t['toppingId'] as int? ?? 0)
            .where((id) => id != 0)
            .toList();
        debugPrint('✅ Extracted topping IDs from map list: $ids');
        return ids;
      }
    }

    // Empty list
    if (toppingsData is List && toppingsData.isEmpty) {
      debugPrint('✅ Toppings is empty list');
      return [];
    }

    // Encoded string format
    if (toppingsData is String && toppingsData.isNotEmpty) {
      try {
        final decoded = toppingsData.replaceAll('&quot;', '"');
        final List<int> ids = [];
        final regex = RegExp(r'"toppingId":\s*(\d+)');
        final matches = regex.allMatches(decoded);

        for (final match in matches) {
          ids.add(int.parse(match.group(1)!));
        }
        debugPrint('✅ Extracted topping IDs from string: $ids');
        return ids;
      } catch (e) {
        debugPrint('⚠️ Error extracting topping IDs: $e');
        return [];
      }
    }

    debugPrint('⚠️ Could not extract topping IDs, returning empty list');
    return [];
  }

  /// Extract extra IDs from various formats
  List<int> _extractExtraIds(dynamic extrasData) {
    if (extrasData == null) return [];

    debugPrint('🔍 Extracting extra IDs from: $extrasData (type: ${extrasData.runtimeType})');

    // Already a List<int>
    if (extrasData is List && extrasData.isNotEmpty) {
      if (extrasData.first is int) {
        debugPrint('✅ Extras is already List<int>: $extrasData');
        return List<int>.from(extrasData);
      }

      // List of maps with extraId
      if (extrasData.first is Map) {
        final ids = extrasData
            .whereType<Map<String, dynamic>>()
            .map((e) => e['extraId'] as int? ?? 0)
            .where((id) => id != 0)
            .toList();
        debugPrint('✅ Extracted extra IDs from map list: $ids');
        return ids;
      }
    }

    // Empty list
    if (extrasData is List && extrasData.isEmpty) {
      debugPrint('✅ Extras is empty list');
      return [];
    }

    // Encoded string format
    if (extrasData is String && extrasData.isNotEmpty) {
      try {
        final decoded = extrasData.replaceAll('&quot;', '"');
        final List<int> ids = [];
        final regex = RegExp(r'"extraId":\s*(\d+)');
        final matches = regex.allMatches(decoded);

        for (final match in matches) {
          ids.add(int.parse(match.group(1)!));
        }
        debugPrint('✅ Extracted extra IDs from string: $ids');
        return ids;
      } catch (e) {
        debugPrint('⚠️ Error extracting extra IDs: $e');
        return [];
      }
    }

    debugPrint('⚠️ Could not extract extra IDs, returning empty list');
    return [];
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Informations de Livraison',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.black87, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.companyName != null) ...[
                  _buildCompanyCard(),
                  const SizedBox(height: 24),
                ],
                _buildOrderSummaryCard(),
                const SizedBox(height: 24),
                _buildItemsSection(),
                const SizedBox(height: 28),
                const Text(
                  'Vos Informations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                _buildModernFormField(
                  controller: _nameController,
                  label: 'Nom Complet',
                  icon: Icons.person_outline,
                  hint: 'Votre nom complet',
                  validator: _validateName,
                ),
                const SizedBox(height: 18),
                _buildModernFormField(
                  controller: _emailController,
                  label: 'Email (Optionnel)',
                  icon: Icons.email_outlined,
                  hint: 'votre.email@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 18),
                _buildModernFormField(
                  controller: _phoneController,
                  label: 'Téléphone',
                  icon: Icons.phone_outlined,
                  hint: '12345678',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validatePhone,
                  maxLength: 8,
                ),
                const SizedBox(height: 18),
                _buildAddressFieldWithMap(),
                const SizedBox(height: 18),
                _buildModernFormField(
                  controller: _notesController,
                  label: 'Notes (Optionnel)',
                  icon: Icons.note_outlined,
                  hint: 'Instructions de livraison...',
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                      shadowColor: AppColors.primary.withOpacity(0.5),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withOpacity(0.9),
                        ),
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Passer la Commande',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(color: Colors.grey[300]!, width: 2),
                    ),
                    child: Text(
                      'Retour au Panier',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyCard() {
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.store_outlined,
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
                  'Vendeur',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.companyName!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    final finalTotal = widget.totalAmount + widget.deliveryFee;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Résumé de la Commande',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.cartItems.length} article${widget.cartItems.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 12),
          _buildSummaryRow('Sous-total', '${widget.totalAmount.toStringAsFixed(2)} DT'),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Livraison',
            widget.deliveryFee > 0
                ? '${widget.deliveryFee.toStringAsFixed(2)} DT'
                : 'Gratuite',
            isDelivery: true,
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey[200]),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'Total',
            '${finalTotal.toStringAsFixed(2)} DT',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isDelivery = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Colors.grey[800] : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            color: isDelivery && value == 'Gratuite'
                ? Colors.green
                : isTotal
                ? AppColors.primary
                : Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Articles de la Commande',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.cartItems.length,
            separatorBuilder: (context, index) =>
                Divider(color: Colors.grey[200], height: 1),
            itemBuilder: (context, index) {
              final item = widget.cartItems[index];
              return _buildOrderItemCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemCard(Map<String, dynamic> item) {
    final productId = item['productId'] as int?;
    final productName = item['productName'] ?? 'Produit';
    final quantity = item['quantity'] ?? 1;
    final priceValue = item['productFinalePrice'] ?? item['productPrice'] ?? 0.0;
    final price = (priceValue is int) ? priceValue.toDouble() : (priceValue as double);
    final originalPriceValue = item['productPrice'] ?? price;
    final originalPrice = (originalPriceValue is int) ? originalPriceValue.toDouble() : (originalPriceValue as double);
    final itemTotal = _calculateItemTotalWithExtras(item);
    final hasDiscount = price < originalPrice;
    final productImage = productId != null ? _productImages[productId] : null;
    final toppings = _parseToppings(item['selectedToppings']);
    final extras = _parseExtras(item['selectedExtras']);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: productImage != null
                      ? Image.memory(
                    productImage,
                    fit: BoxFit.cover,
                  )
                      : Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.grey[400],
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasDiscount) ...[
                            Text(
                              '${originalPrice.toStringAsFixed(2)} DT',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            '${price.toStringAsFixed(2)} DT',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[600],
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'PROMO',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Qty: $quantity',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        Text(
                          '${itemTotal.toStringAsFixed(2)} DT',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
    );
  }

  Widget _buildAddressFieldWithMap() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      'Sélectionnez sur la carte ou saisissez manuellement',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
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
                child: TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  validator: _validateAddress,
                  decoration: InputDecoration(
                    hintText: 'Votre adresse complète',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.edit_location_alt,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.red[400]!,
                        width: 1.5,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.red[400]!,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openLocationPicker(),
                    child: const Icon(
                      Icons.map_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Problème avec la carte ? Entrez votre adresse manuellement',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedLocation != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Localisation sélectionnée: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openLocationPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerWidget(
          onLocationSelected: (lat, lng) async {
            setState(() {
              _selectedLocation = LatLng(lat, lng);
            });
            await _updateAddressFromCoordinates(lat, lng);
          },
          initialLocation: _selectedLocation,
        ),
      ),
    );
  }

  Future<void> _updateAddressFromCoordinates(double lat, double lng) async {
    try {
      final address = await _getAddressFromCoordinates(lat, lng);
      if (address.isNotEmpty) {
        setState(() {
          _addressController.text = address;
        });
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1&accept-language=fr';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Jibli-App/1.0'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Geocoding response: $data');
        
        final address = data['address'] as Map<String, dynamic>?;
        
        if (address != null) {
          debugPrint('Address components: $address');
          List<String> addressParts = [];
          
          // Street with house number
          String? street;
          if (address['house_number'] != null && address['road'] != null) {
            street = '${address['house_number']} ${address['road']}';
          } else if (address['road'] != null) {
            street = address['road'];
          } else if (address['pedestrian'] != null) {
            street = address['pedestrian'];
          }
          if (street != null) addressParts.add(street);
          
          // Area/District
          String? area = address['suburb'] ?? 
                        address['neighbourhood'] ?? 
                        address['quarter'] ?? 
                        address['district'];
          if (area != null) addressParts.add(area);
          
          // City
          String? city = address['city'] ?? 
                        address['town'] ?? 
                        address['village'] ?? 
                        address['municipality'];
          if (city != null) addressParts.add(city);
          
          if (addressParts.isNotEmpty) {
            final result = addressParts.join(', ');
            debugPrint('Formatted address: $result');
            return result;
          }
        }
        
        // Fallback to display_name but clean it up
        String displayName = data['display_name'] ?? 'Adresse non trouvée';
        // Remove coordinates and country code from display name
        displayName = displayName.split(',').take(3).join(', ');
        return displayName;
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
    }
    return 'Coordonnées: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
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
        debugPrint('Error parsing toppings: $e');
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
        debugPrint('Error parsing extras: $e');
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
                    '${toppings.length} garniturs${toppings.length > 1 ? 's' : ''}',
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
                    '${extras.length} addition${extras.length > 1 ? 's' : ''} • +${totalExtraPrice.toStringAsFixed(2)} DT',
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
    final quantity = item['quantity'] ?? 1;
    final basePrice = (item['productFinalePrice'] ?? item['productPrice'] ?? 0.0) as double;
    final extras = _parseExtras(item['selectedExtras']);

    double extraPrice = 0.0;
    for (var extra in extras) {
      extraPrice += (extra['extraPrice'] ?? 0.0) as double;
    }

    return (basePrice + extraPrice) * quantity;
  }

  Widget _buildModernFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                letterSpacing: -0.2,
              ),
            ),
            if (!label.contains('Optionnel'))
              Text(
                ' *',
                style: TextStyle(color: Colors.red[500], fontSize: 16),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            prefixIcon: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
            ),
            errorText: null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.red[400]!,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.red[400]!,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            counterText: '',
          ),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[800],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}