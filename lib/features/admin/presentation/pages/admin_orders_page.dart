import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/services/order_service.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../owner/presentation/pages/owner_order_details_page.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final OrderService _orderService = OrderService();
  final CompanyService _companyService = CompanyService();
  final UserService _userService = UserService('http://192.168.1.216:8080');
  final PaginationService _paginationService = PaginationService();
  PaginationState _paginationState = PaginationState(currentPage: 1, totalItems: 0, itemsPerPage: 12);

  String _searchQuery = '';
  String _selectedStatus = 'Tous';
  String _selectedCompany = 'Toutes';
  double _minTotal = 0;
  double _maxTotal = 1000;
  String _sortBy = 'date';
  bool _sortAscending = false;
  bool _isLoading = true;

  List<String> _statuses = ['Tous', 'PENDING', 'IN_PREPARATION', 'WAITING', 'ACCEPTED','PICKED_UP','DELIVERED', 'CANCELED'];
  List<String> _companies = ['Toutes'];
  Map<String, int> _companyMap = {};
  Map<int, String> _companyNameCache = {};
  Map<int, String> _userNameCache = {};

  final List<String> _sortOptions = ['date', 'total', 'status', 'company'];

  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filteredOrders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final results = await Future.wait([
        _orderService.getAllOrders(),
        _companyService.getAllCompanies(),
      ]);

      final orders = results[0] as List<Map<String, dynamic>>;
      final companies = results[1] as List<Map<String, dynamic>>;

      _companyMap = {for (var comp in companies)
        if (comp['companyName'] != null) comp['companyName'] as String: comp['companyId'] as int};

      _companies = ['Toutes', ...companies
          .where((c) => c['companyName'] != null)
          .map((c) => c['companyName'] as String)];

      for (var comp in companies) {
        _companyNameCache[comp['companyId']] = comp['companyName'] ?? 'Entreprise inconnue';
      }

      setState(() {
        _allOrders = orders;
        _paginationState = _paginationState.copyWith(totalItems: orders.length);
        _isLoading = false;
      });

      await _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  Future<String> _getCompanyName(int companyId) async {
    if (_companyNameCache.containsKey(companyId)) {
      return _companyNameCache[companyId]!;
    }
    try {
      final company = await _companyService.getCompanyById(companyId);
      final name = company!['companyName'] ?? 'Entreprise inconnue';
      _companyNameCache[companyId] = name;
      return name;
    } catch (e) {
      return 'Entreprise inconnue';
    }
  }

  Future<String> _getUserName(int userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    try {
      final user = await _userService.getUserById(userId);
      final name = '${user!['fullName']}';
      _userNameCache[userId] = name.isEmpty ? 'Client inconnu' : name;
      return _userNameCache[userId]!;
    } catch (e) {
      return 'Client inconnu';
    }
  }

  Future<void> _applyFilters() async {
    List<Map<String, dynamic>> ordersToFilter;

    if (_selectedCompany != 'Toutes' && _companyMap.containsKey(_selectedCompany)) {
      try {
        final companyId = _companyMap[_selectedCompany]!;
        ordersToFilter = await _orderService.getOrdersByCompanyId(companyId);
      } catch (e) {
        ordersToFilter = _allOrders;
      }
    } else {
      ordersToFilter = _allOrders;
    }

    _filteredOrders = ordersToFilter.where((order) {
      final orderDate = _formatDate(order['orderDate']);
      final orderStatus = order['orderStatus']?.toString() ?? '';
      final total = (order['totalAmount'] ?? 0).toDouble();

      bool matchesSearch = orderDate.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order['orderId']?.toString().contains(_searchQuery) == true;
      bool matchesStatus = _selectedStatus == 'Tous' || orderStatus == _selectedStatus;
      bool matchesCompany = _selectedCompany == 'Toutes' ||
          (_selectedCompany != 'Toutes' && ordersToFilter != _allOrders);
      bool matchesTotal = total >= _minTotal && total <= _maxTotal;

      return matchesSearch && matchesStatus && matchesCompany && matchesTotal;
    }).toList();

    _filteredOrders.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'total':
          final totalA = (a['totalAmount'] ?? 0).toDouble();
          final totalB = (b['totalAmount'] ?? 0).toDouble();
          comparison = totalA.compareTo(totalB);
          break;
        case 'status':
          final statusA = a['orderStatus']?.toString() ?? '';
          final statusB = b['orderStatus']?.toString() ?? '';
          comparison = statusA.compareTo(statusB);
          break;
        case 'company':
          final companyA = a['company']?['companyName']?.toString() ?? '';
          final companyB = b['company']?['companyName']?.toString() ?? '';
          comparison = companyA.compareTo(companyB);
          break;
        default:
          final dateA = a['orderDate']?.toString() ?? '';
          final dateB = b['orderDate']?.toString() ?? '';
          comparison = dateA.compareTo(dateB);
      }
      return _sortAscending ? comparison : -comparison;
    });

    if (mounted) {
      setState(() {
        _paginationState = _paginationState.copyWith(currentPage: 1, totalItems: _filteredOrders.length);
      });
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => OwnerOrderDetailsDialog(
        order: order,
        onOrderUpdated: () {
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final paginationService = PaginationService(itemsPerPage: 12);
    final paginatedOrders = paginationService.getPageItems(
        _filteredOrders,
        _paginationState.currentPage
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: isMobile ? _buildMobileLayout(paginatedOrders) : _buildWebLayout(paginatedOrders),
    );
  }

  Widget _buildMobileLayout(List<Map<String, dynamic>> paginatedOrders) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(isMobile: true),
          _buildFiltersSection(isMobile: true),
          _buildOrdersContent(paginatedOrders, isMobile: true),
          if (_filteredOrders.isNotEmpty) _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildWebLayout(List<Map<String, dynamic>> paginatedOrders) {
    return Column(
      children: [
        _buildHeader(isMobile: false),
        _buildFiltersSection(isMobile: false),
        Expanded(
          child: _buildOrdersContent(paginatedOrders, isMobile: false),
        ),
        if (_filteredOrders.isNotEmpty) _buildPaginationBar(),
      ],
    );
  }

  Widget _buildHeader({required bool isMobile}) {
    final totalRevenue = _allOrders.fold<double>(
      0,
          (sum, order) => sum + ((order['totalAmount'] ?? 0).toDouble()),
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: isMobile
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.textLight,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gestion des\nCommandes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_filteredOrders.length} commandes',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildStatsRow(totalRevenue, isMobile: true),
          ),
        ],
      )
          : Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.textLight,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestion des Commandes',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_filteredOrders.length} commandes trouvées',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _buildStatsRow(totalRevenue, isMobile: false),
        ],
      ),
    );
  }

  Widget _buildStatsRow(double totalRevenue, {required bool isMobile}) {
    return Wrap(
      spacing: isMobile ? 8 : 12,
      children: [
        _buildStatCard('Totales', _allOrders.length.toString(), Icons.shopping_bag_rounded, isMobile),
        _buildStatCard('Revenu', '${totalRevenue.toStringAsFixed(0)}DT', Icons.trending_up_rounded, isMobile),
        _buildStatCard('Livrées',
            _allOrders.where((o) => o['orderStatus'] == 'DELIVERED').length.toString(),
            Icons.check_circle_rounded, isMobile),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 14, vertical: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: isMobile ? 14 : 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: isMobile ? 9 : 10, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFiltersSection({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: isMobile ? _buildMobileFilters() : _buildDesktopFilters(),
      ),
    );
  }

  Widget _buildMobileFilters() {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      spacing: 12,
      children: [
        TextField(
          onChanged: (value) async {
            _searchQuery = value;
            await _applyFilters();
          },
          decoration: InputDecoration(
            hintText: 'Rechercher...',
            isDense: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown('Statut', _selectedStatus, _statuses, (value) async {
                _selectedStatus = value!;
                await _applyFilters();
              }, isMobile),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFilterDropdown('Entreprise', _selectedCompany, _companies, (value) async {
                _selectedCompany = value!;
                await _applyFilters();
              }, isMobile),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Montant: ${_minTotal.toInt()}DT - ${_maxTotal.toInt()}DT',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            ),
            RangeSlider(
              values: RangeValues(_minTotal, _maxTotal),
              min: 0,
              max: 1000,
              divisions: 100,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.border.withOpacity(0.3),
              onChanged: (values) {
                setState(() {
                  _minTotal = values.start;
                  _maxTotal = values.end;
                });
              },
              onChangeEnd: (values) async => await _applyFilters(),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                value: _sortBy,
                isExpanded: true,
                items: _sortOptions.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(_getSortLabel(option), style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (value) async {
                  _sortBy = value!;
                  await _applyFilters();
                },
              ),
            ),
            IconButton(
              onPressed: () async {
                _sortAscending = !_sortAscending;
                await _applyFilters();
              },
              icon: Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: AppColors.primary,
                size: 20,
              ),
              constraints: const BoxConstraints(maxHeight: 35),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                onChanged: (value) async {
                  _searchQuery = value;
                  await _applyFilters();
                },
                decoration: InputDecoration(
                  hintText: 'Rechercher par ID ou date...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 22),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFilterDropdown('Statut', _selectedStatus, _statuses, (value) async {
                _selectedStatus = value!;
                await _applyFilters();
              }, false),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFilterDropdown('Entreprise', _selectedCompany, _companies, (value) async {
                _selectedCompany = value!;
                await _applyFilters();
              }, false),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Montant: ${_minTotal.toInt()}DT - ${_maxTotal.toInt()}DT',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                  ),
                  RangeSlider(
                    values: RangeValues(_minTotal, _maxTotal),
                    min: 0,
                    max: 1000,
                    divisions: 100,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border.withOpacity(0.3),
                    onChanged: (values) {
                      setState(() {
                        _minTotal = values.start;
                        _maxTotal = values.end;
                      });
                    },
                    onChangeEnd: (values) async => await _applyFilters(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            _buildSortSection(),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged, bool isMobile) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        isDense: isMobile,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(isMobile ? 10 : 12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
          borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 8 : 12),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  Widget _buildSortSection() {
    return Row(
      children: [
        DropdownButton<String>(
          value: _sortBy,
          items: _sortOptions.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(_getSortLabel(option), style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (value) async {
            _sortBy = value!;
            await _applyFilters();
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () async {
            _sortAscending = !_sortAscending;
            await _applyFilters();
          },
          icon: Icon(
            _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            color: AppColors.primary,
          ),
          tooltip: _sortAscending ? 'Croissant' : 'Décroissant',
        ),
      ],
    );
  }

  String _getSortLabel(String option) {
    switch (option) {
      case 'date': return 'Date';
      case 'total': return 'Montant';
      case 'status': return 'Statut';
      case 'company': return 'Entreprise';
      default: return option;
    }
  }

  Widget _buildOrdersContent(List<Map<String, dynamic>> orders, {required bool isMobile}) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 72,
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucune commande trouvée',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez de modifier vos filtres',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: isMobile ? _buildMobileOrdersList(orders) : _buildWebOrdersList(orders),
    );
  }

  Widget _buildMobileOrdersList(List<Map<String, dynamic>> orders) {
    return Column(
      spacing: 12,
      children: orders.map((order) => _buildOrderCard(order, isMobile: true)).toList(),
    );
  }

  Widget _buildWebOrdersList(List<Map<String, dynamic>> orders) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1200) {
          return _buildOrdersGrid(orders, 3);
        } else if (constraints.maxWidth > 900) {
          return _buildOrdersGrid(orders, 2);
        } else {
          return _buildOrdersGrid(orders, 1);
        }
      },
    );
  }

  Widget _buildOrdersGrid(List<Map<String, dynamic>> orders, int columns) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 1.15,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildOrderCard(orders[index], isMobile: false),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {required bool isMobile}) {
    final orderId = order['orderId']?.toString() ?? 'N/A';
    final orderDate = _formatDate(order['orderDate']);
    final orderStatus = order['orderStatus']?.toString() ?? '';
    final total = (order['totalAmount'] ?? 0).toDouble();
    final companyId = order['companyId'] as int?;
    final userId = order['userId'] as int?;

    Color statusColor = _getStatusColor(orderStatus);

    return GestureDetector(
      onTap: () => _showOrderDetails(order),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppColors.border.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [statusColor.withOpacity(0.2), statusColor.withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: statusColor,
                          size: isMobile ? 18 : 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commande #$orderId',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              orderDate,
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatusBadge(orderStatus, statusColor, isMobile),
                  const SizedBox(height: 12),
                  _buildOrderCardInfo(companyId, userId, isMobile),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 10 : 12,
                          vertical: isMobile ? 5 : 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${total.toStringAsFixed(2)} DT',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Voir détails'),
                    onTap: () => _showOrderDetails(order),
                  ),
                  PopupMenuItem(
                    child: const Text('Éditer'),
                    onTap: () {},
                  ),
                  PopupMenuItem(
                    child: const Text('Supprimer'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCardInfo(int? companyId, int? userId, bool isMobile) {
    return FutureBuilder<List<String>>(
      future: Future.wait([
        companyId != null ? _getCompanyName(companyId) : Future.value('Entreprise inconnue'),
        userId != null ? _getUserName(userId) : Future.value('Client inconnu'),
      ]),
      builder: (context, snapshot) {
        String companyName = 'Entreprise inconnue';
        String userName = 'Client inconnu';

        if (snapshot.hasData) {
          companyName = snapshot.data![0];
          userName = snapshot.data![1];
        }

        return Container(
          padding: EdgeInsets.all(isMobile ? 10 : 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.border.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.business, size: isMobile ? 14 : 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      companyName,
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: isMobile ? 14 : 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      userName,
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status, Color statusColor, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: isMobile ? 4 : 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'IN_PREPARATION':
        return Colors.blue;
      case 'WAITING':
        return Colors.purple;
      case 'ACCEPTED':
        return Colors.greenAccent;
      case 'PICKED_UP':
        return Colors.green;
      case 'DELIVERED':
        return AppColors.success;
      case 'CANCELED':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildPaginationBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final paginationService = PaginationService(itemsPerPage: 12);
    final totalPages = paginationService.getTotalPages(_filteredOrders.length);
    final startItem = (_paginationState.currentPage - 1) * _paginationState.itemsPerPage + 1;
    final endItem = (_paginationState.currentPage * _paginationState.itemsPerPage)
        .clamp(0, _filteredOrders.length);

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withOpacity(0.1), width: 1),
        ),
      ),
      child: isMobile
          ? Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Affichage de $startItem à $endItem sur ${_filteredOrders.length}',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _paginationState.currentPage > 1
                    ? () => setState(() {
                  _paginationState = _paginationState.copyWith(
                    currentPage: _paginationState.currentPage - 1,
                  );
                })
                    : null,
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              Text(
                '${_paginationState.currentPage}/$totalPages',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: _paginationState.currentPage < totalPages
                    ? () => setState(() {
                  _paginationState = _paginationState.copyWith(
                    currentPage: _paginationState.currentPage + 1,
                  );
                })
                    : null,
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
        ],
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage de $startItem à $endItem sur ${_filteredOrders.length}',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _paginationState.currentPage > 1
                    ? () => setState(() {
                  _paginationState = _paginationState.copyWith(
                    currentPage: _paginationState.currentPage - 1,
                  );
                })
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Page ${_paginationState.currentPage} sur $totalPages',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: _paginationState.currentPage < totalPages
                    ? () => setState(() {
                  _paginationState = _paginationState.copyWith(
                    currentPage: _paginationState.currentPage + 1,
                  );
                })
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
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