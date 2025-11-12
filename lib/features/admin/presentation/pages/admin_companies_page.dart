import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/attachment_service.dart';
import 'admin_company_details_page.dart';

class AdminCompaniesPage extends StatefulWidget {
  const AdminCompaniesPage({super.key});

  @override
  State<AdminCompaniesPage> createState() => _AdminCompaniesPageState();
}

class _AdminCompaniesPageState extends State<AdminCompaniesPage>
    with SingleTickerProviderStateMixin {
  final CompanyService _companyService = CompanyService();
  final PaginationService _paginationService =
  PaginationService(itemsPerPage: 10);
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _filteredCompanies = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _viewMode = 'grid';
  int _currentPage = 1;
  late AnimationController _animationController;

  String _selectedStatus = 'ALL';
  String _sortBy = 'name';

  // Image service and storage
  final AttachmentService _attachmentService = AttachmentService();
  Map<int, List<Uint8List>> _companyImages = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
    _loadCompanies();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await _companyService.getAllCompanies();
      setState(() {
        _companies = companies;
        _applyFilters();
        _isLoading = false;
      });

      // Load images for all companies
      await _loadCompaniesImages(companies);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Erreur: $e', Colors.red.shade600);
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
                final attachmentDownload =
                await _attachmentService.downloadAttachment(attachmentId);
                images.add(attachmentDownload.data);
              }
            } catch (e) {
              debugPrint(
                '⚠️ Error downloading company attachment: $e',
              );
            }
          }

          if (mounted && images.isNotEmpty) {
            setState(() {
              _companyImages[companyId] = images;
            });
          }
        } catch (e) {
          debugPrint(
            '❌ Error loading images for company $companyId: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading companies images: $e');
    }
  }

  void _applyFilters() {
    var filtered = _companies;

    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((c) =>
      (c['companyName'] ?? '').toLowerCase().contains(query) ||
          (c['companyDescription'] ?? '').toLowerCase().contains(query))
          .toList();
    }

    if (_selectedStatus != 'ALL') {
      filtered = filtered
          .where((c) => (c['companyStatus'] ?? 'INACTIVE') == _selectedStatus)
          .toList();
    }

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return (a['companyName'] ?? '')
              .compareTo(b['companyName'] ?? '');
        case 'date':
          return (b['createdAt'] ?? '')
              .compareTo(a['createdAt'] ?? '');
        case 'rating':
          return (b['averageRating'] ?? 0)
              .compareTo(a['averageRating'] ?? 0);
        default:
          return 0;
      }
    });

    setState(() {
      _filteredCompanies = filtered;
      _currentPage = 1;
    });
  }

  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _deleteCompany(int companyId) async {
    try {
      await _companyService.deleteCompany(companyId);
      _loadCompanies();
      _showSnackBar('Entreprise supprimée avec succès', Colors.green);
    } catch (e) {
      _showSnackBar('Erreur: $e', Colors.red.shade600);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FadeTransition(
        opacity: _animationController,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 28),
              _buildFiltersBar(isMobile),
              const SizedBox(height: 24),
              _buildCompaniesContent(isMobile, isTablet),
              if (!_isLoading && _filteredCompanies.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildPaginationBar(isMobile),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gestion des Entreprises',
                    style: TextStyle(
                      fontSize: isMobile ? 28 : 36,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gérez et supervisez toutes les entreprises enregistrées',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            if (!isMobile)
              _buildStatsGrid(),
          ],
        ),
        if (isMobile) ...[
          const SizedBox(height: 16),
          _buildStatsGrid(),
        ],
      ],
    );
  }

  Widget _buildStatsGrid() {
    final activeCount = _companies
        .where((c) => c['companyStatus'] == 'ACTIVE')
        .length;
    final inactiveCount = _companies
        .where((c) => c['companyStatus'] == 'INACTIVE')
        .length;
    final bannedCount = _companies
        .where((c) => c['companyStatus'] == 'BANNED')
        .length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildStatCard('${_companies.length}', 'Total', Color(0xFF6366F1)),
        _buildStatCard('$activeCount', 'Actif', Color(0xFF10B981)),
        _buildStatCard('$inactiveCount', 'Inactif', Color(0xFFF59E0B)),
        _buildStatCard('$bannedCount', 'Bloqué', Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSearchField(),
              ),
              const SizedBox(width: 12),
              _buildStatusFilter(),
              if (!isMobile) ...[
                const SizedBox(width: 12),
                _buildSortDropdown(),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildSortDropdown()),
                const SizedBox(width: 12),
                Expanded(child: _buildViewToggle()),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredCompanies.length} entreprise${_filteredCompanies.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _buildViewToggle(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => _applyFilters(),
      decoration: InputDecoration(
        hintText: 'Rechercher par nom ou description...',
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildStatusFilter() {
    final statuses = [
      {'value': 'ALL', 'label': 'Tous', 'color': Color(0xFF6B7280)},
      {'value': 'ACTIVE', 'label': 'Actif', 'color': Color(0xFF10B981)},
      {'value': 'INACTIVE', 'label': 'Inactif', 'color': Color(0xFFF59E0B)},
      {'value': 'BANNED', 'label': 'Bloqué', 'color': Color(0xFFEF4444)},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          icon: Icon(Icons.expand_more, color: Colors.grey[600], size: 20),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
          onChanged: (value) {
            setState(() => _selectedStatus = value!);
            _applyFilters();
          },
          items: statuses.map((s) {
            return DropdownMenuItem(
              value: s['value'] as String,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: s['color'] as Color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s['label'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          icon: Icon(Icons.sort, size: 20, color: Colors.grey[600]),
          onChanged: (v) {
            setState(() => _sortBy = v!);
            _applyFilters();
          },
          items: [
            {'value': 'name', 'label': 'Nom'},
            {'value': 'date', 'label': 'Récent'},
            {'value': 'rating', 'label': 'Note'},
          ].map((e) {
            return DropdownMenuItem(
              value: e['value'] as String,
              child: Text(
                e['label'] as String,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Row(
      children: [
        _viewButton('grid', Icons.grid_view_rounded, 'Grille'),
        const SizedBox(width: 8),
        _viewButton('list', Icons.view_list_rounded, 'Liste'),
      ],
    );
  }

  Widget _viewButton(String mode, IconData icon, String tooltip) {
    final isActive = _viewMode == mode;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => setState(() => _viewMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : Colors.grey[300]!,
            ),
            boxShadow: isActive
                ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildCompaniesContent(bool isMobile, bool isTablet) {
    if (_isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    if (_filteredCompanies.isEmpty) return _buildEmptyState();

    return _viewMode == 'grid'
        ? _buildGridView(isMobile, isTablet)
        : _buildListView();
  }

  Widget _buildGridView(bool isMobile, bool isTablet) {
    final crossCount = isMobile ? 1 : isTablet ? 2 : 4;
    final paginated =
    _paginationService.getPageItems(_filteredCompanies, _currentPage);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: paginated.length,
      itemBuilder: (_, i) => _buildModernCard(paginated[i], i),
    );
  }

  Widget _buildListView() {
    final paginated =
    _paginationService.getPageItems(_filteredCompanies, _currentPage);
    return Column(children: paginated.map((c) => _buildListCard(c)).toList());
  }

  Widget _buildModernCard(Map<String, dynamic> company, int index) {
    final status = company['companyStatus'] ?? 'INACTIVE';
    final statusInfo = _getStatusInfo(status);
    final rating = (company['averageRating'] is num)
        ? (company['averageRating'] as num).toDouble()
        : 0.0;
    final companyId = company['companyId'] as int?;
    final companyImages = companyId != null ? _companyImages[companyId] : null;
    final firstImage = companyImages != null && companyImages.isNotEmpty
        ? companyImages.first
        : null;

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + (index * 80)),
      builder: (_, double value, __) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: MouseRegion(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: statusInfo['color'].withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background image
                    if (firstImage != null)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(
                            firstImage,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                statusInfo['color'].withOpacity(0.15),
                                statusInfo['color'].withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    // Dark overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Content overlay
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Header
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            company['companyName'] ?? 'Sans nom',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: -0.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'ID: ${company['companyId']}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Footer
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusInfo['color']
                                        .withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: statusInfo['color']
                                            .withOpacity(0.4),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        statusInfo['icon'],
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        statusInfo['label'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Rating and actions
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildRatingChipCompact(rating),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildQuickActionButtonCompact(
                                          Icons.visibility_rounded,
                                          Color(0xFF6366F1),
                                              () {
                                            showDialog(
                                              context: context,
                                              builder: (_) =>
                                                  AdminCompanyDetailsDialog(
                                                    companyId:
                                                    company['companyId'],
                                                    companyService:
                                                    _companyService,
                                                    onCompanyUpdated:
                                                    _loadCompanies,
                                                  ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 6),
                                        _buildQuickActionButtonCompact(
                                          Icons.delete_outline_rounded,
                                          Color(0xFFEF4444),
                                              () => _showDeleteDialog(
                                              company['companyId']),
                                        ),
                                      ],
                                    ),
                                  ],
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
          ),
        );
      },
    );
  }

  Widget _buildRatingChipCompact(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            size: 11,
            color: Colors.amber,
          ),
          const SizedBox(width: 3),
          Text(
            '${rating.toStringAsFixed(1)}/5',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 10,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtonCompact(
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.4),
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(Map<String, dynamic> company) {
    final status = company['companyStatus'] ?? 'INACTIVE';
    final statusInfo = _getStatusInfo(status);
    final rating = (company['averageRating'] is num)
        ? (company['averageRating'] as num).toDouble()
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusInfo['color'].withOpacity(0.15),
                  statusInfo['color'].withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.business_rounded,
              color: statusInfo['color'],
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company['companyName'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  company['companyDescription'] ?? '',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusInfo['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: statusInfo['color'].withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusInfo['icon'],
                  size: 12,
                  color: statusInfo['color'],
                ),
                const SizedBox(width: 4),
                Text(
                  statusInfo['label'],
                  style: TextStyle(
                    color: statusInfo['color'],
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildRatingChip(rating, compact: true),
          const SizedBox(width: 8),
          _buildActionMenu(company['companyId']),
        ],
      ),
    );
  }

  Widget _buildRatingChip(double rating, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Color(0xFFFCD34D).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Color(0xFFFCD34D).withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            size: 12,
            color: Color(0xFFFCD34D),
          ),
          const SizedBox(width: 4),
          Text(
            '${rating.toStringAsFixed(1)}/5',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
              color: Color(0xFFFCD34D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(int companyId) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: Colors.grey[500], size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 40),
      onSelected: (v) {
        if (v == 'view') {
          showDialog(
            context: context,
            builder: (_) => AdminCompanyDetailsDialog(
              companyId: companyId,
              companyService: _companyService,
              onCompanyUpdated: _loadCompanies,
            ),
          );
        } else if (v == 'delete') {
          _showDeleteDialog(companyId);
        }
      },
      itemBuilder: (_) => [
        _menuItem('view', Icons.visibility_rounded, 'Voir détails', AppColors.primary),
        _menuItem('delete', Icons.delete_outline_rounded, 'Supprimer', Color(0xFFEF4444)),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
      String value,
      IconData icon,
      String text,
      Color color,
      ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'ACTIVE':
        return {
          'label': 'Actif',
          'color': Color(0xFF10B981),
          'icon': Icons.check_circle_rounded,
        };
      case 'INACTIVE':
        return {
          'label': 'Inactif',
          'color': Color(0xFFF59E0B),
          'icon': Icons.pause_circle_rounded,
        };
      case 'BANNED':
        return {
          'label': 'Bloqué',
          'color': Color(0xFFEF4444),
          'icon': Icons.block_rounded,
        };
      default:
        return {
          'label': 'Inconnu',
          'color': Color(0xFF6B7280),
          'icon': Icons.help_rounded,
        };
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune entreprise trouvée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Essayez de modifier vos filtres ou votre recherche',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFFEF4444).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            size: 32,
            color: Color(0xFFEF4444),
          ),
        ),
        title: const Text(
          'Supprimer l\'entreprise ?',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        content: const Text(
          'Cette action est irréversible. Vous allez supprimer définitivement cette entreprise et toutes ses données associées.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteCompany(id);
            },
            child: const Text(
              'Supprimer',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar(bool isMobile) {
    final total = _paginationService.getTotalPages(_filteredCompanies.length);
    final start = (_currentPage - 1) * 10 + 1;
    final end = _currentPage * 10 > _filteredCompanies.length
        ? _filteredCompanies.length
        : _currentPage * 10;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
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
          Text(
            '$start–$end sur ${_filteredCompanies.length}',
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
          Row(
            children: [
              _pageButton(
                Icons.chevron_left_rounded,
                _currentPage > 1,
                    () => setState(() => _currentPage--),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '$_currentPage / $total',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _pageButton(
                Icons.chevron_right_rounded,
                _currentPage < total,
                    () => setState(() => _currentPage++),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageButton(IconData icon, bool enabled, VoidCallback onTap) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(
        icon,
        color: enabled ? AppColors.primary : Colors.grey[400],
        size: 22,
      ),
      splashRadius: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}