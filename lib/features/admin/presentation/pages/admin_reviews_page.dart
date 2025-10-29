import 'package:flutter/material.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/review_service.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/product_service.dart';

class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key});

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState extends State<AdminReviewsPage> {
  final ReviewService _reviewService = ReviewService();
  final CompanyService _companyService = CompanyService();
  final ProductService _productService = ProductService();
  final PaginationService _paginationService = PaginationService(itemsPerPage: 10);

  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _filteredReviews = [];
  Map<int, Map<String, dynamic>> _companiesCache = {};
  Map<int, Map<String, dynamic>> _productsCache = {};
  bool _isLoading = true;
  String _selectedRating = 'Toutes';
  String _selectedStatus = 'Tous';
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _ratings = ['Toutes', '5', '4', '3', '2', '1'];
  final List<String> _statuses = ['Tous', 'Publié', 'En attente', 'Rejeté'];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _reviewService.getAllReviews();
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _filteredReviews = reviews;
          _isLoading = false;
        });
      }

      // Preload companies and products data
      _preloadCompaniesAndProducts(reviews);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      _showErrorSnackBar('Erreur: $e');
    }
  }

  Future<void> _preloadCompaniesAndProducts(List<Map<String, dynamic>> reviews) async {
    final companyIds = <int>{};
    final productIds = <int>{};

    for (var review in reviews) {
      if (review['companyId'] != null) {
        companyIds.add(review['companyId'] as int);
      }
      if (review['productId'] != null) {
        productIds.add(review['productId'] as int);
      }
    }

    // Load companies
    for (var companyId in companyIds) {
      try {
        final company = await _companyService.getCompanyById(companyId);
        if (mounted) {
          setState(() {
            _companiesCache[companyId] = company!;
          });
        }
      } catch (e) {
        debugPrint('Error loading company $companyId: $e');
      }
    }

    // Load products
    for (var productId in productIds) {
      try {
        final product = await _productService.getProductById(productId);
        if (mounted) {
          setState(() {
            _productsCache[productId] = product!;
          });
        }
      } catch (e) {
        debugPrint('Error loading product $productId: $e');
      }
    }
  }

  void _filterReviews() {
    if (mounted) {
      setState(() {
        _filteredReviews = _reviews.where((review) {
          final matchesRating = _selectedRating == 'Toutes' ||
              review['rating'].toString() == _selectedRating;
          final matchesStatus = _selectedStatus == 'Tous' ||
              (review['status']?.toString() ?? 'Publié') == _selectedStatus;
          final matchesSearch = _searchController.text.isEmpty ||
              review['comment'].toString().toLowerCase().contains(_searchController.text.toLowerCase()) ||
              review['userId'].toString().contains(_searchController.text);
          return matchesRating && matchesStatus && matchesSearch;
        }).toList();
        _currentPage = 1;
      });
    }
  }

  Future<void> _deleteReview(int reviewId) async {
    try {
      await _reviewService.deleteReview(reviewId);
      _loadReviews();
      _showSuccessSnackBar('Avis supprimé avec succès');
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isMobile),
            const SizedBox(height: 24),
            _buildStatsCards(isMobile),
            const SizedBox(height: 24),
            _buildFilters(isMobile, isTablet),
            const SizedBox(height: 24),
            _buildReviewsList(isMobile),
            if (!_isLoading && _filteredReviews.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildPaginationBar(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestion des Avis',
          style: TextStyle(
            fontSize: isMobile ? 28 : 32,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2937),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'Modérez et gérez les avis clients',
              style: TextStyle(
                fontSize: isMobile ? 14 : 15,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                '${_filteredReviews.length} avis',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCards(bool isMobile) {
    final totalReviews = _reviews.length;
    final avgRating = _calculateAverageRating();
    final fiveStarCount = _reviews.where((r) => (r['rating'] as int? ?? 0) == 5).length;
    final oneStarCount = _reviews.where((r) => (r['rating'] as int? ?? 0) == 1).length;

    return isMobile
        ? Column(
      children: [
        _buildStatCard('Total Avis', '$totalReviews', Colors.blue, Icons.rate_review),
        const SizedBox(height: 12),
        _buildStatCard('Note Moyenne', '${avgRating.toStringAsFixed(1)}/5', Colors.amber, Icons.star),
        const SizedBox(height: 12),
        _buildStatCard('Excellent', '$fiveStarCount', Colors.green, Icons.thumb_up),
        const SizedBox(height: 12),
        _buildStatCard('Faible', '$oneStarCount', Colors.red, Icons.thumb_down),
      ],
    )
        : Row(
      children: [
        Expanded(
          child: _buildStatCard('Total Avis', '$totalReviews', Colors.blue, Icons.rate_review),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('Note Moyenne', '${avgRating.toStringAsFixed(1)}/5', Colors.amber, Icons.star),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('Excellent', '$fiveStarCount', Colors.green, Icons.thumb_up),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('Faible', '$oneStarCount', Colors.red, Icons.thumb_down),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateAverageRating() {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<int>(0, (acc, r) => acc + (r['rating'] as int? ?? 0));
    return sum / _reviews.length;
  }

  Widget _buildFilters(bool isMobile, bool isTablet) {
    return Column(
      children: [
        if (isMobile)
          Column(
            children: [
              _buildSearchField(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildRatingFilter()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatusFilter()),
                ],
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(flex: 2, child: _buildSearchField()),
              const SizedBox(width: 12),
              Expanded(child: _buildRatingFilter()),
              const SizedBox(width: 12),
              Expanded(child: _buildStatusFilter()),
            ],
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _filterReviews(),
        decoration: InputDecoration(
          hintText: 'Rechercher les avis...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(Icons.search, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildRatingFilter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: _selectedRating,
        underline: const SizedBox(),
        isExpanded: true,
        items: _ratings.map((rating) {
          return DropdownMenuItem(
            value: rating,
            child: Row(
              children: [
                if (rating != 'Toutes') ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(int.parse(rating), (index) {
                      return const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Icon(Icons.star, color: Colors.amber, size: 14),
                      );
                    }),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  rating == 'Toutes' ? 'Toutes les notes' : '$rating',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (mounted) {
            setState(() {
              _selectedRating = value!;
            });
          }
          _filterReviews();
        },
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: _selectedStatus,
        underline: const SizedBox(),
        isExpanded: true,
        items: _statuses.map((status) {
          return DropdownMenuItem(
            value: status,
            child: Text(
              status,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (mounted) {
            setState(() {
              _selectedStatus = value!;
            });
          }
          _filterReviews();
        },
      ),
    );
  }

  Widget _buildReviewsList(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isLoading
          ? const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator()),
      )
          : _filteredReviews.isEmpty
          ? _buildEmptyState()
          : _buildReviewsContent(isMobile),
    );
  }

  Widget _buildReviewsContent(bool isMobile) {
    final paginatedReviews = _paginationService.getPageItems(_filteredReviews, _currentPage);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: paginatedReviews.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]),
      itemBuilder: (context, index) {
        final review = paginatedReviews[index];
        return isMobile
            ? _buildMobileReviewCard(review)
            : _buildDesktopReviewCard(review);
      },
    );
  }

  Widget _buildDesktopReviewCard(Map<String, dynamic> review) {
    final rating = review['rating'] as int? ?? 0;
    final comment = review['comment'] ?? '';
    final reviewId = review['id'] as int? ?? review['reviewId'] as int? ?? 0;
    final status = review['status'] ?? 'Publié';
    final userId = review['userId'] ?? 'N/A';
    final productId = review['productId'] as int?;
    final companyId = review['companyId'] as int?;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              '$userId'.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'User #$userId',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildRatingDisplay(rating),
                    const Spacer(),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  comment,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (companyId != null)
                      _buildCompanyBadge(companyId)
                    else
                      const SizedBox.shrink(),
                    if (companyId != null && productId != null)
                      const SizedBox(width: 8)
                    else
                      const SizedBox.shrink(),
                    if (productId != null)
                      _buildProductBadge(productId)
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Actions
          _buildActionButtons(reviewId),
        ],
      ),
    );
  }

  Widget _buildMobileReviewCard(Map<String, dynamic> review) {
    final rating = review['rating'] as int? ?? 0;
    final comment = review['comment'] ?? '';
    final reviewId = review['id'] as int? ?? review['reviewId'] as int? ?? 0;
    final status = review['status'] ?? 'Publié';
    final userId = review['userId'] ?? 'N/A';
    final productId = review['productId'] as int?;
    final companyId = review['companyId'] as int?;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  '$userId'.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User #$userId',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    _buildRatingDisplay(rating),
                  ],
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (companyId != null) _buildCompanyBadge(companyId),
                if (companyId != null && productId != null) const SizedBox(width: 8),
                if (productId != null) _buildProductBadge(productId),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showDeleteDialog(reviewId),
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('Supprimer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyBadge(int companyId) {
    final company = _companiesCache[companyId];
    final companyName = company?['name'] ?? 'Entreprise #$companyId';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business, size: 12, color: Colors.blue[700]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              companyName,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductBadge(int productId) {
    final product = _productsCache[productId];
    final productName = product?['name'] ?? 'Produit #$productId';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag, size: 12, color: Colors.green[700]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              productName,
              style: TextStyle(
                fontSize: 11,
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDisplay(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 16,
          ),
        );
      }),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor = Colors.grey;
    Color textColor = Colors.grey[700]!;
    IconData icon = Icons.info;

    if (status == 'Publié') {
      bgColor = Colors.green;
      textColor = Colors.green;
      icon = Icons.check_circle;
    } else if (status == 'En attente') {
      bgColor = Colors.orange;
      textColor = Colors.orange;
      icon = Icons.schedule;
    } else if (status == 'Rejeté') {
      bgColor = Colors.red;
      textColor = Colors.red;
      icon = Icons.cloud_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bgColor.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(int reviewId) {
    return Tooltip(
      message: 'Supprimer cet avis',
      child: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () => _showDeleteDialog(reviewId),
        color: Colors.red,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rate_review_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun avis trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez de modifier vos filtres de recherche',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    final totalPages = _paginationService.getTotalPages(_filteredReviews.length);
    final startItem = (_currentPage - 1) * 10 + 1;
    final endItem = (startItem + 9 > _filteredReviews.length) ? _filteredReviews.length : startItem + 9;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage $startItem-$endItem sur ${_filteredReviews.length}',
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
                    ? () {
                        if (mounted) setState(() => _currentPage--);
                      }
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
                    ? () {
                        if (mounted) setState(() => _currentPage++);
                      }
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

  void _showDeleteDialog(int reviewId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet avis ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReview(reviewId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}