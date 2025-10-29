import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/user_service.dart';
import '../../../../Core/services/order_service.dart';
import '../../../../Core/services/order_item_service.dart';

class CustomerOrderPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final double totalAmount;
  final int userId;

  const CustomerOrderPage({
    required this.cartItems,
    required this.totalAmount,
    required this.userId,
    super.key,
  });

  @override
  State<CustomerOrderPage> createState() => _CustomerOrderPageState();
}

class _CustomerOrderPageState extends State<CustomerOrderPage> {
  final UserService _userService = UserService('http://192.168.1.216:8080');
  final OrderService _orderService = OrderService();
  final OrderItemService _orderItemService = OrderItemService();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _loadUserData();
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
    super.dispose();
  }

  Future<void> _submitOrder() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Confirmer la commande'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Êtes-vous sûr de vouloir passer cette commande ?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Nom', _nameController.text),
                  const SizedBox(height: 8),
                  _buildDetailRow('Email', _emailController.text),
                  const SizedBox(height: 8),
                  _buildDetailRow('Téléphone', _phoneController.text),
                  const SizedBox(height: 8),
                  _buildDetailRow('Adresse', _addressController.text),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Montant Total',
                    '${(widget.totalAmount).toStringAsFixed(2)} DT',
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createOrder();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Confirmer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
              color: isTotal ? AppColors.primary : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _createOrder() async {
    setState(() => _isSubmitting = true);

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Création de la commande...'),
            ],
          ),
        ),
      );

      final DateTime now = DateTime.now();
      final deliveryFee = 0.0;
      final finalTotal = widget.totalAmount + deliveryFee;
      final totalProducts = widget.cartItems.length;
      final totalQuantity = widget.cartItems.fold<int>(
        0,
            (sum, item) => sum + (item['quantity'] as int),
      );

      final firstProduct =
      widget.cartItems.first['product'] as Map<String, dynamic>;
      final companyId = firstProduct['companyId'] ?? 1;

      // Create order
      final orderData = {
        'userId': widget.userId,
        'companyId': companyId,
        'customerName': _nameController.text,
        'customerEmail': _emailController.text,
        'customerAddress': _addressController.text,
        'customerPhone': _phoneController.text,
        'orderNotes': '',
        'totalProducts': totalProducts,
        'quantity': totalQuantity,
        'discount': 0,
        'totalAmount': finalTotal,
        'orderStatus': 'PENDING',
        'orderDate': now.toIso8601String(),
        'shippedDate': now.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'lastUpdated': now.toIso8601String(),
        'orderItemIds': [],
      };

      final createdOrder = await _orderService.createOrder(orderData);
      final orderId = createdOrder['orderId'];

      // Create order items
      final List<int> orderItemIds = [];
      for (var cartItem in widget.cartItems) {
        final product = cartItem['product'] as Map<String, dynamic>;
        final orderItemData = {
          'orderId': orderId,
          'productId': product['productId'],
          'quantity': cartItem['quantity'],
          'unitPrice': product['productFinalePrice'],
          'totalPrice':
          (product['productFinalePrice'] * cartItem['quantity']).toDouble(),
        };
        final orderItem =
        await _orderItemService.createOrderItem(orderItemData);
        orderItemIds.add(orderItem['orderItemId']);
      }

      // Update order with order item IDs
      if (orderItemIds.isNotEmpty) {
        final updatedOrderData = Map<String, dynamic>.from(orderData);
        updatedOrderData['orderItemIds'] = orderItemIds;
        await _orderService.updateOrder(orderId, updatedOrderData);
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                const Text('Commande créée'),
              ],
            ),
            content: Text(
              'Votre commande #$orderId a été créée avec succès!\n\nTotal: ${finalTotal.toStringAsFixed(2)} DT',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close success dialog
                  Navigator.pop(context); // Go back to cart
                  Navigator.pop(context); // Go back to home
                },
                child: const Text('Continuer les achats'),
              ),
            ],
          ),
        );
      }

      setState(() => _isSubmitting = false);
    } catch (e) {
      // Close loading dialog if open
      if (mounted) Navigator.pop(context);

      setState(() => _isSubmitting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la création de la commande: $e'),
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
        title: const Text(
          'Informations de Livraison',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Summary Card
              _buildOrderSummaryCard(),
              const SizedBox(height: 24),

              // Form Section
              const Text(
                'Vos Informations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Name Field
              _buildFormField(
                controller: _nameController,
                label: 'Nom Complet',
                icon: Icons.person_outline,
                hint: 'Votre nom complet',
              ),
              const SizedBox(height: 16),

              // Email Field
              _buildFormField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                hint: 'votre.email@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Phone Field
              _buildFormField(
                controller: _phoneController,
                label: 'Téléphone',
                icon: Icons.phone_outlined,
                hint: '+216 XX XXX XXX',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Address Field
              _buildFormField(
                controller: _addressController,
                label: 'Adresse de Livraison',
                icon: Icons.location_on_outlined,
                hint: 'Votre adresse complète',
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Submit Button
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
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        Colors.white,
                      ),
                    ),
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Passer la Commande',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward,
                          color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Back Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  child: const Text(
                    'Retour au Panier',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Articles: ${widget.cartItems.length}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              Text(
                '${widget.totalAmount.toStringAsFixed(2)} DT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}