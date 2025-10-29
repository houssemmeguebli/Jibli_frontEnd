import 'package:flutter/material.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/order_service.dart';
import '../widgets/order_card.dart';
import 'customer_order_details_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderService _orderService = OrderService();
  final PaginationService _paginationService = PaginationService(itemsPerPage: 10);

  List<Map<String, dynamic>> _currentOrders = [];
  List<Map<String, dynamic>> _orderHistory = [];
  bool _isLoading = true;
  int _currentOrdersPage = 1;
  int _historyPage = 1;
  final int _currentUserId = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() => _isLoading = true);

      final response = await _orderService.getOrdersByUserId(_currentUserId);
      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(response);

      setState(() {
        // Current orders: PENDING, IN_PREPARATION, WAITING, ACCEPTED, PICKED_UP
        _currentOrders = orders.where((order) {
          final status = (order['orderStatus'] ?? '').toString().toUpperCase();
          return !['DELIVERED', 'CANCELED'].contains(status);
        }).toList();

        // History: DELIVERED, CANCELED
        _orderHistory = orders.where((order) {
          final status = (order['orderStatus'] ?? '').toString().toUpperCase();
          return ['DELIVERED', 'CANCELED'].contains(status);
        }).toList();

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _navigateToOrderDetails(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsPage(order: order),
      ),
    ).then((_) {
      // Refresh orders when returning from details page
      _loadOrders();
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mes Commandes',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        toolbarHeight: 60,
        titleSpacing: 20,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20, top: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 24),
              onPressed: _loadOrders,
              tooltip: 'Rafraîchir',
              splashRadius: 24,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          tabs: [
            Tab(
              text: 'En cours (${_currentOrders.length})',
              icon: const Icon(Icons.local_shipping_rounded, size: 18),
              iconMargin: const EdgeInsets.only(bottom: 4),
            ),
            Tab(
              text: 'Historique (${_orderHistory.length})',
              icon: const Icon(Icons.history_rounded, size: 18),
              iconMargin: const EdgeInsets.only(bottom: 4),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCurrentOrders(),
                _buildOrderHistory(),
              ],
            ),
    );
  }

  Widget _buildCurrentOrders() {
    if (_currentOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Aucune commande en cours',
        subtitle: 'Explorez nos produits et passez votre première commande',
        primaryAction: true,
      );
    }

    final paginatedOrders = _paginationService.getPageItems(_currentOrders, _currentOrdersPage);

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.primary,
      strokeWidth: 3,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: paginatedOrders.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () => _navigateToOrderDetails(paginatedOrders[index]),
                    child: OrderCard(order: paginatedOrders[index]),
                  ),
                );
              },
            ),
          ),
          if (_currentOrders.length > 10) _buildPaginationBar(_currentOrders.length, _currentOrdersPage, (page) {
            if (mounted) setState(() => _currentOrdersPage = page);
          }),
        ],
      ),
    );
  }

  Widget _buildOrderHistory() {
    if (_orderHistory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'Aucun historique',
        subtitle: 'Vos commandes passées apparaîtront ici',
        primaryAction: false,
      );
    }

    final paginatedHistory = _paginationService.getPageItems(_orderHistory, _historyPage);

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.primary,
      strokeWidth: 3,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: paginatedHistory.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => _navigateToOrderDetails(paginatedHistory[index]),
                    child: OrderCard(order: paginatedHistory[index]),
                  ),
                );
              },
            ),
          ),
          if (_orderHistory.length > 10) _buildPaginationBar(_orderHistory.length, _historyPage, (page) {
            if (mounted) setState(() => _historyPage = page);
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool primaryAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.primary.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                icon,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (primaryAction) ...[
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Continuer les achats'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar(int totalItems, int currentPage, Function(int) onPageChanged) {
    final totalPages = _paginationService.getTotalPages(totalItems);
    final startItem = (currentPage - 1) * 10 + 1;
    final endItem = (startItem + 9 > totalItems) ? totalItems : startItem + 9;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage $startItem-$endItem sur $totalItems',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: currentPage > 1
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$currentPage / $totalPages',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: currentPage < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}