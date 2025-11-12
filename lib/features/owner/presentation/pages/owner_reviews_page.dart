import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:frontend/features/owner/presentation/pages/owner_details_product_page.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../Core/services/review_service.dart';
import '../../../../Core/services/product_service.dart';
import '../../../../Core/services/user_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../Core/services/company_service.dart';

class OwnerReviewsPage extends StatefulWidget {
  const OwnerReviewsPage({super.key});

  @override
  State<OwnerReviewsPage> createState() => _OwnerReviewsPageState();
}

class _OwnerReviewsPageState extends State<OwnerReviewsPage> with SingleTickerProviderStateMixin {
  final ReviewService _reviewService = ReviewService();
  final ProductService _productService = ProductService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final CompanyService _companyService = CompanyService();
  final PaginationService _paginationService = PaginationService(itemsPerPage: 10);

  List<Map<String, dynamic>> _allReviews = [];
  List<Map<String, dynamic>> _filteredReviews = [];
  bool _isLoading = true;
  int? _currentUserId;

  String _selectedFilter = 'Tous';
  String _selectedCompany = 'Toutes';
  String _searchQuery = '';
  int _currentPage = 1;

  List<String> _companies = ['Toutes'];
  Map<String, int> _companyMap = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await _authService.getUserId();
    setState(() {
      _currentUserId = userId;
    });
    _loadOwnerReviews();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOwnerCompanies() async {
    try {
      if (_currentUserId == null) return;

      final companies = await _companyService.getCompanyByUserID(_currentUserId!);

      _companyMap = {
        for (var comp in companies)
          if (comp['companyName'] != null) comp['companyName'] as String: comp['companyId'] as int
      };

      _companies = [
        'Toutes',
        ...companies
            .where((c) => c['companyName'] != null)
            .map((c) => c['companyName'] as String)
      ];

      debugPrint('Loaded ${companies.length} owner companies');
    } catch (e) {
      debugPrint('Error loading owner companies: $e');
      _companies = ['Toutes'];
      _companyMap = {};
    }
  }

  Future<void> _loadOwnerReviews() async {
    try {
      setState(() => _isLoading = true);

      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Load owner companies first
      await _loadOwnerCompanies();

      final List<Map<String, dynamic>> ownerReviews = [];

      // Get owner companies
      final companies = await _companyService.getCompanyByUserID(_currentUserId!);

      // Filter companies if a specific company is selected
      List<Map<String, dynamic>> companiesToProcess = companies;
      if (_selectedCompany != 'Toutes' && _companyMap.containsKey(_selectedCompany)) {
        companiesToProcess = companies.where((c) => c['companyName'] == _selectedCompany).toList();
      }

      // Get reviews for each company
      for (var company in companiesToProcess) {
        final companyId = company['companyId'];
        if (companyId != null) {
          try {
            final companyData = await _companyService.findByCompanyIdWithReviews(companyId);

            if (companyData is Map<String, dynamic>) {
              final reviews = companyData['reviews'] as List<dynamic>?;

              if (reviews != null && reviews.isNotEmpty) {
                for (var review in reviews) {
                  final reviewMap = review as Map<String, dynamic>;
                  final productId = reviewMap['productId'];

                  if (productId != null) {
                    try {
                      final product = await _productService.getProductById(productId);
                      if (product != null) {
                        reviewMap['productName'] = product['productName'] ?? 'Produit inconnu';
                        reviewMap['productImage'] =
                        product['attachments']?.isNotEmpty ?? false
                            ? product['attachments'][0]['attachmentId']
                            : null;
                        reviewMap['companyName'] =
                            company['companyName'] ?? 'Entreprise inconnue';

                        final userId = reviewMap['userId'];
                        if (userId != null) {
                          try {
                            final user = await _userService.getUserById(userId);
                            if (user != null) {
                              reviewMap['userName'] = user['fullName'] ?? 'Utilisateur';
                              reviewMap['userEmail'] = user['email'] ?? '';
                            }
                          } catch (e) {
                            debugPrint('Error loading user data: $e');
                          }
                        }

                        ownerReviews.add(reviewMap);
                      }
                    } catch (e) {
                      debugPrint('Error loading product data: $e');
                    }
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error loading reviews for company $companyId: $e');
          }
        }
      }

      // Sort by date (newest first)
      ownerReviews.sort((a, b) {
        final aDate = a['createdAt'] as List<dynamic>?;
        final bDate = b['createdAt'] as List<dynamic>?;
        if (aDate == null || bDate == null) return 0;
        return -DateTime(
          aDate[0] as int,
          aDate[1] as int,
          aDate[2] as int,
          aDate.length > 3 ? aDate[3] as int : 0,
          aDate.length > 4 ? aDate[4] as int : 0,
          aDate.length > 5 ? aDate[5] as int : 0,
        ).compareTo(DateTime(
          bDate[0] as int,
          bDate[1] as int,
          bDate[2] as int,
          bDate.length > 3 ? bDate[3] as int : 0,
          bDate.length > 4 ? bDate[4] as int : 0,
          bDate.length > 5 ? bDate[5] as int : 0,
        ));
      });

      setState(() {
        _allReviews = ownerReviews;
        _filteredReviews = ownerReviews;
        _isLoading = false;
      });

      _applyFilters();
      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackBar('Erreur de chargement: $e', isError: true);
      }
      debugPrint('Error in _loadOwnerReviews: $e');
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allReviews);

    // Apply rating filter
    if (_selectedFilter != 'Tous') {
      final rating = int.parse(_selectedFilter.split(' ')[0]);
      filtered = filtered.where((review) => review['rating'] == rating).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((review) {
        final productName = (review['productName'] ?? '').toLowerCase();
        final userName = (review['userName'] ?? '').toLowerCase();
        final comment = (review['comment'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return productName.contains(query) || userName.contains(query) || comment.contains(query);
      }).toList();
    }

    setState(() {
      _filteredReviews = filtered;
      _currentPage = 1;
    });
  }

  double _calculateAverageRating() {
    if (_allReviews.isEmpty) return 0.0;
    final validReviews =
    _allReviews.where((r) => r['rating'] != null && r['rating'] > 0).toList();
    if (validReviews.isEmpty) return 0.0;
    final sum = validReviews.fold<int>(0, (sum, review) => sum + (review['rating'] as int));
    return sum / validReviews.length;
  }

  Map<int, int> _getRatingDistribution() {
    Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (var review in _allReviews) {
      final rating = review['rating'] as int?;
      if (rating != null && rating > 0) {
        distribution[rating] = (distribution[rating] ?? 0) + 1;
      }
    }
    return distribution;
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

  String _formatDate(List<dynamic>? dateList) {
    if (dateList == null || dateList.length < 3) return 'Date inconnue';
    final date = DateTime(dateList[0], dateList[1], dateList[2]);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Il y a $weeks ${weeks == 1 ? 'semaine' : 'semaines'}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Il y a $months ${months == 1 ? 'mois' : 'mois'}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(isMobile),
              _buildStatsCards(),
              _buildFiltersSection(isMobile),
              _filteredReviews.isEmpty
                  ? _buildEmptyState()
                  : Column(
                children: [
                  _buildReviewsList(isMobile),
                  if (_filteredReviews.isNotEmpty) _buildPaginationBar(isMobile),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Skeletonizer(
      enabled: true,
      child: Column(
        children: [
          _buildSkeletonHeader(),
          _buildSkeletonStatsCards(),
          _buildSkeletonFiltersSection(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildSkeletonReviewCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 22,
                  width: 120,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 100,
                  color: Colors.white.withOpacity(0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonStatsCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(
            3,
                (index) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index == 2 ? 0 : 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 12,
                      width: 60,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 24,
                      width: 40,
                      color: Colors.grey[300],
                    ),
                  ],
                ),
              ),
            )),
      ),
    );
  }

  Widget _buildSkeletonFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                  6,
                      (index) => Container(
                    margin: EdgeInsets.only(right: index == 5 ? 0 : 8),
                    height: 40,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonReviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 17,
                      width: 120,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 13,
                      width: 150,
                      color: Colors.grey[300],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: isMobile ? 16 : 24,
        right: isMobile ? 16 : 24,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
        ),
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
              Icons.rate_review_rounded,
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
                  'Avis Clients',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_allReviews.length} avis sur vos produits',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: isMobile ? 12 : 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadOwnerReviews,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualiser',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final avgRating = _calculateAverageRating();
    final distribution = _getRatingDistribution();
    final totalReviews = _allReviews.length;
    final positiveReviews = distribution[5]! + distribution[4]!;
    final positivePercentage = totalReviews > 0
        ? (positiveReviews / totalReviews * 100).toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.star_rounded,
              title: 'Note Moyenne',
              value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '0.0',
              subtitle: '$totalReviews avis',
              color: Colors.amber,
              gradient: [Colors.amber[400]!, Colors.amber[600]!],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.thumb_up_rounded,
              title: 'Avis Positifs',
              value: '$positivePercentage%',
              subtitle: '$positiveReviews avis (4-5★)',
              color: Colors.green,
              gradient: [Colors.green[400]!, Colors.green[600]!],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.people_rounded,
              title: 'Clients',
              value: '${_allReviews.map((r) => r['userId']).toSet().length}',
              subtitle: 'utilisateurs',
              color: Colors.blue,
              gradient: [Colors.blue[400]!, Colors.blue[600]!],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(bool isMobile) {
    final ratingFilters = ['Tous', '5 étoiles', '4 étoiles', '3 étoiles', '2 étoiles', '1 étoile'];

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: Colors.white,
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un avis, produit ou client...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    _searchQuery = '';
                    _applyFilters();
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Rating filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ratingFilters.map((filter) {
                final isSelected = _selectedFilter == filter;
                final distribution = _getRatingDistribution();
                int count = distribution[5]! +
                    distribution[4]! +
                    distribution[3]! +
                    distribution[2]! +
                    distribution[1]!;
                if (filter != 'Tous') {
                  final rating = int.parse(filter.split(' ')[0]);
                  count = distribution[rating] ?? 0;
                }

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = filter);
                    _applyFilters();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)])
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey[300]!,
                        width: isSelected ? 2 : 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          filter,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Company filter
          if (_companies.length > 1) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _companies.map((company) {
                  final isSelected = _selectedCompany == company;
                  return GestureDetector(
                    onTap: () async {
                      setState(() => _selectedCompany = company);
                      await _loadOwnerReviews();
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
              _searchQuery.isNotEmpty || _selectedFilter != 'Tous'
                  ? Icons.search_off_rounded
                  : Icons.star_border_rounded,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'Tous'
                ? 'Aucun résultat trouvé'
                : 'Aucun avis pour le moment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'Tous'
                ? 'Essayez de modifier vos filtres'
                : 'Les avis de vos clients apparaîtront ici',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[500],
            ),
          ),
          if (_searchQuery.isNotEmpty || _selectedFilter != 'Tous') ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedFilter = 'Tous';
                  _searchController.clear();
                });
                _applyFilters();
              },
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Réinitialiser les filtres'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsList(bool isMobile) {
    final paginatedReviews = _paginationService.getPageItems(_filteredReviews, _currentPage);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: paginatedReviews.length,
      itemBuilder: (context, index) {
        final review = paginatedReviews[index];
        return _buildReviewCard(review, index);
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, int index) {
    final rating = review['rating'] ?? 0;
    final comment = review['comment'] ?? '';
    final productName = review['productName'] ?? 'Produit';
    final userName = review['userName'] ?? 'Utilisateur';
    final userEmail = review['userEmail'] ?? '';
    final hasComment = comment.isNotEmpty;
    final hasRating = rating > 0;
    final createdAt = review['createdAt'] as List<dynamic>?;

    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[50]!, Colors.white],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
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
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        if (userEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            userEmail,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasRating)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.amber[400]!, Colors.amber[600]!],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '$rating.0',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Product info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: GestureDetector(
                onTap: () async {
                  final productId = review['productId'];
                  if (productId != null) {
                    await DetailsProductPage.showProductDetailsDialog(
                      context,
                      productId: productId,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Produit évalué',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              productName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Stars display
            if (hasRating)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: List.generate(5, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: index < rating ? Colors.amber[600] : Colors.grey[300],
                        size: 24,
                      ),
                    );
                  }),
                ),
              ),
            // Comment
            if (hasComment) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Commentaire',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        comment,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[800],
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (!hasComment && !hasRating) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Avis sans commentaire ni note',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar(bool isMobile) {
    final totalPages = _paginationService.getTotalPages(_filteredReviews.length);
    final startItem = (_currentPage - 1) * 10 + 1;
    final endItem = (startItem + 9 > _filteredReviews.length) ? _filteredReviews.length : startItem + 9;

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
              'Affichage $startItem-$endItem sur ${_filteredReviews.length}',
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
}