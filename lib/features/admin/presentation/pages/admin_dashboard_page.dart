import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/review_service.dart';
import '../../../../core/services/order_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final CompanyService _companyService = CompanyService();
  final ReviewService _reviewService = ReviewService();
  final OrderService _orderService = OrderService();

  int _totalUsers = 0;
  int _totalCompanies = 0;
  int _totalReviews = 0;
  int _totalOrders = 0;
  int _activeUsers = 0;
  int _activeCompanies = 0;
  int _inactiveCompanies = 0;
  int _bannedCompanies = 0;
  double _totalRevenue = 0.0;
  double _averageRating = 0.0;
  int _newUsersThisMonth = 0;
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final users = await _userService.getAllUsers();
      final companies = await _companyService.getAllCompanies();
      final reviews = await _reviewService.getAllReviews();
      final orders = await _orderService.getAllOrders();

      if (mounted) {
        final activeUsers =
            users.where((u) => u['userStatus'] == 'ACTIVE').length;
        final activeComps =
            companies.where((c) => c['companyStatus'] == 'ACTIVE').length;
        final inactiveComps =
            companies.where((c) => c['companyStatus'] == 'INACTIVE').length;
        final bannedComps =
            companies.where((c) => c['companyStatus'] == 'BANNED').length;

        double revenue = 0.0;
        for (var order in orders) {
          final total = order['totalAmount'];
          if (total != null) {
            if (total is int) {
              revenue += total.toDouble();
            } else if (total is double) {
              revenue += total;
            } else if (total is String) {
              revenue += double.tryParse(total) ?? 0.0;
            }
          }
        }

        double totalRating = 0.0;
        for (var review in reviews) {
          final rating = review['rating'] ?? 0;
          totalRating +=
          (rating is int) ? rating.toDouble() : (rating as double);
        }
        double avgRating =
        reviews.isNotEmpty ? totalRating / reviews.length : 0.0;

        final now = DateTime.now();
        final thisMonth = users.where((u) {
          final createdDate = u['createdAt'];
          if (createdDate is String) {
            try {
              final date = DateTime.parse(createdDate);
              return date.year == now.year && date.month == now.month;
            } catch (e) {
              return false;
            }
          }
          return false;
        }).length;

        setState(() {
          _totalUsers = users.length;
          _totalCompanies = companies.length;
          _totalReviews = reviews.length;
          _totalOrders = orders.length;
          _activeUsers = activeUsers;
          _activeCompanies = activeComps;
          _inactiveCompanies = inactiveComps;
          _bannedCompanies = bannedComps;
          _totalRevenue = revenue;
          _averageRating = avgRating;
          _newUsersThisMonth = thisMonth;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chargement du tableau de bord...',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOut,
            ),
          ),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(isMobile),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : isTablet ? 20 : 32,
                  isMobile ? 16 : 24,
                  isMobile ? 16 : isTablet ? 20 : 32,
                  0,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMainStatsGrid(isMobile, isTablet),
                    const SizedBox(height: 28),
                    _buildCompanyStatsGrid(isMobile, isTablet),
                    const SizedBox(height: 28),
                    _buildAnalyticsSection(isMobile, isTablet),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isMobile ? 12 : 16),
        left: isMobile ? 16 : 24,
        right: isMobile ? 16 : 24,
        bottom: isMobile ? 16 : 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tableau de Bord',
                      style: TextStyle(
                        fontSize: isMobile ? 22 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gestion complète de la plateforme',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateTime.now().toString().split(' ')[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildMainStatsGrid(bool isMobile, bool isTablet) {
    final crossCount = isMobile ? 2 : isTablet ? 2 : 4;
    final stats = [
      {
        'title': 'Utilisateurs',
        'value': _totalUsers.toString(),
        'icon': Icons.people_outline,
        'color': const Color(0xFF3B82F6),
        'change': '+$_newUsersThisMonth ce mois',
      },
      {
        'title': 'Entreprises',
        'value': _activeCompanies.toString(),
        'icon': Icons.business_outlined,
        'color': const Color(0xFF10B981),
        'change':
        '${((_activeCompanies / _totalCompanies) * 100).toStringAsFixed(1)}%',
      },
      {
        'title': 'Commandes',
        'value': _totalOrders.toString(),
        'icon': Icons.shopping_cart_outlined,
        'color': const Color(0xFFF59E0B),
        'change': '+${(_totalOrders > 0 ? ((100 / _totalOrders) * 8.2).toStringAsFixed(1) : '0')}%',
      },
      {
        'title': 'Revenu',
        'value': '${(_totalRevenue / 1000).toStringAsFixed(1)}K DT',
        'icon': Icons.trending_up,
        'color': const Color(0xFF8B5CF6),
        'change': '+15.3%',
      },
    ];

    return GridView.count(
      crossAxisCount: crossCount,
      crossAxisSpacing: isMobile ? 10 : 16,
      mainAxisSpacing: isMobile ? 10 : 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isMobile ? 1.25 : isTablet ? 1.4 : 1.7,
      children: List.generate(
        stats.length,
            (index) => _buildStatCard(
          stats[index]['title'] as String,
          stats[index]['value'] as String,
          stats[index]['icon'] as IconData,
          stats[index]['color'] as Color,
          stats[index]['change'] as String,
          index,
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      String change,
      int index,
      ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: 0.9 + (opacity * 0.1),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -50,
                    right: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
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
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                icon,
                                color: color,
                                size: 18,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                change,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value,
                              style: TextStyle(
                                fontSize: MediaQuery.of(context).size.width < 400
                                    ? 16
                                    : 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1F2937),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompanyStatsGrid(bool isMobile, bool isTablet) {
    final stats = [
      {
        'title': 'Actives',
        'value': _activeCompanies.toString(),
        'icon': Icons.check_circle,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'En Attente',
        'value': _inactiveCompanies.toString(),
        'icon': Icons.schedule,
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Bloquées',
        'value': _bannedCompanies.toString(),
        'icon': Icons.block,
        'color': const Color(0xFFEF4444),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'État des Entreprises',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: isMobile ? 3 : 3,
          crossAxisSpacing: isMobile ? 8 : 14,
          mainAxisSpacing: isMobile ? 8 : 14,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isMobile ? 1.0 : 1.2,
          children: List.generate(
            stats.length,
                (index) => _buildCompanyStatCard(
              stats[index]['title'] as String,
              stats[index]['value'] as String,
              stats[index]['icon'] as IconData,
              stats[index]['color'] as Color,
              index,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      int index,
      ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 100) + 200),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildActionButton(
      String title,
      IconData icon,
      Color color,
      int index,
      ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 100) + 600),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {},
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.1),
                      color.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsSection(bool isMobile, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistiques',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: isMobile ? 1 : isTablet ? 2 : 3,
          crossAxisSpacing: isMobile ? 10 : 16,
          mainAxisSpacing: isMobile ? 10 : 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isMobile ? 2.2 : 2.1,
          children: [
            _buildAnalyticsCard(
              'Taux d\'Utilisation',
              '${((_activeUsers / _totalUsers) * 100).toStringAsFixed(1)}%',
              'Utilisateurs actifs',
              Colors.green,
            ),
            _buildAnalyticsCard(
              'Satisfaction',
              _averageRating.toStringAsFixed(1),
              '/5.0 note moyenne',
              Colors.blue,
            ),
            _buildAnalyticsCard(
              'Croissance',
              '$_totalCompanies',
              'Total inscrites',
              Colors.purple,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(
      String title,
      String value,
      String subtitle,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}