import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../widgets/owner_company_info_card.dart';
import '../widgets/owner_company_stats_card.dart';
import 'add_product_page.dart';
import 'owner_add_company_page.dart';
import 'owner_add_product_page.dart';
import 'owner_details_product_page.dart';

class CompanyPage extends StatefulWidget {
  const CompanyPage({super.key});

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> with SingleTickerProviderStateMixin {
  final CompanyService _companyService = CompanyService();
  final ProductService _productService = ProductService();
  final AttachmentService _attachmentService = AttachmentService();
  final PaginationService _paginationService = PaginationService(itemsPerPage: 8);

  List<Map<String, dynamic>> _companies = [];
  Map<String, List<Map<String, dynamic>>> _productsByCompany = {};
  Map<int, Uint8List> _imageCache = {};

  bool _isLoading = true;
  int _selectedCompanyIndex = 0;
  int _currentPage = 1;
  static const int currentUserId = 2;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final companiesData = await _companyService.getCompanyByUserID(currentUserId);
      List<Map<String, dynamic>> companiesList = [];

      if (companiesData == null) {
        companiesList = [];
      } else if (companiesData is List<dynamic>) {
        companiesList = (companiesData as List<dynamic>)
            .where((item) => item is Map<dynamic, dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      } else if (companiesData is Map<String, dynamic> || companiesData is Map<dynamic, dynamic>) {
        final dataMap = Map<String, dynamic>.from(companiesData as Map);
        if (_isCompanyObject(dataMap)) {
          companiesList = [dataMap];
        }
      }

      _productsByCompany = {};
      for (var company in companiesList) {
        final companyId = company['companyId'];
        if (companyId == null) continue;

        final companyIdInt = companyId is String
            ? int.tryParse(companyId)
            : companyId is int ? companyId : null;
        if (companyIdInt == null) continue;

        try {
          final productsData = await _productService.getProductByCompanyId(companyIdInt);
          List<Map<String, dynamic>> productsList = [];

          if (productsData == null) {
            productsList = [];
          } else if (productsData is List<dynamic>) {
            productsList = (productsData as List<dynamic>)
                .where((item) => item is Map)
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
          } else if (productsData is Map<String, dynamic> || productsData is Map<dynamic, dynamic>) {
            productsList = [Map<String, dynamic>.from(productsData as Map)];
          }

          _productsByCompany[companyId.toString()] = productsList;

          for (final product in productsList) {
            final attachments = product['attachments'] as List<dynamic>?;
            if (attachments != null && attachments.isNotEmpty) {
              final firstAttachmentId = attachments[0]['attachmentId'] as int;
              if (!_imageCache.containsKey(firstAttachmentId)) {
                _preloadImage(firstAttachmentId);
              }
            }
          }
        } catch (e) {
          _productsByCompany[companyId.toString()] = [];
        }
      }

      if (_selectedCompanyIndex >= companiesList.length) {
        _selectedCompanyIndex = 0;
      }

      setState(() {
        _companies = companiesList;
        _isLoading = false;
      });

      if (mounted) {
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Erreur de chargement: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  bool _isCompanyObject(Map<String, dynamic> map) {
    return map.containsKey('companyId') &&
        (map.containsKey('companyName') || map.containsKey('companySector'));
  }

  Future<void> _preloadImage(int attachmentId) async {
    try {
      final download = await _attachmentService.downloadAttachment(attachmentId);
      if (mounted) {
        setState(() {
          _imageCache[attachmentId] = download.data;
        });
      }
    } catch (e) {
      debugPrint('Error preloading image $attachmentId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              const Text(
                'Chargement de vos entreprises...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_companies.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: _buildNoCompanyState(context),
      );
    }

    final selectedCompany = _companies[_selectedCompanyIndex];

    return FadeTransition(
      opacity: _fadeController,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(isMobile),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_companies.length > 1) ...[
                  _buildCompanySwitcherHeader(),
                  const SizedBox(height: 16),
                  _buildCompanySwitcher(isMobile),
                  const SizedBox(height: 28),
                ],
                _buildStatsRow(isMobile),
                const SizedBox(height: 28),
                _buildCompanyInfo(selectedCompany),
                const SizedBox(height: 28),
                _buildProductsSection(context, isMobile, selectedCompany),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 70,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mon Portefeuille',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_companies.length} entreprise${_companies.length > 1 ? 's' : ''} gérée${_companies.length > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final result = await AddCompanyPage.showAddCompanyDialog(context);
                      if (result == true) {
                        _loadData();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, color: AppColors.textLight, size: 20),
                          if (!isMobile) ...[
                            const SizedBox(width: 6),
                            const Text(
                              'Ajouter',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textLight,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      final result = await AddCompanyPage.showAddCompanyDialog(
                        context,
                        companyData: _companies[_selectedCompanyIndex],
                        isEditing: true,
                      );
                      if (result == true) {
                        _loadData();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_rounded, color: AppColors.textLight, size: 20),
                          if (!isMobile) ...[
                            const SizedBox(width: 6),
                            const Text(
                              'Modifier',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textLight,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoCompanyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.business_outlined,
                size: 60,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Commencez votre aventure',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Créez votre première entreprise et commencez à gérer vos produits et services dès maintenant',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 36),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await AddCompanyPage.showAddCompanyDialog(context);
                  if (result == true) {
                    _loadData();
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 22),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: const Text(
                  'Créer une entreprise',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanySwitcherHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mes entreprises',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sélectionnez une entreprise pour voir ses détails',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanySwitcher(bool isMobile) {
    if (isMobile) {
      return SizedBox(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: 4),
          itemCount: _companies.length,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(right: index == _companies.length - 1 ? 0 : 12),
            child: SizedBox(
              width: 160,
              child: _buildCompanyCard(index, isMobile),
            ),
          ),
        ),
      );
    } else {
      return LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 4;
          if (constraints.maxWidth < 1200) crossAxisCount = 3;
          if (constraints.maxWidth < 900) crossAxisCount = 2;

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _companies.length,
            itemBuilder: (context, index) => _buildCompanyCard(index, isMobile),
          );
        },
      );
    }
  }

  Widget _buildCompanyCard(int index, bool isMobile) {
    final company = _companies[index];
    final isSelected = index == _selectedCompanyIndex;
    final productCount =
        _productsByCompany[company['companyId']?.toString()]?.length ?? 0;
    final sector = company['companySector'] ?? 'Sans secteur';
    final phone = company['companyPhone'] ?? 'N/A';

    return GestureDetector(
      onTap: () {
        setState(() => _selectedCompanyIndex = index);
        _fadeController.reset();
        _fadeController.forward();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? Colors.transparent : AppColors.border.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.35)
                    : AppColors.shadow.withOpacity(0.06),
                blurRadius: isSelected ? 20 : 12,
                offset: Offset(0, isSelected ? 8 : 3),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: isMobile ? 40 : 50,
                          height: isMobile ? 40 : 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.textLight.withOpacity(0.25)
                                : AppColors.primary.withOpacity(0.15),
                          ),
                          child: Icon(
                            Icons.business_rounded,
                            size: isMobile ? 20 : 24,
                            color: isSelected ? AppColors.textLight : AppColors.primary,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.textLight.withOpacity(0.25),
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: isMobile ? 12 : 16,
                              color: AppColors.textLight,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 10 : 14),
                    Text(
                      company['companyName'] ?? 'Entreprise',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isMobile ? 12 : 15,
                        color: isSelected ? AppColors.textLight : AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                if (!isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.textLight.withOpacity(0.2)
                              : AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sector,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? AppColors.textLight : AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: 13,
                            color: isSelected
                                ? AppColors.textLight.withOpacity(0.7)
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              phone,
                              style: TextStyle(
                                fontSize: 11,
                                color: isSelected
                                    ? AppColors.textLight.withOpacity(0.8)
                                    : AppColors.textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isMobile ? 6 : 10),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 10,
                        vertical: isMobile ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.textLight.withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.textLight.withOpacity(0.2)
                              : AppColors.primary.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            size: isMobile ? 12 : 14,
                            color: isSelected
                                ? AppColors.textLight.withOpacity(0.85)
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$productCount prod${productCount != 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 12,
                                color: isSelected
                                    ? AppColors.textLight.withOpacity(0.9)
                                    : AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isMobile) {
    final selectedCompany = _companies[_selectedCompanyIndex];
    final productCount = _productsByCompany[selectedCompany['companyId']?.toString()]?.length ?? 0;

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            CompanyStatsCard(
              title: 'Produits',
              value: '$productCount',
              icon: Icons.inventory_2_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            const CompanyStatsCard(
              title: 'Commandes',
              value: '156',
              icon: Icons.shopping_bag_outlined,
              color: AppColors.success,
            ),
            const SizedBox(width: 12),
            const CompanyStatsCard(
              title: 'Revenus',
              value: '12.4K€',
              icon: Icons.trending_up,
              color: AppColors.accent,
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: CompanyStatsCard(
            title: 'Produits',
            value: '$productCount',
            icon: Icons.inventory_2_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: CompanyStatsCard(
            title: 'Commandes',
            value: '156',
            icon: Icons.shopping_bag_outlined,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 16),
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

  Widget _buildCompanyInfo(Map<String, dynamic> company) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CompanyInfoCard(companyData: company),
    );
  }

  Widget _buildProductsSection(
      BuildContext context, bool isMobile, Map<String, dynamic> company) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;

    if (screenWidth > 1200) {
      crossAxisCount = 4;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
    } else if (screenWidth > 600) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 2;
    }

    final companyProducts = _productsByCompany[company['companyId']?.toString()] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Produits',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${companyProducts.length} produit${companyProducts.length != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AddProductDialog(
                        onProductAdded: _loadData,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, color: AppColors.textLight, size: 18),
                        if (!isMobile) ...[
                          const SizedBox(width: 8),
                          const Text(
                            'Nouveau produit',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textLight,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          constraints: BoxConstraints(
            minHeight: companyProducts.isEmpty ? 220 : 0,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: companyProducts.isEmpty
              ? _buildEmptyState()
              : Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: companyProducts.length,
              itemBuilder: (context, index) {
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
                  child: _buildProductCard(companyProducts[index]),
                );
              },
            ),
          ),
        ),
      ],
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
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucun produit disponible',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Commencez à ajouter vos produits',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final productId = product['productId'] ?? 0;
    final hasDiscount = (product['discountPercentage'] ?? 0) > 0;
    final discountPercent = (product['discountPercentage'] ?? 0).toInt();
    final originalPrice = product['productPrice']?.toDouble() ?? 0.0;
    final finalPrice = product['productFinalePrice']?.toDouble() ?? originalPrice;
    final attachments = product['attachments'] as List<dynamic>?;
    final int? firstAttachmentId = attachments != null && attachments.isNotEmpty
        ? attachments[0]['attachmentId'] as int
        : null;
    final isAvailable = product['available'] ?? true;
    final productName = product['productName'] ?? 'Produit sans nom';
    final productDescription = product['productDescription'] ?? '';

    return GestureDetector(
      onTap: () async {
        final result = await DetailsProductPage.showProductDetailsDialog(
          context,
          productId: productId,
        );
        if (result == true) {
          _loadData();
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
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
              // Image Section
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: _buildProductImage(firstAttachmentId),
                    ),
                    // Status Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAvailable ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (isAvailable ? Colors.green : Colors.red).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAvailable ? Icons.check_circle : Icons.cancel,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAvailable ? 'En stock' : 'Épuisé',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Discount Badge
                    if (hasDiscount)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.red[400]!, Colors.red[600]!],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                '-$discountPercent%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Content Section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Tooltip(
                        message: productName,
                        child: Text(
                          productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Product Description
                      if (productDescription.isNotEmpty)
                        Text(
                          productDescription.length > 50
                              ? '${productDescription.substring(0, 50)}...'
                              : productDescription,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const Spacer(),
                      // Price Section
                      Row(
                        children: [
                          if (hasDiscount) ...[
                            Text(
                              '${originalPrice.toStringAsFixed(2)} DT',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              hasDiscount
                                  ? '${finalPrice.toStringAsFixed(2)} DT'
                                  : '${originalPrice.toStringAsFixed(2)} DT',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: hasDiscount ? Colors.green[600] : AppColors.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(int? attachmentId) {
    if (attachmentId == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.grey[100],
        child: Icon(
          Icons.inventory_2_rounded,
          size: 48,
          color: Colors.grey[400],
        ),
      );
    }

    if (_imageCache.containsKey(attachmentId)) {
      return Image.memory(
        _imageCache[attachmentId]!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return FutureBuilder<dynamic>(
      future: _attachmentService.downloadAttachment(attachmentId),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data;
          Uint8List? imageData;

          if (data is Uint8List) {
            imageData = data;
          } else if (data.runtimeType.toString().contains('AttachmentDownload')) {
            imageData = data.data;
          }

          if (imageData != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _imageCache[attachmentId] = imageData!;
                });
              }
            });
            return Image.memory(
              imageData,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            );
          }
        } else if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[100],
            child: Icon(
              Icons.broken_image_rounded,
              size: 48,
              color: Colors.grey[400],
            ),
          );
        }
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.grey[100],
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        );
      },
    );
  }
}