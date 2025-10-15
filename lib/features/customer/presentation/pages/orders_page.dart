import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/order_service.dart';
import '../widgets/order_card.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderService _orderService = OrderService();

  List<Map<String, dynamic>> _currentOrders = [];
  List<Map<String, dynamic>> _orderHistory = [];
  bool _isLoading = true;
  final int _currentUserId = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final response = await _orderService.getOrdersByUserId(_currentUserId);
      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(response);

      setState(() {
        _currentOrders = orders.where((order) =>
          !['delivered', 'cancelled', 'livré', 'annulé'].contains((order['orderStatus'] ?? '').toString().toLowerCase())
        ).toList();
        _orderHistory = orders.where((order) =>
          ['delivered', 'cancelled', 'livré', 'annulé'].contains((order['orderStatus'] ?? '').toString().toLowerCase())
        ).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text(
                'Mes Commandes',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: AppColors.primary,
              pinned: true,
              floating: true,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loadOrders,
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: AppColors.primary,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.textLight,
                    indicatorWeight: 3,
                    labelColor: AppColors.textLight,
                    unselectedLabelColor: AppColors.textLight.withOpacity(0.7),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                    tabs: [
                      Tab(text: 'En cours (${_currentOrders.length})'),
                      Tab(text: 'Historique (${_orderHistory.length})'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildCurrentOrders(),
                  _buildOrderHistory(),
                ],
              ),
      ),
    );
  }

  Widget _buildCurrentOrders() {
    if (_currentOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Aucune commande en cours',
        subtitle: 'Vos commandes actives apparaîtront ici',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _currentOrders.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OrderCard(order: _currentOrders[index]),
          );
        },
      ),
    );
  }

  Widget _buildOrderHistory() {
    if (_orderHistory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'Aucun historique',
        subtitle: 'Vos commandes passées apparaîtront ici',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _orderHistory.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OrderCard(order: _orderHistory[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Navigate to home page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textLight,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Commencer à commander'),
            ),
          ],
        ),
      ),
    );
  }
}