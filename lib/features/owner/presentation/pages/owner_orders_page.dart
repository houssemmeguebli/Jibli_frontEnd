import 'package:flutter/material.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../Core/services/attachment_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../Core/services/order_service.dart';
import '../../../../Core/services/order_item_service.dart';
import '../../../../Core/services/product_service.dart';
import '../../../../Core/services/user_service.dart';
import 'dart:typed_data' as typed_data;

import 'owner_order_details_page.dart';

class OwnerOrdersPage extends StatefulWidget {
  const OwnerOrdersPage({super.key});

  @override
  State<OwnerOrdersPage> createState() => _OwnerOrdersPageState();
}

class _OwnerOrdersPageState extends State<OwnerOrdersPage> with TickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final OrderItemService _orderItemService = OrderItemService();
  final ProductService _productService = ProductService();
  final UserService _userService = UserService('http://192.168.1.216:8080');
  final AttachmentService _attachmentService = AttachmentService();
  final PaginationService _paginationService = PaginationService(itemsPerPage: 10);

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = true;
  String _selectedFilter = 'Tous';
  String _searchQuery = '';
  int _currentPage = 1;
  final int currentUserId = 2;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadOwnerOrders();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOwnerOrders() async {
    try {
      setState(() => _isLoading = true);

      final allOrders = await _orderService.getAllOrders();
      final List<Map<String, dynamic>> ownerOrders = [];

      for (var order in allOrders) {
        final orderId = order['orderId'];
        if (orderId != null) {
          final orderItems = await _orderItemService.getOrderItemsByOrder(orderId);

          bool hasOwnerProduct = false;
          int ownerItemCount = 0;
          double ownerRevenue = 0.0;
          List<Map<String, dynamic>> ownerOrderItems = [];

          for (var item in orderItems) {
            final productId = item['productId'];
            if (productId != null) {
              final product = await _productService.getProductById(productId);
              if (product != null && product['userId'] == currentUserId) {
                hasOwnerProduct = true;
                ownerItemCount += (item['quantity'] ?? 0) as int;
                ownerRevenue += ((item['quantity'] ?? 0) as int) * ((product['productPrice'] ?? 0) as num).toDouble();

                // Add product details to item
                item['productDetails'] = product;
                ownerOrderItems.add(item);
              }
            }
          }

          if (hasOwnerProduct) {
            final customerId = order['userId'];
            if (customerId != null) {
              final customer = await _userService.getUserById(customerId);
              if (customer != null) {
                order['customerName'] = customer['fullName'] ?? 'Client';
                order['customerEmail'] = customer['email'] ?? '';
                order['customerPhone'] = customer['phoneNumber'] ?? '';
              }
            }

            order['orderItems'] = ownerOrderItems;
            order['ownerItemCount'] = ownerItemCount;
            order['ownerRevenue'] = ownerRevenue;
            ownerOrders.add(order);
          }
        }
      }

      ownerOrders.sort((a, b) {
        final dateA = _parseDate(a['orderDate']);
        final dateB = _parseDate(b['orderDate']);
        return (dateB?.compareTo(dateA ?? DateTime.now()) ?? 0);
      });

      setState(() {
        _orders = ownerOrders;
        _filteredOrders = ownerOrders;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackBar('Erreur de chargement: $e', isError: true);
      }
    }
  }
  void _filterAndSearch() {
    setState(() {
      _filteredOrders = _orders.where((order) {
        final statusMatch = _selectedFilter == 'Tous' ||
            _matchesStatus(order['orderStatus']);

        final searchMatch = _searchQuery.isEmpty ||
            (order['customerName'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (order['orderId'].toString()).contains(_searchQuery) ||
            (order['customerEmail'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

        return statusMatch && searchMatch;
      }).toList();
      _currentPage = 1;
    });
  }

  bool _matchesStatus(String status) {
    final upperStatus = status.toUpperCase();
    switch (_selectedFilter) {
      case 'En attente':
        return upperStatus == 'PENDING';
      case 'En préparation':
        return upperStatus == 'IN_PREPARATION';
      case 'En attente livreur':
        return upperStatus == 'WAITING';
      case 'Accepté':
        return upperStatus == 'ACCEPTED';
      case 'Récupéré':
        return upperStatus == 'PICKED_UP';
      case 'Livré':
        return upperStatus == 'DELIVERED';
      case 'Annulé':
        return upperStatus == 'CANCELED';
      default:
        return true;
    }
  }

  Future<void> _updateOrderStatus(Map<String, dynamic> order, String newStatus) async {
    try {
      final orderId = order['orderId'];
      await _orderService.patchOrderStatus(orderId, newStatus);

      if (mounted) {
        _showSnackBar('Statut mis à jour avec succès');
      }

      await _loadOwnerOrders();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur: $e', isError: true);
      }
    }
  }
  void _navigateToOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => OwnerOrderDetailsDialog(
        order: order,
        onOrderUpdated: _loadOwnerOrders,
      ),
    );
  }
  Widget _buildDeliveryInfoSection(Map<String, dynamic> order) {
    final deliveryPerson = order['deliveryPerson'] as Map<String, dynamic>? ?? {};
    final deliveryName = deliveryPerson['fullName'] ?? 'Livreur assigné';
    final deliveryPhone = deliveryPerson['phoneNumber'] ?? 'Non spécifié';
    final deliveryEmail = deliveryPerson['email'] ?? 'Non spécifié';
    final deliveryVehicle = deliveryPerson['vehicleType'] ?? 'Véhicule';
    final deliveryRating = (deliveryPerson['rating'] ?? 4.5).toDouble();
    final isDelivered = (order['orderStatus']).toString().toUpperCase() == 'DELIVERED';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.withOpacity(0.08),
            Colors.blue.withOpacity(0.04),
          ],
        ),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Informations de Livraison',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              if (isDelivered)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Livrée',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.2),
                      Colors.blue.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: const Center(
                  child: Icon(Icons.person_rounded, color: Colors.blue, size: 30),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deliveryName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: Colors.amber[600]),
                        const SizedBox(width: 4),
                        Text(
                          '$deliveryRating',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.blue.withOpacity(0.1)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildDeliveryContactItem(
                  icon: Icons.phone_rounded,
                  label: 'Téléphone',
                  value: deliveryPhone,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDeliveryContactItem(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: deliveryEmail,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDeliveryContactItem(
                  icon: Icons.two_wheeler_rounded,
                  label: 'Véhicule',
                  value: deliveryVehicle,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildDeliveryContactItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
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
          const SizedBox(height: 4),
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

  Future<void> _assignDelivery(Map<String, dynamic> order) async {
    try {
      final deliveryUsers = await _userService.getUsersByUserRole('Delivery');

      if (deliveryUsers.isEmpty) {
        _showSnackBar('Aucun livreur disponible', isError: true);
        return;
      }

      // Sort by availability and rating
      deliveryUsers.sort((a, b) {
        bool aAvailable = a['isAvailable'] ?? false;
        bool bAvailable = b['isAvailable'] ?? false;
        if (aAvailable != bAvailable) return bAvailable ? 1 : -1;
        double aRating = (a['rating'] ?? 0).toDouble();
        double bRating = (b['rating'] ?? 0).toDouble();
        return bRating.compareTo(aRating);
      });

      final selectedDelivery = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sélectionner un Livreur',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Commande #${order['orderId']}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Delivery List
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: deliveryUsers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final user = entry.value;
                          final isLast = index == deliveryUsers.length - 1;

                          return Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                            child: _buildDeliveryPersonCard(context, user, order),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (selectedDelivery != null) {
        await _updateOrderStatus(order, 'WAITING');
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

  Widget _buildDeliveryPersonCard(
      BuildContext context,
      Map<String, dynamic> user,
      Map<String, dynamic> order,
      ) {
    final fullName = user['fullName'] ?? 'Livreur';
    final email = user['email'] ?? 'Email non disponible';
    final phone = user['phoneNumber'] ?? 'Non spécifié';
    final isAvailable = user['isAvailable'] ?? false;
    final rating = (user['rating'] ?? 4.5).toDouble();
    final completedOrders = user['completedOrders'] ?? 0;
    final vehicleType = user['vehicleType'] ?? 'Véhicule';

    return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context, user),
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withOpacity(0.1),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAvailable ? Colors.green.withOpacity(0.2) : Colors.grey[200]!,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isAvailable
                      ? AppColors.primary.withOpacity(0.08)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Main Row
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withOpacity(0.3),
                            AppColors.primary.withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isAvailable)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Disponible',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.star_rounded, size: 16, color: Colors.amber[600]),
                              const SizedBox(width: 4),
                              Text(
                                '$rating',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$completedOrders livraisons',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
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

                const SizedBox(height: 14),

                // Divider
                Container(height: 1, color: Colors.grey[200]),

                const SizedBox(height: 12),

                // Contact Details
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

              ],
            ),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
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
          const SizedBox(height: 4),
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

  Color _getStatusColor(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'PENDING') return Colors.blue;
    if (upperStatus == 'IN_PREPARATION') return Colors.orange;
    if (upperStatus == 'WAITING') return Colors.purple;
    if (upperStatus == 'ACCEPTED') return Colors.teal;
    if (upperStatus == 'PICKED_UP') return Colors.indigo;
    if (upperStatus == 'DELIVERED') return Colors.green;
    if (upperStatus == 'CANCELED') return Colors.red;
    return Colors.grey;
  }

  IconData _getStatusIcon(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'PENDING') return Icons.schedule_rounded;
    if (upperStatus == 'IN_PREPARATION') return Icons.restaurant_rounded;
    if (upperStatus == 'WAITING') return Icons.person_rounded;
    if (upperStatus == 'ACCEPTED') return Icons.check_circle_rounded;
    if (upperStatus == 'PICKED_UP') return Icons.local_shipping_rounded;
    if (upperStatus == 'DELIVERED') return Icons.done_all_rounded;
    if (upperStatus == 'CANCELED') return Icons.cancel_rounded;
    return Icons.help_rounded;
  }

  String _getDisplayStatus(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'PENDING') return 'En attente';
    if (upperStatus == 'IN_PREPARATION') return 'En préparation';
    if (upperStatus == 'WAITING') return 'En attente livreur';
    if (upperStatus == 'ACCEPTED') return 'Accepté';
    if (upperStatus == 'PICKED_UP') return 'Récupéré';
    if (upperStatus == 'DELIVERED') return 'Livré';
    if (upperStatus == 'CANCELED') return 'Annulé';
    return status;
  }

  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;

    // If it's already a DateTime
    if (dateValue is DateTime) return dateValue;

    // If it's a list [year, month, day, hour, minute, second]
    if (dateValue is List && dateValue.isNotEmpty) {
      try {
        final year = (dateValue[0] as num).toInt();
        final month = dateValue.length > 1 ? (dateValue[1] as num).toInt() : 1;
        final day = dateValue.length > 2 ? (dateValue[2] as num).toInt() : 1;
        final hour = dateValue.length > 3 ? (dateValue[3] as num).toInt() : 0;
        final minute = dateValue.length > 4 ? (dateValue[4] as num).toInt() : 0;
        final second = dateValue.length > 5 ? (dateValue[5] as num).toInt() : 0;
        return DateTime(year, month, day, hour, minute, second);
      } catch (e) {
        debugPrint('Error parsing date from list: $e');
      }
    }

    // If it's a string
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        debugPrint('Error parsing date from string: $e');
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? _buildLoadingState()
          : FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeader(isMobile),
            _buildSearchAndFilter(),
            Expanded(
              child: _filteredOrders.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        Expanded(child: _buildOrdersList(isMobile)),
                        if (_filteredOrders.isNotEmpty) _buildPaginationBar(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement des commandes...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildHeader(bool isMobile) {
    final totalOrders = _orders.length;
    final totalRevenue = _orders.fold<double>(
      0,
          (sum, order) => sum + ((order['ownerRevenue'] ?? 0.0) as num).toDouble(),
    );
    final pendingCount = _orders
        .where((o) => (o['orderStatus']).toString().toUpperCase() == 'PENDING')
        .length;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.shopping_cart_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gestion des Commandes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Suivez et gérez vos ventes',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
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
              IconButton(
                onPressed: _loadOwnerOrders,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 26),
                tooltip: 'Actualiser',
                padding: const EdgeInsets.all(8),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Commandes',
                  '$totalOrders',
                  Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'En Attente',
                  '$pendingCount',
                  Icons.pending_actions_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Revenus',
                  '${totalRevenue.toStringAsFixed(0)} DT',
                  Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final filters = ['Tous', 'En attente', 'En préparation', 'En attente livreur', 'Accepté', 'Récupéré', 'Livré', 'Annulé'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _searchQuery = value;
                _filterAndSearch();
              },
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, #commande ou email...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    _searchQuery = '';
                    _filterAndSearch();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                    _filterAndSearch();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: !isSelected ? Border.all(color: Colors.grey[300]!) : null,
                    ),
                    child: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune commande trouvée',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'Aucun résultat pour votre recherche'
                : 'Les commandes de vos produits apparaîtront ici',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(bool isMobile) {
    final paginatedOrders = _paginationService.getPageItems(_filteredOrders, _currentPage);
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: paginatedOrders.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildOrderCard(paginatedOrders[index], isMobile),
        );
      },
    );
  }

  Widget _buildPaginationBar() {
    final totalPages = _paginationService.getTotalPages(_filteredOrders.length);
    final startItem = (_currentPage - 1) * 10 + 1;
    final endItem = (startItem + 9 > _filteredOrders.length) ? _filteredOrders.length : startItem + 9;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage $startItem-$endItem sur ${_filteredOrders.length}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Page précédente',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_currentPage / $totalPages',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Page suivante',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isMobile) {
    final orderId = order['orderId'] ?? 0;
    final status = order['orderStatus'] ?? order['status'] ?? 'Pending';
    final customerName = order['customerName'] ?? 'Client';
    final totalAmount = (order['ownerRevenue'] ?? 0.0).toDouble();
    final quantity = order['ownerItemCount'] ?? 0;
    final statusColor = _getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToOrderDetails(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isMobile
              ? _buildMobileOrderCard(order, statusColor, orderId, customerName, totalAmount, quantity, status)
              : _buildDesktopOrderCard(order, statusColor, orderId, customerName, totalAmount, quantity, status),
        ),
      ),
    );
  }

  Widget _buildMobileOrderCard(Map<String, dynamic> order, Color statusColor, int orderId,
      String customerName, double totalAmount, int quantity, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getStatusIcon(status), color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commande #$orderId',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    customerName,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            _buildStatusChip(status),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Montant', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  '${totalAmount.toStringAsFixed(2)} DT',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Articles', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  '$quantity',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionButtons(order),
      ],
    );
  }

  Widget _buildDesktopOrderCard(Map<String, dynamic> order, Color statusColor, int orderId,
      String customerName, double totalAmount, int quantity, String status) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getStatusIcon(status), color: statusColor, size: 24),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commande #$orderId',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                customerName,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$quantity articles',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${totalAmount.toStringAsFixed(2)} DT',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text(
              'Montant',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(width: 24),
        _buildStatusChip(status),
        const SizedBox(width: 20),
        _buildStatusTransitionButton(order),
      ],
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> order) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => _navigateToOrderDetails(order),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Détails'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusTransitionButton(order),
        ),
      ],
    );
  }

  Widget _buildStatusTransitionButton(Map<String, dynamic> order) {
    final status = (order['orderStatus'] ?? order['status'] ?? 'PENDING').toString().toUpperCase();

    if (status == 'PENDING') {
      return ElevatedButton(
        onPressed: () => _updateOrderStatus(order, 'IN_PREPARATION'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Préparer', style: TextStyle(color: Colors.white, fontSize: 12)),
      );
    } else if (status == 'IN_PREPARATION') {
      return ElevatedButton(
        onPressed: () => _updateOrderStatus(order, 'WAITING'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Prêt', style: TextStyle(color: Colors.white, fontSize: 12)),
      );
    } else if (status == 'WAITING') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.purple[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'En attente',
          style: TextStyle(color: Colors.purple[700], fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    } else if (status == 'ACCEPTED') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.teal[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Accepté',
          style: TextStyle(color: Colors.teal[700], fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    } else if (status == 'PICKED_UP') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.indigo[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'En livraison',
          style: TextStyle(color: Colors.indigo[700], fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    } else if (status == 'DELIVERED') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Livré',
          style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    } else if (status == 'CANCELED') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Annulé',
          style: TextStyle(color: Colors.red[700], fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }

    return const SizedBox.shrink();
  }
  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _getDisplayStatus(status),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


}