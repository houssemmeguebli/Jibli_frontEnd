import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/product_service.dart';
import '../widgets/company_info_card.dart';
import '../widgets/company_stats_card.dart';
import 'edit_company_page.dart';
import 'add_product_page.dart';

class CompanyPage extends StatefulWidget {
  const CompanyPage({super.key});

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  final CompanyService _companyService = CompanyService();
  final ProductService _productService = ProductService();
  Map<String, dynamic>? _companyData;
  List<Map<String, dynamic>> _companyProducts = [];
  bool _isLoading = true;
  static const int currentUserId = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final company = await _companyService.getCompanyByUserID(currentUserId.toString());
      if (company != null) {
        final products = await _companyService.getCompanyProducts(company['id'].toString());
        setState(() {
          _companyData = company;
          _companyProducts = products;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_companyData == null) {
      return _buildNoCompanyState(context);
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 20),
          _buildStatsRow(),
          const SizedBox(height: 20),
          _buildCompanyInfo(),
          const SizedBox(height: 20),
          _buildProductsSection(context),
        ],
      ),
    );
  }

  Widget _buildNoCompanyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.business_outlined, size: 64, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text(
            'Aucune entreprise trouvée',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Créez votre entreprise pour commencer',
            style: TextStyle(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Créer une entreprise'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Profil de l\'entreprise',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditCompanyPage(companyData: _companyData!),
              ),
            ),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Modifier l\'entreprise'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.textLight,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: CompanyStatsCard(
            title: 'Produits',
            value: '${_companyProducts.length}',
            icon: Icons.inventory_2_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 15),
        const Expanded(
          child: CompanyStatsCard(
            title: 'Commandes',
            value: '156',
            icon: Icons.shopping_bag_outlined,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 15),
        const Expanded(
          child: CompanyStatsCard(
            title: 'Revenus',
            value: '12.4K€',
            icon: Icons.trending_up,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyInfo() {
    return CompanyInfoCard(companyData: _companyData!);
  }

  Widget _buildProductsSection(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Produits de l\'entreprise',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddProductPage()),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter un produit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppColors.textLight,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _companyProducts.isEmpty
                  ? _buildEmptyState()
                  : _buildProductsGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text(
            'Aucun produit trouvé',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
          ),
          SizedBox(height: 8),
          Text(
            'Ajoutez votre premier produit pour commencer',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.8,
      ),
      itemCount: _companyProducts.length,
      itemBuilder: (context, index) => _buildProductCard(_companyProducts[index]),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final hasDiscount = product['discount'] > 0;
    final finalPrice = hasDiscount 
        ? product['price'] * (1 - product['discount'] / 100)
        : product['price'];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.surfaceVariant, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Icon(Icons.inventory_2_rounded, size: 40, color: AppColors.primary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (hasDiscount) ...[
                    Text(
                      '\$${product['price'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '\$${finalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                        fontSize: 14,
                      ),
                    ),
                  ] else
                    Text(
                      '\$${product['price'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: product['available'] ? AppColors.success.withOpacity(0.1) : AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product['available'] ? 'Disponible' : 'Épuisé',
                      style: TextStyle(
                        color: product['available'] ? AppColors.success : AppColors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}