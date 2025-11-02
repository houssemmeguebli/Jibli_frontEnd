import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/theme.dart';
import '../../../../Core/services/order_service.dart';

class DeliveryStatisticsPage extends StatefulWidget {
  const DeliveryStatisticsPage({super.key});

  @override
  State<DeliveryStatisticsPage> createState() => _DeliveryStatisticsPageState();
}

class _DeliveryStatisticsPageState extends State<DeliveryStatisticsPage>
    with TickerProviderStateMixin {
  final OrderService _orderService = OrderService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = true;
  String _selectedPeriod = 'monthly';
  final int currentDeliveryId = 3;

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _statusData = [];
  List<Map<String, dynamic>> _revenueData = [];
  List<Map<String, dynamic>> _recentDeliveries = [];
  List<Map<String, dynamic>> _allOrders = [];

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

      final deliveryOrders = await _orderService.getOrdersByDeliveryId(currentDeliveryId);

      setState(() {
        _allOrders = deliveryOrders;
      });

      await _calculateStatistics(deliveryOrders);

      setState(() => _isLoading = false);
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showErrorSnackBar('Erreur: ${e.toString()}');
      }
    }
  }

  Future<void> _calculateStatistics(
      List<Map<String, dynamic>> orders) async {
    final now = DateTime.now();
    final periodOrders = _filterOrdersByPeriod(orders, now);

    final statusCounts = <String, int>{};
    for (var order in periodOrders) {
      final status = order['orderStatus'] ?? 'UNKNOWN';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    final totalDeliveries = periodOrders.length;
    final deliveredCount =
        periodOrders.where((o) => o['orderStatus'] == 'DELIVERED').length;
    final rejectedCount =
        periodOrders.where((o) => o['orderStatus'] == 'REJECTED').length;
    final pickedUpCount =
        periodOrders.where((o) => o['orderStatus'] == 'PICKED_UP').length;

    final totalEarnings = periodOrders.fold<double>(0, (sum, order) {
      if (order['orderStatus'] == 'DELIVERED' ||
          order['orderStatus'] == 'PICKED_UP') {
        return sum +
            ((order['deliveryFee'] ?? 0) as num).toDouble();
      }
      return sum;
    });

    final completionRate =
    totalDeliveries > 0 ? (deliveredCount / totalDeliveries * 100) : 0.0;
    final rejectionRate =
    totalDeliveries > 0 ? (rejectedCount / totalDeliveries * 100) : 0.0;
    final avgDeliveryTime = _calculateAvgDeliveryTime(periodOrders);
    final growthRate = _calculateGrowthRate(orders);

    final revenueByPeriod = _calculateRevenueByPeriod(periodOrders);

    final filteredStatusCounts = <String, int>{
      'WAITING': statusCounts['WAITING'] ?? 0,
      'PICKED_UP': statusCounts['PICKED_UP'] ?? 0,
      'DELIVERED': statusCounts['DELIVERED'] ?? 0,
      'REJECTED': statusCounts['REJECTED'] ?? 0,
    };

    setState(() {
      _stats = {
        'totalDeliveries': totalDeliveries,
        'deliveredCount': deliveredCount,
        'pickedUpCount': pickedUpCount,
        'rejectedCount': rejectedCount,
        'totalEarnings': totalEarnings,
        'completionRate': completionRate,
        'rejectionRate': rejectionRate,
        'avgDeliveryTime': avgDeliveryTime,
        'growthRate': growthRate,
        'periodLabel': _getPeriodLabel(),
      };

      _statusData = filteredStatusCounts.entries
          .map((e) => {
        'status': e.key,
        'count': e.value,
        'percentage': totalDeliveries > 0
            ? (e.value / totalDeliveries * 100).round()
            : 0,
      })
          .toList()
        ..removeWhere((item) => item['count'] == 0);

      _revenueData = revenueByPeriod.entries
          .map((e) => {
        'day': e.key,
        'revenue': e.value,
      })
          .toList();

      _recentDeliveries = periodOrders.take(10).toList();
    });
  }

  List<Map<String, dynamic>> _filterOrdersByPeriod(
      List<Map<String, dynamic>> orders, DateTime now) {
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'weekly':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'all':
        return orders;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }

    return orders.where((order) {
      final orderDate = _parseDate(order['orderDate']);
      return orderDate != null && orderDate.isAfter(startDate);
    }).toList();
  }

  Map<String, double> _calculateRevenueByPeriod(
      List<Map<String, dynamic>> periodOrders) {
    final revenueByPeriod = <String, double>{};

    for (var order in periodOrders) {
      if (order['orderStatus'] == 'DELIVERED' ||
          order['orderStatus'] == 'PICKED_UP') {
        final orderDate = _parseDate(order['orderDate']);
        if (orderDate != null) {
          String periodKey;

          if (_selectedPeriod == 'daily') {
            periodKey =
            '${orderDate.hour}:${orderDate.minute.toString().padLeft(2, '0')}';
          } else if (_selectedPeriod == 'weekly') {
            const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
            periodKey = days[orderDate.weekday - 1];
          } else {
            periodKey = '${orderDate.day}/${orderDate.month}';
          }

          final fee = ((order['deliveryFee'] ?? 0) as num).toDouble();
          revenueByPeriod[periodKey] =
              (revenueByPeriod[periodKey] ?? 0) + fee;
        }
      }
    }

    final sortedEntries = revenueByPeriod.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Map.fromEntries(sortedEntries);
  }

  double _calculateAvgDeliveryTime(List<Map<String, dynamic>> orders) {
    final deliveredOrders =
    orders.where((o) => o['orderStatus'] == 'DELIVERED').toList();
    if (deliveredOrders.isEmpty) return 0.0;

    double totalMinutes = 0;
    int validOrders = 0;

    for (var order in deliveredOrders) {
      final orderDate = _parseDate(order['orderDate']);
      final deliveryDate = _parseDate(order['deliveredDate']);

      if (orderDate != null && deliveryDate != null) {
        totalMinutes += deliveryDate.difference(orderDate).inMinutes;
        validOrders++;
      }
    }

    return validOrders > 0 ? totalMinutes / validOrders / 60 : 0.0;
  }

  double _calculateGrowthRate(List<Map<String, dynamic>> allOrders) {
    final now = DateTime.now();
    DateTime currentStart, previousStart;

    switch (_selectedPeriod) {
      case 'daily':
        currentStart = DateTime(now.year, now.month, now.day);
        previousStart =
            DateTime(now.year, now.month, now.day - 1);
        break;
      case 'weekly':
        currentStart = now.subtract(Duration(days: now.weekday - 1));
        currentStart =
            DateTime(currentStart.year, currentStart.month, currentStart.day);
        previousStart = currentStart.subtract(const Duration(days: 7));
        break;
      case 'monthly':
        currentStart = DateTime(now.year, now.month, 1);
        previousStart =
            DateTime(now.year, now.month - 1, 1);
        break;
      default:
        return 0;
    }

    final currentEarnings = allOrders
        .where((order) {
      final orderDate = _parseDate(order['orderDate']);
      return orderDate != null &&
          orderDate.isAfter(currentStart) &&
          (order['orderStatus'] == 'DELIVERED' ||
              order['orderStatus'] == 'PICKED_UP');
    })
        .fold<double>(0,
            (sum, order) => sum + ((order['deliveryFee'] ?? 0) as num).toDouble());

    final previousEarnings = allOrders
        .where((order) {
      final orderDate = _parseDate(order['orderDate']);
      return orderDate != null &&
          orderDate.isAfter(previousStart) &&
          orderDate.isBefore(currentStart) &&
          (order['orderStatus'] == 'DELIVERED' ||
              order['orderStatus'] == 'PICKED_UP');
    })
        .fold<double>(0,
            (sum, order) => sum + ((order['deliveryFee'] ?? 0) as num).toDouble());

    if (previousEarnings == 0) return 0;
    return ((currentEarnings - previousEarnings) / previousEarnings * 100);
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'daily':
        return 'Aujourd\'hui';
      case 'weekly':
        return 'Cette semaine';
      case 'monthly':
        return 'Ce mois';
      case 'all':
        return 'Historique complet';
      default:
        return '';
    }
  }

  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;

    if (dateValue is DateTime) return dateValue;

    if (dateValue is String) {
      try {
        final parts = dateValue
            .replaceAll(' ', '')
            .split(',')
            .map((s) => int.parse(s))
            .toList();

        if (parts.length >= 3) {
          final year = parts[0];
          final month = parts[1];
          final day = parts[2];
          final hour = parts.length > 3 ? parts[3] : 0;
          final minute = parts.length > 4 ? parts[4] : 0;
          final second = parts.length > 5 ? parts[5] : 0;

          return DateTime(year, month, day, hour, minute, second);
        }
      } catch (e) {
        return null;
      }
    }

    if (dateValue is List && dateValue.isNotEmpty) {
      try {
        final year = (dateValue[0] as num).toInt();
        final month =
        dateValue.length > 1 ? (dateValue[1] as num).toInt() : 1;
        final day = dateValue.length > 2 ? (dateValue[2] as num).toInt() : 1;
        final hour = dateValue.length > 3 ? (dateValue[3] as num).toInt() : 0;
        final minute =
        dateValue.length > 4 ? (dateValue[4] as num).toInt() : 0;
        final second =
        dateValue.length > 5 ? (dateValue[5] as num).toInt() : 0;

        return DateTime(year, month, day, hour, minute, second);
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
            _buildRecentDeliveriesSection(isMobile),
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
                Icons.local_shipping_rounded,
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
                    'Mes Statistiques',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 22 : 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Historique complet & Analyses de performances',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(bool isMobile) {
    final periods = [
      {'value': 'daily', 'label': 'Aujourd\'hui', 'icon': Icons.today_rounded},
      {'value': 'weekly', 'label': 'Semaine', 'icon': Icons.date_range_rounded},
      {'value': 'monthly', 'label': 'Mois', 'icon': Icons.calendar_month_rounded},
      {'value': 'all', 'label': 'Historique', 'icon': Icons.history_rounded},
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
                  setState(() => _selectedPeriod = period['value']! as String);
                  _loadStatistics();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 10),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        period['icon'] as IconData,
                        color: isSelected ? Colors.white : Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        period['label']! as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                          fontSize: isMobile ? 11 : 12,
                        ),
                      ),
                    ],
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
        'title': 'Total',
        'value': '${_stats['totalDeliveries'] ?? 0}',
        'icon': Icons.local_shipping_rounded,
        'color': Colors.blue,
      },
      {
        'title': 'Livrées',
        'value': '${_stats['deliveredCount'] ?? 0}',
        'icon': Icons.check_circle_rounded,
        'color': Colors.green,
      },
      {
        'title': 'Rejetées',
        'value': '${_stats['rejectedCount'] ?? 0}',
        'icon': Icons.cancel_rounded,
        'color': Colors.red,
      },
      {
        'title': 'Gains',
        'value': '${(_stats['totalEarnings'] ?? 0.0).toStringAsFixed(2)} DT',
        'icon': Icons.monetization_on_rounded,
        'color': Colors.purple,
      },
    ];

    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isMobile ? 2 : 3,
          childAspectRatio: isMobile ? 1.0 : 1.2,
          crossAxisSpacing: isMobile ? 10 : 16,
          mainAxisSpacing: isMobile ? 10 : 16,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) => _buildStatCard(stats[index]),
          childCount: stats.length,
        ),
      ),
    );
  }

  Widget _buildStatCard(Map<String, dynamic> stat) {
    final color = stat['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(14),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              stat['icon'] as IconData,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stat['value'] as String,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            stat['title'] as String,
            style: TextStyle(
              fontSize: 11,
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
                  size: isMobile ? 20 : 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Évolution des Gains',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _stats['periodLabel'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: isMobile ? 200 : 250,
            child: _revenueData.isEmpty
                ? Center(
              child: Text(
                'Aucune donnée',
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
                        fontSize: 10,
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
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
              reservedSize: 40,
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
                  radius: 4,
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
                  size: isMobile ? 20 : 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statut des Livraisons',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _stats['periodLabel'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_statusData.isEmpty)
            Center(
              child: Text(
                'Aucune donnée',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          else
            SizedBox(
              height: isMobile ? 200 : 250,
              width: double.infinity,
              child: _buildPieChart(),
            ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    List<PieChartSectionData> sections = [];
    List<Color> colors = [
      Colors.purple,
      Colors.cyan,
      Colors.green,
      Colors.red,
    ];

    for (int i = 0; i < _statusData.length; i++) {
      final data = _statusData[i];
      sections.add(
        PieChartSectionData(
          color: colors[i % colors.length],
          value: (data['count'] as int).toDouble(),
          title: '${data['percentage']}%',
          radius: 45,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 28,
        sectionsSpace: 2,
      ),
    );
  }

  Widget _buildRecentDeliveriesSection(bool isMobile) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      sliver: SliverToBoxAdapter(
        child: _buildRecentDeliveries(isMobile),
      ),
    );
  }

  Widget _buildRecentDeliveries(bool isMobile) {
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
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Livraisons Récentes',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_recentDeliveries.length} livraison(s)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentDeliveries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aucune livraison récente',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ..._recentDeliveries.map((delivery) =>
                _buildDeliveryRow(delivery, isMobile)),
        ],
      ),
    );
  }

  Widget _buildDeliveryRow(Map<String, dynamic> delivery, bool isMobile) {
    final orderId = delivery['orderId'] ?? 0;
    final status = delivery['orderStatus'] ?? 'UNKNOWN';
    final fee = delivery['deliveryFee'] ?? 0.0;
    final date = _parseDate(delivery['orderDate']);
    final customerName = delivery['customerName'] ?? 'Client';

    final statusColor = _getStatusColor(status);
    final statusLabel = _getStatusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
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
              _getStatusIcon(status),
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
                    Expanded(
                      child: Text(
                        'Commande #$orderId',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
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
                        statusLabel,
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
                    Expanded(
                      child: Text(
                        customerName,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      date != null
                          ? '${date.day}/${date.month}'
                          : 'N/A',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (status == 'DELIVERED' || status == 'PICKED_UP') ...[
                  const SizedBox(height: 4),
                  Text(
                    '${fee.toStringAsFixed(2)} DT',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'WAITING':
        return Colors.purple;
      case 'PICKED_UP':
        return Colors.cyan;
      case 'DELIVERED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'WAITING':
        return Icons.schedule_rounded;
      case 'PICKED_UP':
        return Icons.local_shipping_rounded;
      case 'DELIVERED':
        return Icons.done_all_rounded;
      case 'REJECTED':
        return Icons.cancel_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'WAITING':
        return 'En attente';
      case 'PICKED_UP':
        return 'Récupéré';
      case 'DELIVERED':
        return 'Livré';
      case 'REJECTED':
        return 'Rejeté';
      default:
        return status;
    }
  }
}