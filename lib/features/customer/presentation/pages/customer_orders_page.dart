import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/order_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/auth_service.dart';
import '../widgets/order_card.dart';
import 'customer_order_details_page.dart';
import 'dart:typed_data';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final OrderService _orderService = OrderService();
  final PaginationService _paginationService = PaginationService(itemsPerPage: 10);
  final AttachmentService _attachmentService = AttachmentService();
  final ProductService _productService = ProductService();

  List<Map<String, dynamic>> _currentOrders = [];
  List<Map<String, dynamic>> _orderHistory = [];
  Map<int, Uint8List?> _productImages = {};
  bool _isLoading = true;
  int _currentOrdersPage = 1;
  int _historyPage = 1;
  int? _currentUserId;

  // Filter and search variables
  String _searchQuery = '';
  String _selectedStatusFilter = 'TOUS';

  final Map<String, List<String>> statusOptionsMap = {
    'TOUS': [],
    'EN ATTENTE': ['PENDING'],
    'EN TRAITEMENT': ['IN_PREPARATION', 'WAITING', 'ACCEPTED', 'REJECTED', 'PROCESSING'],
    'EN ROUTE': ['PICKED_UP', 'SHIPPED'],
    'LIVRÉ': ['DELIVERED'],
    'ANNULÉ': ['CANCELED'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _loadOrders();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _loadOrders() async {
    // Initialize skeleton data
    setState(() {
      _isLoading = true;
      _currentOrders = List.generate(3, (index) => {
        'orderId': index + 1,
        'orderStatus': 'PENDING',
        'totalAmount': 45.99,
        'createdAt': [2024, 1, 15, 10, 30],
        'orderItems': [{
          'productId': index,
          'quantity': 2,
          'productName': 'Produit skeleton',
        }],
      });
      _orderHistory = List.generate(2, (index) => {
        'orderId': index + 10,
        'orderStatus': 'DELIVERED',
        'totalAmount': 32.50,
        'createdAt': [2024, 1, 10, 14, 20],
        'orderItems': [{
          'productId': index + 10,
          'quantity': 1,
          'productName': 'Produit skeleton historique',
        }],
      });
    });

    try {
      // Get current user ID from AuthService
      final authService = AuthService();
      _currentUserId = await authService.getUserId();
      
      if (_currentUserId == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      final response = await _orderService.getOrdersByUserId(_currentUserId!);
      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(response);

      setState(() {
        _currentOrders = orders.where((order) {
          final status = (order['orderStatus'] ?? '').toString().toUpperCase();
          return !['DELIVERED', 'CANCELED'].contains(status);
        }).toList();

        _orderHistory = orders.where((order) {
          final status = (order['orderStatus'] ?? '').toString().toUpperCase();
          return ['DELIVERED', 'CANCELED'].contains(status);
        }).toList();

        _isLoading = false;
      });

      await Future.wait([
        _loadOrderImages(_currentOrders),
        _loadOrderImages(_orderHistory),
      ]);

      _fadeController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Erreur: $e')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _loadOrderImages(List<Map<String, dynamic>> orders) async {
    try {
      final Map<int, Uint8List?> images = {};

      for (var order in orders) {
        final orderItems = order['orderItems'] as List<dynamic>? ?? [];
        for (var item in orderItems) {
          final productId = item['productId'] as int?;
          if (productId != null && !_productImages.containsKey(productId)) {
            try {
              final attachments = await _attachmentService.findByProductProductId(productId);
              if (attachments.isNotEmpty) {
                final firstAttachment = attachments.first as Map<String, dynamic>;
                final attachmentId = firstAttachment['attachmentId'] as int?;
                if (attachmentId != null) {
                  final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
                  if (attachmentDownload.data.isNotEmpty) {
                    images[productId] = attachmentDownload.data;
                  }
                }
              }
            } catch (e) {
              debugPrint('⚠️ Error loading image for product $productId: $e');
              images[productId] = null;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _productImages.addAll(images);
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading order images: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredAndSearchedOrders(List<Map<String, dynamic>> orders) {
    return orders.where((order) {
      // Status filter
      final orderStatus = _safeString(order['orderStatus']).toUpperCase();
      final selectedStatuses = statusOptionsMap[_selectedStatusFilter] ?? [];
      final statusMatches = selectedStatuses.isEmpty || selectedStatuses.contains(orderStatus);

      // Search filter
      final orderId = _safeString(order['orderId']);
      final totalAmount = _safeString(order['totalAmount']);
      final searchMatches = _searchQuery.isEmpty ||
          orderId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          totalAmount.contains(_searchQuery);

      return statusMatches && searchMatches;
    }).toList();
  }

  String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is List) return value.join(', ');
    return value.toString();
  }

  void _navigateToOrderDetails(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsPage(order: order),
      ),
    ).then((_) {
      _loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildModernAppBar(),
      body: Skeletonizer(
        enabled: _isLoading,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildSearchAndFilterBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCurrentOrders(),
                    _buildOrderHistory(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      title: const Text(
        'Mes Commandes',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 24,
          letterSpacing: -0.5,
        ),
      ),
      backgroundColor: AppColors.primary,
      elevation: 0,
      toolbarHeight: 70,
      titleSpacing: 20,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.6),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            tabs: [
              Tab(
                text: 'En cours (${_currentOrders.length})',
                icon: const Icon(Icons.local_shipping_rounded, size: 20),
                iconMargin: const EdgeInsets.only(bottom: 6),
              ),
              Tab(
                text: 'Historique (${_orderHistory.length})',
                icon: const Icon(Icons.history_rounded, size: 20),
                iconMargin: const EdgeInsets.only(bottom: 6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            decoration: InputDecoration(
              hintText: 'Rechercher par ID ou montant...',
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? GestureDetector(
                onTap: () => setState(() => _searchQuery = ''),
                child: const Icon(Icons.clear_rounded, color: Colors.grey),
              )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintStyle: TextStyle(color: Colors.grey[500]),
            ),
          ),
          const SizedBox(height: 12),
          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...statusOptionsMap.keys.map((label) {
                  final isSelected = _selectedStatusFilter == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedStatusFilter = label);
                      },
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.primary,
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : Colors.grey[300]!,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildCurrentOrders() {
    final filteredOrders = _getFilteredAndSearchedOrders(_currentOrders);

    if (filteredOrders.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_outlined,
        title: _currentOrders.isEmpty ? 'Aucune commande en cours' : 'Aucun résultat',
        subtitle: _currentOrders.isEmpty
            ? 'Passez votre première commande'
            : 'Aucune commande ne correspond à vos filtres',
        primaryAction: _currentOrders.isEmpty,
      );
    }

    final paginatedOrders = _paginationService.getPageItems(filteredOrders, _currentOrdersPage);

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.primary,
      strokeWidth: 3,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: paginatedOrders.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: _isLoading ? null : () => _navigateToOrderDetails(paginatedOrders[index]),
                    child: OrderCard(
                      order: paginatedOrders[index],
                      productImages: _productImages,
                    ),
                  ),
                );
              },
            ),
          ),
          if (filteredOrders.length > 10)
            _buildPaginationBar(
              filteredOrders.length,
              _currentOrdersPage,
                  (page) {
                if (mounted) setState(() => _currentOrdersPage = page);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOrderHistory() {
    final filteredHistory = _getFilteredAndSearchedOrders(_orderHistory);

    if (filteredHistory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: _orderHistory.isEmpty ? 'Aucun historique' : 'Aucun résultat',
        subtitle: _orderHistory.isEmpty
            ? 'Vos commandes passées apparaîtront ici'
            : 'Aucune commande ne correspond à vos filtres',
        primaryAction: false,
      );
    }

    final paginatedHistory = _paginationService.getPageItems(filteredHistory, _historyPage);

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: AppColors.primary,
      strokeWidth: 3,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: paginatedHistory.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: _isLoading ? null : () => _navigateToOrderDetails(paginatedHistory[index]),
                    child: OrderCard(
                      order: paginatedHistory[index],
                      productImages: _productImages,
                    ),
                  ),
                );
              },
            ),
          ),
          if (filteredHistory.length > 10)
            _buildPaginationBar(
              filteredHistory.length,
              _historyPage,
                  (page) {
                if (mounted) setState(() => _historyPage = page);
              },
            ),
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
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    AppColors.primary.withOpacity(0.08),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (primaryAction) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.shopping_bag_outlined, size: 22),
                label: const Text('Continuer les achats'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primary.withOpacity(0.4),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$startItem-$endItem sur $totalItems',
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: currentPage > 1
                      ? () => onPageChanged(currentPage - 1)
                      : null,
                  icon: Icon(
                    Icons.chevron_left,
                    color: currentPage > 1 ? AppColors.primary : Colors.grey[300],
                  ),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '$currentPage / $totalPages',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  onPressed: currentPage < totalPages
                      ? () => onPageChanged(currentPage + 1)
                      : null,
                  icon: Icon(
                    Icons.chevron_right,
                    color: currentPage < totalPages ? AppColors.primary : Colors.grey[300],
                  ),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
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
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadOrders();
    }
  }
}