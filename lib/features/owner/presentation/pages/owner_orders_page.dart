import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../Core/services/attachment_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../Core/services/order_service.dart';
import '../../../../Core/services/order_item_service.dart';
import '../../../../Core/services/product_service.dart';
import '../../../../Core/services/user_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/company_service.dart';
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
  final UserService _userService = UserService();
  final AttachmentService _attachmentService = AttachmentService();
  final AuthService _authService = AuthService();
  final CompanyService _companyService = CompanyService();
  final PaginationService _paginationService = PaginationService(itemsPerPage: 10);

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = true;
  String _selectedFilter = 'Tous';
  String _selectedCompany = 'Toutes';
  String _searchQuery = '';
  int _currentPage = 1;
  int? _currentUserId;
  List<String> _companies = ['Toutes'];
  Map<String, int> _companyMap = {};
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
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await _authService.getUserId();
    setState(() {
      _currentUserId = userId;
    });
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

      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Load owner companies first
      await _loadOwnerCompanies();

      List<Map<String, dynamic>> allOrders = [];
      
      // If company filter is selected and not 'Toutes', get orders for specific company
      if (_selectedCompany != 'Toutes' && _companyMap.containsKey(_selectedCompany)) {
        final companyId = _companyMap[_selectedCompany]!;
        allOrders = await _orderService.getOrdersByCompanyId(companyId);
      } else {
        // Get all orders for the owner's companies
        allOrders = await _orderService.getOrdersByCompanyUserId(_currentUserId!);
      }

      // Get all unique user IDs for batch fetching
      final Set<int> userIds = {};
      for (var order in allOrders) {
        final userId = order['userId'];
        if (userId != null) userIds.add(userId);
      }

      // Fetch all users in parallel
      final Map<int, Map<String, dynamic>> usersMap = {};
      if (userIds.isNotEmpty) {
        final userFutures = userIds.map((id) => _userService.getUserById(id));
        final users = await Future.wait(userFutures);
        for (int i = 0; i < userIds.length; i++) {
          final userId = userIds.elementAt(i);
          if (users[i] != null) usersMap[userId] = users[i]!;
        }
      }

      // Get all order items in parallel
      final List<Future<List<dynamic>>> orderItemsFutures = [];
      final List<int> orderIds = [];

      for (var order in allOrders) {
        final orderId = order['orderId'];
        if (orderId != null) {
          orderIds.add(orderId);
          orderItemsFutures.add(_orderItemService.getOrderItemsByOrder(orderId));
        }
      }

      final List<List<dynamic>> allOrderItemsList = await Future.wait(orderItemsFutures);
      final Map<int, List<dynamic>> orderItemsMap = {};

      for (int i = 0; i < orderIds.length; i++) {
        orderItemsMap[orderIds[i]] = allOrderItemsList[i];
      }

      // Get all unique product IDs
      final Set<int> productIds = {};
      for (var orderItems in allOrderItemsList) {
        for (var item in orderItems) {
          final productId = item['productId'];
          if (productId != null) productIds.add(productId);
        }
      }

      // Fetch all products in parallel
      final Map<int, Map<String, dynamic>> productsMap = {};
      if (productIds.isNotEmpty) {
        final productFutures = productIds.map((id) => _productService.getProductById(id));
        final products = await Future.wait(productFutures);
        for (int i = 0; i < productIds.length; i++) {
          final productId = productIds.elementAt(i);
          if (products[i] != null) productsMap[productId] = products[i]!;
        }
      }

      // Process orders
      final List<Map<String, dynamic>> ownerOrders = [];

      for (var order in allOrders) {
        final customerId = order['userId'];
        if (customerId != null) {
          final customer = usersMap[customerId];
          if (customer != null) {
            order['customerName'] = customer['fullName'] ?? 'Client';
            order['customerEmail'] = customer['email'] ?? '';
            order['customerPhone'] = customer['phoneNumber'] ?? '';
          }
        }

        try {
          if (order['company'] != null && order['company']['companyName'] != null) {
            final companyName = order['company']['companyName'].toString();
            order['companyName'] = companyName;
          }
        } catch (e) {
          debugPrint('Error processing company: $e');
          order['companyName'] = 'Entreprise inconnue';
        }

        final orderId = order['orderId'];
        if (orderId != null) {
          final orderItems = orderItemsMap[orderId] ?? [];
          for (var item in orderItems) {
            final productId = item['productId'];
            if (productId != null && productsMap[productId] != null) {
              item['productDetails'] = productsMap[productId];
            }
          }
          order['orderItems'] = orderItems;
        }

        order['ownerRevenue'] = order['totalAmount'] ?? 0.0;
        order['ownerItemCount'] = order['quantity'] ?? 0;
        ownerOrders.add(order);
      }

      // Sort by date
      ownerOrders.sort((a, b) {
        final dateA = _parseDate(a['orderDate']);
        final dateB = _parseDate(b['orderDate']);
        return (dateB?.compareTo(dateA ?? DateTime.now()) ?? 0);
      });

      setState(() {
        _orders = ownerOrders;
        _filteredOrders = ownerOrders;
        _isLoading = false;
        debugPrint('Loaded ${ownerOrders.length} orders');
      });
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackBar('Erreur de chargement: $e', isError: true);
      }
      debugPrint('Error loading orders: $e');
    }
  }

  Future<void> _loadOwnerCompanies() async {
    try {
      if (_currentUserId == null) return;
      
      // Get companies owned by the current user
      final companies = await _companyService.getCompanyByUserID(_currentUserId!);
      
      _companyMap = {for (var comp in companies)
        if (comp['companyName'] != null) comp['companyName'] as String: comp['companyId'] as int};

      _companies = ['Toutes', ...companies
          .where((c) => c['companyName'] != null)
          .map((c) => c['companyName'] as String)];
          
      debugPrint('Loaded ${companies.length} owner companies');
    } catch (e) {
      debugPrint('Error loading owner companies: $e');
      _companies = ['Toutes'];
      _companyMap = {};
    }
  }

  void _filterAndSearch() {
    setState(() {
      _filteredOrders = _orders.where((order) {
        final statusMatch = _selectedFilter == 'Tous' || _matchesStatus(order['orderStatus']);

        final companyMatch = _selectedCompany == 'Toutes' ||
            (order['companyName'] ?? '').toLowerCase() == _selectedCompany.toLowerCase();

        final searchMatch = _searchQuery.isEmpty ||
            (order['customerName'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (order['orderId'].toString()).contains(_searchQuery) ||
            (order['customerEmail'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (order['companyName'] ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

        return statusMatch && companyMatch && searchMatch;
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
      case 'En livraison':
        return upperStatus == 'PICKED_UP';
      case 'Livré':
        return upperStatus == 'DELIVERED';
      case 'Refusé':
        return upperStatus == 'REJECTED';
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

  Future<void> _assignDelivery(Map<String, dynamic> order) async {
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
        builder: (context) => _buildDeliverySelectionDialog(availableDeliverers, order),
      );

      if (selectedDelivery != null) {
        final deliveryId = selectedDelivery['userId'];
        final orderId = order['orderId'];

        await _orderService.patchOrderStatus(orderId, 'WAITING');
        await _orderService.updateOrder(orderId, {
          'deliveryId': deliveryId,
          'assignedById': _currentUserId,
        });
        await _loadOwnerOrders();

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

  Widget _buildDeliverySelectionDialog(
      List<Map<String, dynamic>> deliveryUsers,
      Map<String, dynamic> order) {
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
                              'Commande #${order['orderId']} • ${deliveryUsers.length} livreurs disponibles',
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
                  return _buildDeliveryPersonCard(context, user, order, isMobile);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryPersonCard(
      BuildContext context,
      Map<String, dynamic> user,
      Map<String, dynamic> order,
      bool isMobile) {
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
    if (upperStatus == 'PENDING') return const Color(0xFFF59E0B);
    if (upperStatus == 'IN_PREPARATION') return const Color(0xFF3B82F6);
    if (upperStatus == 'WAITING') return const Color(0xFF8B5CF6);
    if (upperStatus == 'ACCEPTED') return const Color(0xFF10B981);
    if (upperStatus == 'PICKED_UP') return const Color(0xFF06B6D4);
    if (upperStatus == 'DELIVERED') return const Color(0xFF10B981);
    if (upperStatus == 'REJECTED') return const Color(0xFFF97316);
    if (upperStatus == 'CANCELED') return const Color(0xFFEF4444);
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
    if (upperStatus == 'REJECTED') return Icons.cancel_outlined;
    if (upperStatus == 'CANCELED') return Icons.cancel_rounded;
    return Icons.help_rounded;
  }

  String _getDisplayStatus(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'PENDING') return 'En attente';
    if (upperStatus == 'IN_PREPARATION') return 'En préparation';
    if (upperStatus == 'WAITING') return 'En attente livreur';
    if (upperStatus == 'ACCEPTED') return 'Accepté';
    if (upperStatus == 'PICKED_UP') return 'En livraison';
    if (upperStatus == 'DELIVERED') return 'Livré';
    if (upperStatus == 'REJECTED') return 'Refusé';
    if (upperStatus == 'CANCELED') return 'Annulé';
    return status;
  }

  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is DateTime) return dateValue;
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
            _buildSearchAndFilter(isMobile),
            Expanded(
              child: _filteredOrders.isEmpty
                  ? _buildEmptyState()
                  : Column(
                children: [
                  Expanded(child: _buildOrdersList(isMobile)),
                  if (_filteredOrders.isNotEmpty) _buildPaginationBar(isMobile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Column(
      children: [
        _buildHeader(isMobile),
        _buildSearchAndFilter(isMobile),
        Expanded(
          child: Skeletonizer(
            enabled: true,
            child: ListView.builder(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              itemCount: 6,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSkeletonOrderCard(isMobile),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonOrderCard(bool isMobile) {
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
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 16),
        child: isMobile
            ? _buildMobileSkeletonCard()
            : _buildDesktopSkeletonCard(),
      ),
    );
  }

  Widget _buildMobileSkeletonCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 80,
                    height: 12,
                    color: Colors.grey[300],
                  ),
                ],
              ),
            ),
            Container(
              width: 60,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 12,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 4),
                Container(
                  width: 70,
                  height: 16,
                  color: Colors.grey[300],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 50,
                  height: 12,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 4),
                Container(
                  width: 30,
                  height: 16,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopSkeletonCard() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 140,
                height: 16,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 4),
              Container(
                width: 100,
                height: 14,
                color: Colors.grey[300],
              ),
            ],
          ),
        ),
        Container(
          width: 80,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 80,
              height: 16,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 4),
            Container(
              width: 50,
              height: 12,
              color: Colors.grey[300],
            ),
          ],
        ),
        const SizedBox(width: 24),
        Container(
          width: 70,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 20),
        Container(
          width: 100,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isMobile) {
    final totalOrders = _orders.length;
    final totalRevenue = _orders.fold<double>(
      0,
          (sum, order) => sum + ((order['ownerRevenue'] ?? 0.0) as num).toDouble(),
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
        ),
      ),
      child: Row(
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
                      child: Icon(
                        Icons.shopping_cart_rounded,
                        color: Colors.white,
                        size: isMobile ? 24 : 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gestion des Commandes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Suivez et gérez vos ventes',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: isMobile ? 12 : 13,
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
    );
  }

  Widget _buildSearchAndFilter(bool isMobile) {
    final filters = ['Tous', 'En attente', 'En préparation', 'En attente livreur', 'Accepté', 'En livraison', 'Livré', 'Refusé', 'Annulé'];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
          SizedBox(height: isMobile ? 12 : 16),
          Column(
            children: [
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
              if (_companies.length > 2) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _companies.map((company) {
                      final isSelected = _selectedCompany == company;
                      return GestureDetector(
                        onTap: () async {
                          setState(() => _selectedCompany = company);
                          await _loadOwnerOrders();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.success : Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.success : Colors.grey[300]!,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.business,
                                size: 14,
                                color: isSelected ? Colors.white : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                company,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey[700],
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
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
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: paginatedOrders.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildOrderCard(paginatedOrders[index], isMobile),
        );
      },
    );
  }

  Widget _buildPaginationBar(bool isMobile) {
    final totalPages = _paginationService.getTotalPages(_filteredOrders.length);
    final startItem = (_currentPage - 1) * 10 + 1;
    final endItem = (startItem + 9 > _filteredOrders.length) ? _filteredOrders.length : startItem + 9;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 16,
        vertical: isMobile ? 10 : 12,
      ),
      margin: EdgeInsets.all(isMobile ? 12 : 16),
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
          Expanded(
            child: Text(
              'Affichage $startItem-$endItem sur ${_filteredOrders.length}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isMobile ? 11 : 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: isMobile ? 36 : 40,
            height: isMobile ? 36 : 40,
            child: IconButton(
              onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Page précédente',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: isMobile ? 20 : 24,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 12,
              vertical: isMobile ? 5 : 6,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$_currentPage/$totalPages',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: isMobile ? 12 : 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: isMobile ? 36 : 40,
            height: isMobile ? 36 : 40,
            child: IconButton(
              onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Page suivante',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              iconSize: isMobile ? 20 : 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isMobile) {
    final orderId = order['orderId'] ?? 0;
    final status = order['orderStatus'] ?? 'PENDING';
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
          padding: EdgeInsets.all(isMobile ? 14 : 16),
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
                  if (order['companyName'] != null)
                    Text(
                      order['companyName'],
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
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
              if (order['companyName'] != null)
                Text(
                  order['companyName'],
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
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
    final status = (order['orderStatus'] ?? 'PENDING').toString().toUpperCase();

    if (status == 'PENDING') {
      return ElevatedButton(
        onPressed: () => _updateOrderStatus(order, 'IN_PREPARATION'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Accepter', style: TextStyle(color: Colors.white, fontSize: 12)),
      );
    }
    else if (status == 'IN_PREPARATION') {
      return ElevatedButton(
        onPressed: () => _assignDelivery(order),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Assigner Livreur', style: TextStyle(color: Colors.white, fontSize: 12)),
      );
    }
    else if (status == 'WAITING') {
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
    }
    else if (status == 'ACCEPTED') {
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
    }
    else if (status == 'PICKED_UP') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.cyan[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'En livraison',
          style: TextStyle(color: Colors.cyan[700], fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
    else if (status == 'DELIVERED') {
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
    }
    else if (status == 'REJECTED') {
      return ElevatedButton(
        onPressed: () => _assignDelivery(order),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: const Text('Réassigner', style: TextStyle(color: Colors.white, fontSize: 12)),
      );
    }
    else if (status == 'CANCELED') {
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