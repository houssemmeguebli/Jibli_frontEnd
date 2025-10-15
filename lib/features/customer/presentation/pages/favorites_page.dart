import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/user_company_service.dart';
import '../../../../core/services/company_service.dart';
import '../widgets/company_card.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final UserCompanyService _userCompanyService = UserCompanyService();
  final CompanyService _companyService = CompanyService();
  
  List<Map<String, dynamic>> _favoriteCompanies = [];
  bool _isLoading = true;
  
  // Mock user ID - in real app, get from auth service
  final int _currentUserId = 1;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final userCompanies = await _userCompanyService.getUserCompaniesByUser(_currentUserId);
      final List<Map<String, dynamic>> favorites = [];
      
      for (final userCompany in userCompanies) {
        if (userCompany['isFavorite'] == true) {
          final company = await _companyService.getCompanyById(userCompany['companyId']);
          if (company != null) {
            favorites.add(company);
          }
        }
      }
      
      setState(() {
        _favoriteCompanies = favorites;
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
                'Mes Favoris',
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
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {},
                ),
              ],
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _favoriteCompanies.isEmpty
                ? _buildEmptyState()
                : _buildFavoritesList(),
      ),
    );
  }

  Widget _buildFavoritesList() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_favoriteCompanies.length} restaurant${_favoriteCompanies.length > 1 ? 's' : ''} favori${_favoriteCompanies.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final company = _favoriteCompanies[index];
                return CompanyCard(
                  name: company['name'] ?? 'Restaurant',
                  category: company['category'] ?? 'Restaurant',
                  rating: (company['rating'] ?? 4.0).toDouble(),
                  imageUrl: company['imageUrl'] ?? 'https://via.placeholder.com/200x150/00A878/FFFFFF?text=Restaurant',
                  deliveryFee: company['deliveryFee'] ?? 'Gratuit',
                  isFavorite: true,
                );
              },
              childCount: _favoriteCompanies.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.favorite_outline_rounded,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Aucun favori pour le moment',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Ajoutez vos restaurants préférés en appuyant sur le cœur pour les retrouver facilement ici.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to home page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: AppColors.textLight,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore_rounded),
                    const SizedBox(width: 8),
                    const Text(
                      'Découvrir des restaurants',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
}