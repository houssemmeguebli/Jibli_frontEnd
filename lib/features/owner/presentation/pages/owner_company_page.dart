import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'dart:typed_data';
import '../../../../Core/services/auth_service.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/product_service.dart';
import '../../../../core/services/attachment_service.dart';
import '../widgets/owner_company_info_card.dart';
import '../widgets/owner_company_stats_card.dart';
import 'owner_add_product_page.dart';
import 'owner_add_company_page.dart';
import 'owner_details_product_page.dart';
import 'owner_edit_company_page.dart';

class CompanyPage extends StatefulWidget {
  const CompanyPage({super.key});

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> with SingleTickerProviderStateMixin {
  final CompanyService _companyService = CompanyService();
  final ProductService _productService = ProductService();
  final AttachmentService _attachmentService = AttachmentService();
  final PaginationService _paginationService = PaginationService(itemsPerPage: 10);
  final AuthService _authService = AuthService();


  List<Map<String, dynamic>> _companies = [];
  Map<String, List<Map<String, dynamic>>> _productsByCompany = {};
  Map<int, Uint8List> _productImageCache = {};
  Map<int, List<Uint8List>> _companyImages = {};

  bool _isLoading = true;
  int _selectedCompanyIndex = 0;
  int _currentPage = 1;
  int? currentUserId;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadCurrentUserId();
  }
  Future<void> _loadCurrentUserId() async {
    final userId = await _authService.getUserId();
    setState(() {
      currentUserId = userId;
    });
    if (userId != null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final companiesData = await _companyService.getCompanyByUserID(currentUserId!);
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

      await _loadCompaniesImages(companiesList);
      await _loadProductImages();

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
  Future<void> _loadCompaniesImages(List<Map<String, dynamic>> companies) async {
    try {
      for (var company in companies) {
        final companyId = company['companyId'] as int?;
        if (companyId == null) continue;

        try {
          final attachments = await _attachmentService.getAttachmentsByEntity(
            'COMPANY',
            companyId,
          );

          final List<Uint8List> images = [];

          for (var attach in attachments) {
            try {
              final attachmentId = attach['attachmentId'] as int?;
              if (attachmentId != null) {
                final attachmentDownload = await _attachmentService.downloadAttachment(attachmentId);
                if (attachmentDownload.data.isNotEmpty) {
                  images.add(attachmentDownload.data);
                }
              }
            } catch (e) {
              debugPrint('⚠️ Error downloading company attachment: $e');
            }
          }

          if (mounted && images.isNotEmpty) {
            setState(() {
              _companyImages[companyId] = images;
            });
          }
        } catch (e) {
          debugPrint('❌ Error loading images for company $companyId: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading companies images: $e');
    }
  }

  Future<void> _loadProductImages() async {
    try {
      final Map<int, Uint8List> images = {};

      for (var company in _companies) {
        final companyId = company['companyId'];
        if (companyId == null) continue;

        final products = _productsByCompany[companyId.toString()] ?? [];
        for (var product in products) {
          final productId = product['productId'] as int?;
          if (productId == null) continue;

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
            continue;
          }
        }
      }

      if (mounted) {
        setState(() {
          _productImageCache  = images;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading product images: $e');
    }
  }

  bool _isCompanyObject(Map<String, dynamic> map) {
    return map.containsKey('companyId') &&
        (map.containsKey('companyName') || map.containsKey('companySector'));
  }


  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildSkeletonAppBar(isMobile),
        body: Skeletonizer(
          enabled: true,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 24,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSkeletonStatsRow(isMobile),
                  const SizedBox(height: 28),
                  _buildSkeletonCompanyInfo(),
                  const SizedBox(height: 28),
                  _buildSkeletonProductsSection(isMobile),
                ],
              ),
            ),
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
      toolbarHeight: isMobile ? 80 : 90,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mon Espace',
                      style: TextStyle(
                        fontSize: isMobile ? 22 : 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.business_rounded,
                            size: 12,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_companies.length} entreprise${_companies.length > 1 ? 's' : ''} gérée${_companies.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) const SizedBox(width: 20),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: isMobile ? 12 : 20, top: 8, bottom: 8),
          child: Row(
            children: [
              // Add Company Button
              _buildAppBarActionButton(
                label: 'Ajouter',
                icon: Icons.add_rounded,
                gradient: AppColors.accentGradient,
                color: AppColors.accent,
                isMobile: isMobile,
                onTap: () async {
                  final result = await AddCompanyPage.showAddCompanyDialog(context);
                  if (result == true) {
                    _loadData();
                  }
                },
              ),
              SizedBox(width: isMobile ? 8 : 12),
              // Edit Company Button
              _buildAppBarActionButton(
                label: 'Modifier',
                icon: Icons.edit_rounded,
                gradient: AppColors.primaryGradient,
                color: AppColors.primary,
                isMobile: isMobile,
                onTap: () async {
                  if (_companies.isNotEmpty) {
                    final selectedCompany = _companies[_selectedCompanyIndex];
                    final result = await EditCompanyPage.showEditCompanyDialog(context, selectedCompany);
                    if (result == true) {
                      _loadData();
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBarActionButton({
    required String label,
    required IconData icon,
    required Gradient gradient,
    required Color color,
    required bool isMobile,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: AppColors.textLight,
                  size: isMobile ? 18 : 20,
                ),
                if (!isMobile) ...[
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'ACTIVE':
        return {
          'label': 'Actif',
          'color': Color(0xFF10B981),
          'icon': Icons.check_circle_rounded,
          'message': 'Votre entreprise est active',
        };
      case 'INACTIVE':
        return {
          'label': 'En Attente',
          'color': Color(0xFFF59E0B),
          'icon': Icons.schedule_rounded,
          'message': 'En attente d\'activation par l\'admin',
        };
      case 'BANNED':
        return {
          'label': 'Bloqué',
          'color': Color(0xFFEF4444),
          'icon': Icons.block_rounded,
          'message':
          'Votre entreprise a été bloquée. Veuillez contacter l\'administrateur.',
        };
      default:
        return {
          'label': 'Inconnu',
          'color': Colors.grey,
          'icon': Icons.help_outline_rounded,
          'message': 'Statut inconnu',
        };
    }
  }
  Widget _buildCompanyCard(int index, bool isMobile) {
    final company = _companies[index];
    final isSelected = index == _selectedCompanyIndex;
    final sector = company['companySector'] ?? 'Sans secteur';
    final status = company['companyStatus'] ?? 'INACTIVE';
    final statusInfo = _getStatusInfo(status);
    final companyId = company['companyId'] as int?;
    final companyImages = companyId != null ? _companyImages[companyId] : null;
    final firstImage = companyImages != null && companyImages.isNotEmpty
        ? companyImages.first
        : null;

    return GestureDetector(
        onTap: () {
          setState(() => _selectedCompanyIndex = index);
          _fadeController.reset();
          _fadeController.forward();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: isSelected ? 1 : 0),
            duration: const Duration(milliseconds: 400),
            builder: (context, value, child) {
              return Transform.scale(
                  scale: 1 + (value * 0.03),
                  child: Opacity(
                    opacity: 0.8 + (value * 0.2),
                    child: child,
                  )
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? (statusInfo['color'] as Color).withOpacity(0.3)
                        : Colors.black.withOpacity(0.06),
                    blurRadius: isSelected ? 32 : 16,
                    offset: Offset(0, isSelected ? 16 : 6),
                    spreadRadius: isSelected ? 2 : 0,
                  ),
                  if (isSelected)
                    BoxShadow(
                      color: (statusInfo['color'] as Color).withOpacity(0.15),
                      blurRadius: 48,
                      offset: const Offset(0, 0),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Background image or gradient
                    if (firstImage != null)
                      Positioned.fill(
                        child: Image.memory(
                          firstImage,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                (statusInfo['color'] as Color)
                                    .withOpacity(0.95),
                                (statusInfo['color'] as Color)
                                    .withOpacity(0.75),
                              ],
                              stops: const [0.0, 1.0],
                            )
                                : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Colors.grey[50]!,
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Dark overlay for better text visibility when image exists
                    if (firstImage != null)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.2),
                                Colors.black.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Animated accent orb
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      top: isSelected ? -40 : -80,
                      right: isSelected ? -40 : -80,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              (statusInfo['color'] as Color).withOpacity(0.25),
                              (statusInfo['color'] as Color).withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Secondary accent orb
                    if (isSelected)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 700),
                        bottom: -60,
                        left: -60,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.1),
                                Colors.white.withOpacity(0.02),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Content
                    Padding(
                      padding: EdgeInsets.all(isMobile ? 16 : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with icon and check
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Business icon
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: isMobile ? 42 : 50,
                                height: isMobile ? 42 : 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: isSelected
                                      ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.1),
                                    ],
                                  )
                                      : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      (statusInfo['color'] as Color)
                                          .withOpacity(0.2),
                                      (statusInfo['color'] as Color)
                                          .withOpacity(0.1),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.3)
                                        : (statusInfo['color'] as Color)
                                        .withOpacity(0.2),
                                  ),
                                ),
                                child: Icon(
                                  Icons.business_rounded,
                                  size: isMobile ? 20 : 26,
                                  color: isSelected ? Colors.white : statusInfo['color'],
                                ),
                              ),

                              // Check indicator
                              if (isSelected)
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.4),
                                        Colors.white.withOpacity(0.2),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),

                          SizedBox(height: isMobile ? 12 : 16),

                          // Company name with gradient text when selected
                          ShaderMask(
                            shaderCallback: (bounds) {
                              if (!isSelected && firstImage == null) {
                                return const LinearGradient(colors: [Colors.black])
                                    .createShader(bounds);
                              }
                              return LinearGradient(
                                colors: [Colors.white, Colors.white.withOpacity(0.8)],
                              ).createShader(bounds);
                            },
                            child: Text(
                              company['companyName'] ?? 'Entreprise',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: isMobile ? 13 : 16,
                                color: (isSelected || firstImage != null)
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                letterSpacing: -0.5,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          if (!isMobile) ...[
                            SizedBox(height: isMobile ? 8 : 10),

                            // Sector badge with glassmorphism
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isSelected
                                      ? [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.08),
                                  ]
                                      : firstImage != null
                                      ? [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.08),
                                  ]
                                      : [
                                    AppColors.primary.withOpacity(0.12),
                                    AppColors.primary.withOpacity(0.06),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.25)
                                      : firstImage != null
                                      ? Colors.white.withOpacity(0.3)
                                      : AppColors.primary.withOpacity(0.25),
                                ),
                              ),
                              child: Text(
                                sector,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: (isSelected || firstImage != null)
                                      ? Colors.white.withOpacity(0.92)
                                      : AppColors.textTertiary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],

                          SizedBox(height: isMobile ? 10 : 12),

                          // Status message
                          if (!isMobile)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isSelected
                                      ? [
                                    Colors.white.withOpacity(0.12),
                                    Colors.white.withOpacity(0.06),
                                  ]
                                      : firstImage != null
                                      ? [
                                    Colors.white.withOpacity(0.12),
                                    Colors.white.withOpacity(0.06),
                                  ]
                                      : [
                                    (statusInfo['color'] as Color)
                                        .withOpacity(0.1),
                                    (statusInfo['color'] as Color)
                                        .withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.2)
                                      : firstImage != null
                                      ? Colors.white.withOpacity(0.2)
                                      : (statusInfo['color'] as Color)
                                      .withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                statusInfo['message'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: (isSelected || firstImage != null)
                                      ? Colors.white.withOpacity(0.88)
                                      : (statusInfo['color'] as Color)
                                      .withOpacity(0.82),
                                  height: 1.4,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          SizedBox(height: isMobile ? 10 : 12),

                          // Status and delivery fee row
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 8 : 10,
                                    vertical: isMobile ? 6 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isSelected
                                          ? [
                                        Colors.white.withOpacity(0.15),
                                        Colors.white.withOpacity(0.08),
                                      ]
                                          : firstImage != null
                                          ? [
                                        Colors.white.withOpacity(0.15),
                                        Colors.white.withOpacity(0.08),
                                      ]
                                          : [
                                        (statusInfo['color'] as Color)
                                            .withOpacity(0.12),
                                        (statusInfo['color'] as Color)
                                            .withOpacity(0.06),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.2)
                                          : firstImage != null
                                          ? Colors.white.withOpacity(0.3)
                                          : (statusInfo['color'] as Color)
                                          .withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        statusInfo['icon'] as IconData,
                                        size: isMobile ? 11 : 13,
                                        color: isSelected || firstImage != null
                                            ? Colors.white
                                            : statusInfo['color'],
                                      ),
                                      SizedBox(width: isMobile ? 4 : 6),
                                      Expanded(
                                        child: Text(
                                          statusInfo['label'] as String,
                                          style: TextStyle(
                                            fontSize: isMobile ? 9 : 10,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected || firstImage != null
                                                ? Colors.white
                                                : statusInfo['color'],
                                            letterSpacing: 0.1,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 8 : 10,
                                    vertical: isMobile ? 6 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isSelected
                                          ? [
                                        Colors.white.withOpacity(0.15),
                                        Colors.white.withOpacity(0.08),
                                      ]
                                          : firstImage != null
                                          ? [
                                        Colors.white.withOpacity(0.15),
                                        Colors.white.withOpacity(0.08),
                                      ]
                                          : [
                                        AppColors.accent.withOpacity(0.12),
                                        AppColors.accent.withOpacity(0.06),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white.withOpacity(0.2)
                                          : firstImage != null
                                          ? Colors.white.withOpacity(0.3)
                                          : AppColors.accent.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_shipping_rounded,
                                        size: isMobile ? 11 : 13,
                                        color: isSelected || firstImage != null
                                            ? Colors.white
                                            : AppColors.accent,
                                      ),
                                      SizedBox(width: isMobile ? 4 : 6),
                                      Expanded(
                                        child: Text(
                                          '${(company['deliveryFee'] ?? 0).toStringAsFixed(1)} DT',
                                          style: TextStyle(
                                            fontSize: isMobile ? 9 : 10,
                                            fontWeight: FontWeight.w700,
                                            color: isSelected || firstImage != null
                                                ? Colors.white
                                                : AppColors.accent,
                                            letterSpacing: 0.1,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
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
          ),
        ));

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
    double childAspectRatio;

    if (isMobile) {
      crossAxisCount = 2;
      childAspectRatio = 0.65;
    } else {
      final screenWidth = MediaQuery.of(context).size.width;
      if (screenWidth > 1200) {
        crossAxisCount = 4;
        childAspectRatio = 0.75;
      } else if (screenWidth > 800) {
        crossAxisCount = 3;
        childAspectRatio = 0.75;
      } else {
        crossAxisCount = 2;
        childAspectRatio = 0.75;
      }
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
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: isMobile ? 10 : 16,
                          mainAxisSpacing: isMobile ? 10 : 16,
                          childAspectRatio: childAspectRatio,
                        ),
                        itemCount: _paginationService.getPageItems(companyProducts, _currentPage).length,
                        itemBuilder: (context, index) {
                          final paginatedProducts = _paginationService.getPageItems(companyProducts, _currentPage);
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
                            child: _buildProductCard(paginatedProducts[index], isMobile),
                          );
                        },
                      ),
                    ),
                    if (companyProducts.length > 10)
                      Padding(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        child: _buildPaginationBar(isMobile, companyProducts),
                      ),
                  ],
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

  Widget _buildProductCard(Map<String, dynamic> product, bool isMobile) {
    final productId = product['productId'] ?? 0;
    final hasDiscount = (product['discountPercentage'] ?? 0) > 0;
    final originalPrice = product['productPrice']?.toDouble() ?? 0.0;
    final finalPrice = product['productFinalePrice']?.toDouble() ?? originalPrice;
    final isAvailable = product['available'] ?? true;

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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
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
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(isMobile ? 16 : 20),
                    ),
                    child: _buildProductImage(productId),
                  ),
                  // Status Badge
                  Positioned(
                    top: isMobile ? 8 : 12,
                    left: isMobile ? 8 : 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 10,
                        vertical: isMobile ? 4 : 6,
                      ),
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
                      child: Text(
                        isAvailable ? 'Disponible' : 'Épuisé',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 9 : 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Discount Badge
                  if (hasDiscount)
                    Positioned(
                      top: isMobile ? 8 : 12,
                      right: isMobile ? 8 : 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 6,
                        ),
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
                        child: Text(
                          '-${product['discountPercentage']}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 10 : 11,
                            fontWeight: FontWeight.w800,
                          ),
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
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['productName'] ?? 'Produit sans nom',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isMobile ? 14 : 16,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (product['productDescription'] != null)
                      Expanded(
                        child: Text(
                          product['productDescription'].toString().length > 50
                              ? '${product['productDescription'].toString().substring(0, 50)}...'
                              : product['productDescription'].toString(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: isMobile ? 11 : 12,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        if (hasDiscount) ...[
                          Expanded(
                            child: Text(
                              '${originalPrice.toStringAsFixed(2)} DT',
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey[500],
                                fontSize: isMobile ? 11 : 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            hasDiscount
                                ? '${finalPrice.toStringAsFixed(2)} DT'
                                : '${originalPrice.toStringAsFixed(2)} DT',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: isMobile ? 14 : 16,
                              color: hasDiscount ? Colors.green[600] : AppColors.accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildProductImage(int? productId) {
    if (productId == null) {
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

    if (_productImageCache .containsKey(productId)) {
      return Image.memory(
        _productImageCache[productId]!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheHeight: 500,
        cacheWidth: 500,
      );
    }

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

  Widget _buildPaginationBar(bool isMobile, List<Map<String, dynamic>> products) {
    final totalPages = _paginationService.getTotalPages(products.length);
    final startItem = (_currentPage - 1) * 10 + 1;
    final endItem = (startItem + 9 > products.length) ? products.length : startItem + 9;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 10 : 12,
      ),
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
      child: isMobile
          ? Column(
        children: [
          Text(
            'Affichage $startItem-$endItem sur ${products.length}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                icon: const Icon(Icons.chevron_left),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                iconSize: 20,
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
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                icon: const Icon(Icons.chevron_right),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                iconSize: 20,
              ),
            ],
          ),
        ],
      )
          : Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage $startItem-$endItem sur ${products.length}',
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
                    ? () => setState(() => _currentPage--)
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
                    ? () => setState(() => _currentPage++)
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

  PreferredSizeWidget _buildSkeletonAppBar(bool isMobile) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: isMobile ? 80 : 90,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: isMobile ? 22 : 24,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 20,
            width: 80,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: isMobile ? 12 : 20, top: 8, bottom: 8),
          child: Row(
            children: [
              Container(
                height: 40,
                width: isMobile ? 40 : 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Container(
                height: 40,
                width: isMobile ? 40 : 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonStatsRow(bool isMobile) {
    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(3, (index) => Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 12),
            child: Container(
              width: 140,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 18,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
        ),
      );
    }

    return Row(
      children: List.generate(3, (index) => Expanded(
        child: Container(
          margin: EdgeInsets.only(right: index == 2 ? 0 : 16),
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 22,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 14,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _buildSkeletonCompanyInfo() {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 20,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 16,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 16,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  height: 30,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 30,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonProductsSection(bool isMobile) {
    final crossAxisCount = isMobile ? 2 : 4;
    final childAspectRatio = isMobile ? 0.7 : 0.8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 18,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 20,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            Container(
              height: 42,
              width: isMobile ? 42 : 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: isMobile ? 10 : 16,
                mainAxisSpacing: isMobile ? 10 : 16,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
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
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(isMobile ? 16 : 20),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: isMobile ? 12 : 14,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(height: isMobile ? 4 : 6),
                          Container(
                            height: isMobile ? 10 : 11,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(height: isMobile ? 6 : 8),
                          Container(
                            height: isMobile ? 12 : 14,
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}