import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../../../../core/theme/theme.dart';
import '../../../../Core/services/order_service.dart';
import '../../../../Core/services/order_item_service.dart';
import '../../../../Core/services/product_service.dart';
import '../../../../Core/services/user_service.dart';

class OwnerStatisticsPage extends StatefulWidget {
  const OwnerStatisticsPage({super.key});

  @override
  State<OwnerStatisticsPage> createState() => _OwnerStatisticsPageState();
}

class _OwnerStatisticsPageState extends State<OwnerStatisticsPage>
    with TickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final OrderItemService _orderItemService = OrderItemService();
  final ProductService _productService = ProductService();
  final UserService _userService = UserService('http://192.168.1.216:8080');

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  String _selectedPeriod = '30';
  final int currentUserId = 2;

  // Statistics data
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _revenueData = [];
  List<Map<String, dynamic>> _orderStatusData = [];
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _loadStatistics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() => _isLoading = true);

      final allOrders = await _orderService.getAllOrders();
      final ownerOrders = await _filterOwnerOrders(allOrders);
      final products =
      await _productService.getProductByUserId(currentUserId);

      await _calculateStatistics(ownerOrders, products);

      setState(() => _isLoading = false);
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Erreur de chargement: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _filterOwnerOrders(
      List<Map<String, dynamic>> allOrders) async {
    List<Map<String, dynamic>> ownerOrders = [];

    for (var order in allOrders) {
      final orderId = order['orderId'];
      if (orderId != null) {
        final orderItems =
        await _orderItemService.getOrderItemsByOrder(orderId);

        bool hasOwnerProduct = false;
        double ownerRevenue = 0.0;
        int ownerItemCount = 0;

        for (var item in orderItems) {
          final productId = item['productId'];
          if (productId != null) {
            final product = await _productService.getProductById(productId);
            if (product != null && product['userId'] == currentUserId) {
              hasOwnerProduct = true;
              ownerItemCount += (item['quantity'] ?? 0) as int;
              ownerRevenue += ((item['quantity'] ?? 0) as int) *
                  ((product['productFinalePrice'] ?? 0) as num).toDouble();
            }
          }
        }

        if (hasOwnerProduct) {
          order['ownerRevenue'] = ownerRevenue;
          order['ownerItemCount'] = ownerItemCount;
          ownerOrders.add(order);
        }
      }
    }

    return ownerOrders;
  }

  Future<void> _calculateStatistics(List<Map<String, dynamic>> orders,
      List<Map<String, dynamic>> products) async {
    final now = DateTime.now();
    final periodDays = int.parse(_selectedPeriod);
    final startDate = now.subtract(Duration(days: periodDays));

    final periodOrders = orders.where((order) {
      final orderDate = _parseDate(order['orderDate']);
      return orderDate != null && orderDate.isAfter(startDate);
    }).toList();

    final totalRevenue = periodOrders.fold<double>(
        0, (sum, order) => sum + (order['ownerRevenue'] ?? 0.0));
    final totalOrders = periodOrders.length;
    final totalProducts = products.length;
    final avgOrderValue =
    totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    final statusCounts = <String, int>{};
    for (var order in periodOrders) {
      final status = order['orderStatus'] ?? 'UNKNOWN';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    final revenueByDay = <String, double>{};
    for (var order in periodOrders) {
      final orderDate = _parseDate(order['orderDate']);
      if (orderDate != null) {
        final dayKey = '${orderDate.day}/${orderDate.month}';
        revenueByDay[dayKey] =
            (revenueByDay[dayKey] ?? 0) + (order['ownerRevenue'] ?? 0.0);
      }
    }

    final productSales = <int, Map<String, dynamic>>{};
    for (var order in periodOrders) {
      final orderId = order['orderId'];
      if (orderId != null) {
        final orderItems =
        await _orderItemService.getOrderItemsByOrder(orderId);
        for (var item in orderItems) {
          final productId = item['productId'];
          final product = await _productService.getProductById(productId);
          if (product != null && product['userId'] == currentUserId) {
            if (!productSales.containsKey(productId)) {
              productSales[productId] = {
                'product': product,
                'quantity': 0,
                'revenue': 0.0,
              };
            }
            productSales[productId]!['quantity'] +=
            (item['quantity'] ?? 0) as int;
            productSales[productId]!['revenue'] += ((item['quantity'] ?? 0)
            as int) *
                ((product['productFinalePrice'] ?? 0) as num).toDouble();
          }
        }
      }
    }

    final topProductsList = productSales.values.toList()
      ..sort((a, b) =>
          (b['revenue'] as double).compareTo(a['revenue'] as double));

    setState(() {
      _stats = {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'totalProducts': totalProducts,
        'avgOrderValue': avgOrderValue,
        'growthRate': _calculateGrowthRate(orders, periodDays),
      };

      _orderStatusData = statusCounts.entries
          .map((e) => {
        'status': e.key,
        'count': e.value,
        'percentage': (e.value / totalOrders * 100).round(),
      })
          .toList();

      _revenueData = revenueByDay.entries
          .map((e) => {
        'day': e.key,
        'revenue': e.value,
      })
          .toList()
        ..sort((a, b) =>
            (a['day'] as String).compareTo(b['day'] as String));

      _topProducts = topProductsList.take(5).toList();
      _recentOrders = periodOrders.take(10).toList();
    });
  }

  double _calculateGrowthRate(
      List<Map<String, dynamic>> allOrders, int periodDays) {
    final now = DateTime.now();
    final currentPeriodStart = now.subtract(Duration(days: periodDays));
    final previousPeriodStart =
    now.subtract(Duration(days: periodDays * 2));

    final currentRevenue = allOrders
        .where((order) {
      final orderDate = _parseDate(order['orderDate']);
      return orderDate != null && orderDate.isAfter(currentPeriodStart);
    })
        .fold<double>(0, (sum, order) => sum + (order['ownerRevenue'] ?? 0.0));

    final previousRevenue = allOrders
        .where((order) {
      final orderDate = _parseDate(order['orderDate']);
      return orderDate != null &&
          orderDate.isAfter(previousPeriodStart) &&
          orderDate.isBefore(currentPeriodStart);
    })
        .fold<double>(0, (sum, order) => sum + (order['ownerRevenue'] ?? 0.0));

    if (previousRevenue == 0) return 0;
    return ((currentRevenue - previousRevenue) / previousRevenue * 100);
  }

  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is DateTime) return dateValue;
    if (dateValue is List && dateValue.isNotEmpty) {
      try {
        final year = (dateValue[0] as num).toInt();
        final month = dateValue.length > 1 ? (dateValue[1] as num).toInt() : 1;
        final day = dateValue.length > 2 ? (dateValue[2] as num).toInt() : 1;
        return DateTime(year, month, day);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        child: CustomScrollView(
          slivers: [
            _buildHeader(isMobile),
            _buildPeriodSelector(isMobile),
            _buildStatsCards(isMobile),
            _buildChartsSection(isMobile),
            _buildTablesSection(isMobile),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
            padding: const EdgeInsets.all(32),
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
            'Chargement des statistiques...',
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
    return SliverToBoxAdapter(
      child: Container(
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
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.analytics_rounded,
                color: Colors.white,
                size: isMobile ? 28 : 32,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistiques & Analytics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 22 : 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Analysez vos performances commerciales en détail',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadStatistics,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              iconSize: isMobile ? 24 : 28,
              tooltip: 'Actualiser',
              splashRadius: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(bool isMobile) {
    final periods = [
      {'value': '7', 'label': '7 jours'},
      {'value': '30', 'label': '30 jours'},
      {'value': '90', 'label': '3 mois'},
      {'value': '365', 'label': '1 an'},
    ];

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: isMobile ? 12 : 16,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: periods.map((period) {
              final isSelected = _selectedPeriod == period['value'];
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedPeriod = period['value']!);
                  _loadStatistics();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 10),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey[300]!,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                        : null,
                  ),
                  child: Text(
                    period['label']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: isMobile ? 12 : 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(bool isMobile) {
    final stats = [
      {
        'title': 'Chiffre d\'Affaires',
        'value':
        '${(_stats['totalRevenue'] ?? 0.0).toStringAsFixed(2)} DT',
        'icon': Icons.monetization_on_rounded,
        'color': Colors.green,
        'growth': _stats['growthRate'] ?? 0.0,
      },
      {
        'title': 'Commandes',
        'value': '${_stats['totalOrders'] ?? 0}',
        'icon': Icons.shopping_cart_rounded,
        'color': Colors.blue,
        'growth': 0.0,
      },
      {
        'title': 'Produits Actifs',
        'value': '${_stats['totalProducts'] ?? 0}',
        'icon': Icons.inventory_2_rounded,
        'color': Colors.orange,
        'growth': 0.0,
      },
      {
        'title': 'Panier Moyen',
        'value': '${(_stats['avgOrderValue'] ?? 0.0).toStringAsFixed(2)} DT',
        'icon': Icons.trending_up_rounded,
        'color': Colors.purple,
        'growth': 0.0,
      },
    ];

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 2 : 4,
          childAspectRatio: isMobile ? 1.1 : 1.3,
          crossAxisSpacing: isMobile ? 10 : 16,
          mainAxisSpacing: isMobile ? 10 : 16,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) => _buildStatCard(stats[index], isMobile),
          childCount: stats.length,
        ),
      ),
    );
  }

  Widget _buildStatCard(Map<String, dynamic> stat, bool isMobile) {
    final growth = stat['growth'] as double;
    final isPositive = growth >= 0;
    final color = stat['color'] as Color;

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  stat['icon'] as IconData,
                  color: color,
                  size: isMobile ? 22 : 26,
                ),
              ),
              if (growth != 0.0)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? Colors.green.withOpacity(0.15)
                        : Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 14,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${growth.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 11,
                          fontWeight: FontWeight.w700,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stat['value'] as String,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            stat['title'] as String,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(bool isMobile) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            if (isMobile) ...[
              _buildRevenueChart(isMobile),
              const SizedBox(height: 16),
              _buildStatusChart(isMobile),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildRevenueChart(isMobile)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildStatusChart(isMobile)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
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
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.primary,
                  size: isMobile ? 22 : 26,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Évolution du Chiffre d\'Affaires',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: isMobile ? 250 : 300,
            child: _revenueData.isEmpty
                ? Center(
              child: Text(
                'Aucune donnée disponible',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
                : _buildLineChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    List<FlSpot> spots = [];
    for (int i = 0; i < _revenueData.length; i++) {
      spots.add(FlSpot(
        i.toDouble(),
        (_revenueData[i]['revenue'] as double),
      ));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 500,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[200],
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < _revenueData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _revenueData[value.toInt()]['day'].toString(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()} DT',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
              reservedSize: 50,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: Colors.grey[300]!, width: 1),
            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        minX: 0,
        maxX: (_revenueData.length - 1).toDouble(),
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.5),
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: AppColors.primary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.3),
                  AppColors.primary.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
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
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  color: AppColors.primary,
                  size: isMobile ? 22 : 26,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Statut des Commandes',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_orderStatusData.isEmpty)
            Center(
              child: Text(
                'Aucune données',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          else
            SizedBox(
              height: isMobile ? 250 : 300,
              child: _buildPieChart(),
            ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    List<PieChartSectionData> sections = [];
    List<Color> colors = [
      Colors.orange,
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.cyan,
      Colors.green,
      Colors.red,
    ];

    for (int i = 0; i < _orderStatusData.length; i++) {
      final data = _orderStatusData[i];
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: (data['count'] as int).toDouble(),
          title: '${data['percentage']}%',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildTablesSection(bool isMobile) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            if (isMobile) ...[
              _buildTopProductsTable(isMobile),
              const SizedBox(height: 16),
              _buildRecentOrdersTable(isMobile),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTopProductsTable(isMobile)),
                  const SizedBox(width: 20),
                  Expanded(child: _buildRecentOrdersTable(isMobile)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProductsTable(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
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
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Top 5 Produits',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_topProducts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aucun produit vendu',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ..._topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return _buildProductRow(index + 1, product, isMobile);
            }),
        ],
      ),
    );
  }

  Widget _buildProductRow(int rank, Map<String, dynamic> productData,
      bool isMobile) {
    final product = productData['product'] as Map<String, dynamic>;
    final quantity = productData['quantity'] as int;
    final revenue = productData['revenue'] as double;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: isMobile ? 32 : 36,
            height: isMobile ? 32 : 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: rank <= 3
                    ? [AppColors.primary, AppColors.primary.withOpacity(0.7)]
                    : [Colors.grey[300]!, Colors.grey[200]!],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 15,
                  fontWeight: FontWeight.w800,
                  color: rank <= 3 ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['productName'] ?? 'Produit',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$quantity vendus',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.green.withOpacity(0.3),
              ),
            ),
            child: Text(
              '${revenue.toStringAsFixed(0)} DT',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrdersTable(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
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
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Commandes Récentes',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_recentOrders.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aucune commande récente',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ..._recentOrders.map((order) => _buildOrderRow(order, isMobile)),
        ],
      ),
    );
  }

  Widget _buildOrderRow(Map<String, dynamic> order, bool isMobile) {
    final orderId = order['orderId'] ?? 0;
    final status = order['orderStatus'] ?? 'UNKNOWN';
    final revenue = order['ownerRevenue'] ?? 0.0;
    final date = _parseDate(order['orderDate']);

    final statusColors = {
      'PENDING': Colors.orange,
      'IN_PREPARATION': Colors.blue,
      'WAITING': Colors.purple,
      'ACCEPTED': Colors.teal,
      'PICKED_UP': Colors.cyan,
      'DELIVERED': Colors.green,
      'REJECTED': Colors.orange,
      'CANCELED': Colors.red,
    };

    final statusColor = statusColors[status] ?? Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.receipt_outlined,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Commande #$orderId',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _getStatusLabel(status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      date != null
                          ? '${date.day}/${date.month}/${date.year}'
                          : 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${revenue.toStringAsFixed(2)} DT',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'En attente';
      case 'IN_PREPARATION':
        return 'En préparation';
      case 'WAITING':
        return 'Assigné';
      case 'ACCEPTED':
        return 'Accepté';
      case 'PICKED_UP':
        return 'Récupéré';
      case 'DELIVERED':
        return 'Livré';
      case 'REJECTED':
        return 'Refusé';
      case 'CANCELED':
        return 'Annulé';
      default:
        return status;
    }
  }
}