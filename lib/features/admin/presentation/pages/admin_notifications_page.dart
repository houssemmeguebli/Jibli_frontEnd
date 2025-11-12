import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/admin_notifications_service.dart';
import '../../../../core/services/pagination_service.dart';
import '../../../../core/theme/theme.dart';

class AdminBroadcastPage extends StatefulWidget {
  const AdminBroadcastPage({super.key});

  @override
  State<AdminBroadcastPage> createState() => _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends State<AdminBroadcastPage> {
  final AdminBroadcastService _broadcastService = AdminBroadcastService();
  final PaginationService _paginationService = PaginationService(itemsPerPage: 10);

  List<Map<String, dynamic>> _broadcasts = [];
  List<Map<String, dynamic>> _filteredBroadcasts = [];
  bool _isLoading = true;
  String _selectedType = 'ALL';
  String _selectedAudience = 'ALL';
  String _selectedStatus = 'ALL';
  int _currentPage = 1;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _types = ['ALL', 'ANNOUNCEMENT', 'PROMOTION', 'ALERT', 'UPDATE', 'BROADCAST'];
  final List<String> _audiences = ['ALL', 'CUSTOMER', 'OWNER', 'DELIVERY'];
  final List<String> _statuses = ['ALL', 'SENDING', 'COMPLETED', 'FAILED', 'SCHEDULED'];

  @override
  void initState() {
    super.initState();
    _loadBroadcasts();
  }

  Future<void> _loadBroadcasts() async {
    try {
      setState(() => _isLoading = true);
      final broadcasts = await _broadcastService.getAllBroadcasts();
      if (mounted) {
        setState(() {
          _broadcasts = List<Map<String, dynamic>>.from(broadcasts);
          _filteredBroadcasts = _broadcasts;
          _currentPage = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Erreur: $e');
      }
    }
  }

  void _filterBroadcasts() {
    if (mounted) {
      setState(() {
        _filteredBroadcasts = _broadcasts.where((broadcast) {
          final matchesType = _selectedType == 'ALL' || broadcast['type'] == _selectedType;
          final matchesAudience = _selectedAudience == 'ALL' || broadcast['targetAudience'] == _selectedAudience;
          final matchesStatus = _selectedStatus == 'ALL' || broadcast['status'] == _selectedStatus;
          final matchesSearch = _searchController.text.isEmpty ||
              (broadcast['title'] ?? '').toString().toLowerCase().contains(_searchController.text.toLowerCase()) ||
              (broadcast['body'] ?? '').toString().toLowerCase().contains(_searchController.text.toLowerCase());
          return matchesType && matchesAudience && matchesStatus && matchesSearch;
        }).toList();
        _currentPage = 1;
      });
    }
  }

  Future<void> _deactivateBroadcast(int notificationId) async {
    try {
      await _broadcastService.deactivateBroadcast(notificationId);
      _loadBroadcasts();
      _showSuccessSnackBar('✅ Annonce désactivée');
    } catch (e) {
      _showErrorSnackBar('Erreur: $e');
    }
  }

  void _showSendBroadcastDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedType = 'ANNOUNCEMENT';
    String selectedAudience = 'ALL';
    bool isSending = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final maxWidth = isMobile ? screenWidth * 0.95 : (screenWidth < 1200 ? 700.0 : 800.0);
        
        return StatefulBuilder(
          builder: (context, setState) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: maxWidth,
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.of(context).size.height * 0.9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.blue.withOpacity(0.02)],
                ),
              ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                    ),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      const Text('📢', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nouvelle Annonce', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('Créez et envoyez une annonce', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: SingleChildScrollView(
                      child: isMobile
                          ? Column(
                              children: [
                                _buildTextInput(titleController, 'Titre', 'ex: Nouvelle Promotion', Icons.title),
                                const SizedBox(height: 16),
                                _buildTextInput(bodyController, 'Message', 'Contenu de l\'annonce', Icons.message, maxLines: 4),
                                const SizedBox(height: 16),
                                _buildDropdownInput(
                                  'Type',
                                  selectedType,
                                  _types.where((t) => t != 'ALL').toList(),
                                  (value) => setState(() => selectedType = value ?? 'ANNOUNCEMENT'),
                                  Icons.category,
                                  (t) => _getTypeLabel(t),
                                ),
                                const SizedBox(height: 16),
                                _buildDropdownInput(
                                  'Public cible',
                                  selectedAudience,
                                  _audiences,
                                  (value) => setState(() => selectedAudience = value ?? 'ALL'),
                                  Icons.people,
                                  _getAudienceName,
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildTextInput(titleController, 'Titre', 'ex: Nouvelle Promotion', Icons.title)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildDropdownInput(
                                      'Type',
                                      selectedType,
                                      _types.where((t) => t != 'ALL').toList(),
                                      (value) => setState(() => selectedType = value ?? 'ANNOUNCEMENT'),
                                      Icons.category,
                                      (t) => _getTypeLabel(t),
                                    )),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildTextInput(bodyController, 'Message', 'Contenu de l\'annonce', Icons.message, maxLines: 4),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: _buildDropdownInput(
                                      'Public cible',
                                      selectedAudience,
                                      _audiences,
                                      (value) => setState(() => selectedAudience = value ?? 'ALL'),
                                      Icons.people,
                                      _getAudienceName,
                                    )),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isSending ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                        child: const Text('Annuler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: isSending
                            ? null
                            : () async {
                          if (titleController.text.isEmpty || bodyController.text.isEmpty) {
                            _showErrorSnackBar('❌ Veuillez remplir les champs obligatoires');
                            return;
                          }
                          setState(() => isSending = true);
                          Navigator.pop(context);
                          await _sendBroadcast(
                            titleController.text,
                            bodyController.text,
                            selectedType,
                            selectedAudience
                          );
                        },
                        icon: isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white))) : const Icon(Icons.send),
                        label: Text(isSending ? 'Envoi...' : 'Envoyer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
      },
    );
  }

  Widget _buildTextInput(TextEditingController controller, String label, String hint, IconData icon, {bool isOptional = false, int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: '$label${isOptional ? '' : ' *'}',
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownInput(String label, String value, List<String> items, Function(String?) onChanged, IconData icon, String Function(String) label2) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(label2(item)))).toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _sendBroadcast(String title, String body, String type, String audience) async {
    try {
      await _broadcastService.sendBroadcast(
        title: title,
        body: body,
        type: type,
        targetAudience: audience,
      );
      _loadBroadcasts();
      _showSuccessSnackBar('✅ Annonce envoyée avec succès!');
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
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getAudienceName(String audience) {
    return switch (audience) {
      'ALL' => '👥 Tous les utilisateurs',
      'CUSTOMER' => '👤 Clients',
      'OWNER' => '🏪 Propriétaires',
      'DELIVERY' => '🚚 Livreurs',
      _ => audience,
    };
  }

  String _getTypeLabel(String type) {
    return switch (type) {
      'ANNOUNCEMENT' => '📢 Annonce',
      'PROMOTION' => '🎉 Promotion',
      'ALERT' => '⚠️ Alerte',
      'UPDATE' => '🔄 Mise à jour',
      'BROADCAST' => '📡 Diffusion',
      _ => type,
    };
  }

  String _getTypeIcon(String type) {
    return switch (type) {
      'ANNOUNCEMENT' => '📢',
      'PROMOTION' => '🎉',
      'ALERT' => '⚠️',
      'UPDATE' => '🔄',
      'BROADCAST' => '📡',
      _ => '📬',
    };
  }

  Color _getTypeColor(String type) {
    return switch (type) {
      'ANNOUNCEMENT' => const Color(0xFF3B82F6),
      'PROMOTION' => const Color(0xFFF59E0B),
      'ALERT' => const Color(0xFFEF4444),
      'UPDATE' => const Color(0xFF8B5CF6),
      'BROADCAST' => const Color(0xFF14B8A6),
      _ => Colors.grey,
    };
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'SENDING' => const Color(0xFFF97316),
      'COMPLETED' => const Color(0xFF22C55E),
      'FAILED' => const Color(0xFFEF4444),
      'SCHEDULED' => const Color(0xFF3B82F6),
      _ => Colors.grey,
    };
  }

  String _formatDate(dynamic dateValue) {
    try {
      if (dateValue == null) return 'N/A';
      DateTime? parsedDate;
      if (dateValue is List) {
        parsedDate = DateTime(dateValue[0], dateValue[1], dateValue[2], dateValue.length > 3 ? dateValue[3] : 0, dateValue.length > 4 ? dateValue[4] : 0);
      } else if (dateValue is String) {
        parsedDate = DateTime.parse(dateValue);
      }
      if (parsedDate != null) {
        return DateFormat('dd/MM/yy HH:mm').format(parsedDate);
      }
    } catch (e) {
      print('Date format error: $e');
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadBroadcasts,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : isTablet ? 24 : 32,
                  vertical: isMobile ? 16 : 24,
                ),
                child: _buildHeader(isMobile, isTablet),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: isMobile ? 24 : 32),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : isTablet ? 24 : 32),
                child: _buildStatsSection(isMobile, isTablet),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: isMobile ? 24 : 32),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : isTablet ? 24 : 32),
                child: _buildFiltersSection(isMobile, isTablet),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: isMobile ? 24 : 32),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : isTablet ? 24 : 32,
                  vertical: isMobile ? 16 : 24,
                ),
                child: _buildBroadcastsSection(isMobile, isTablet),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMobile)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📢 Annonces Diffusées', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -1.5)),
                    const SizedBox(height: 8),
                    Text('Gérez et envoyez des annonces à tous vos utilisateurs', style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showSendBroadcastDialog,
                icon: const Icon(Icons.add_circle, size: 20),
                label: const Text('Nouvelle Annonce', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📢 Annonces', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Text('Gérez vos annonces', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showSendBroadcastDialog,
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Nouvelle Annonce'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatsSection(bool isMobile, bool isTablet) {
    final totalBroadcasts = _broadcasts.length;
    final activeBroadcasts = _broadcasts.where((b) => b['isActive'] == true).length;
    final totalSent = _broadcasts.fold<int>(0, (sum, b) => sum + (b['sentCount'] as int? ?? 0));
    final totalFailed = _broadcasts.fold<int>(0, (sum, b) => sum + (b['failedCount'] as int? ?? 0));

    final stats = [
      {'label': 'Total', 'value': totalBroadcasts, 'icon': Icons.notifications_active, 'color': const Color(0xFF3B82F6), 'gradient': [const Color(0xFF3B82F6), const Color(0xFF1E40AF)]},
      {'label': 'Actives', 'value': activeBroadcasts, 'icon': Icons.check_circle, 'color': const Color(0xFF22C55E), 'gradient': [const Color(0xFF22C55E), const Color(0xFF15803D)]},
      {'label': 'Envoyées', 'value': totalSent, 'icon': Icons.send, 'color': const Color(0xFF8B5CF6), 'gradient': [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)]},
      {'label': 'Échouées', 'value': totalFailed, 'icon': Icons.error_outline, 'color': const Color(0xFFEF4444), 'gradient': [const Color(0xFFEF4444), const Color(0xFFDC2626)]},
    ];

    return Column(
      children: [
        Row(children: [Expanded(child: _buildStatCard(stats[0])), const SizedBox(width: 16), Expanded(child: _buildStatCard(stats[1]))]),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: _buildStatCard(stats[2])), const SizedBox(width: 16), Expanded(child: _buildStatCard(stats[3]))]),
      ],
    );
  }

  Widget _buildStatCard(Map stat) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [stat['color'], (stat['color'] as Color).withOpacity(0.6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: (stat['color'] as Color).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Icon(stat['icon'] as IconData, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          Text(stat['label'] as String, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text('${stat['value']}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
        ],
      ),
    );
  }

  Widget _buildFiltersSection(bool isMobile, bool isTablet) {
    return Column(
      children: [
        if (isMobile)
          Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _buildFilterDropdown('Type', _selectedType, _types, (v) => setState(() => _selectedType = v ?? 'ALL'), _getTypeLabel)), const SizedBox(width: 12), Expanded(child: _buildFilterDropdown('Statut', _selectedStatus, _statuses, (v) => setState(() => _selectedStatus = v ?? 'ALL'), (s) => s))]),
              const SizedBox(height: 12),
              _buildFilterDropdown('Public', _selectedAudience, _audiences, (v) => setState(() => _selectedAudience = v ?? 'ALL'), _getAudienceName),
            ],
          )
        else if (isTablet)
          Column(
            children: [
              Row(children: [Expanded(flex: 2, child: _buildSearchBar()), const SizedBox(width: 12), Expanded(child: _buildFilterDropdown('Type', _selectedType, _types, (v) => setState(() => _selectedType = v ?? 'ALL'), _getTypeLabel))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _buildFilterDropdown('Public', _selectedAudience, _audiences, (v) => setState(() => _selectedAudience = v ?? 'ALL'), _getAudienceName)), const SizedBox(width: 12), Expanded(child: _buildFilterDropdown('Statut', _selectedStatus, _statuses, (v) => setState(() => _selectedStatus = v ?? 'ALL'), (s) => s))]),
            ],
          )
        else
          Row(
            children: [
              Expanded(flex: 2, child: _buildSearchBar()),
              const SizedBox(width: 16),
              Expanded(child: _buildFilterDropdown('Type', _selectedType, _types, (v) => setState(() => _selectedType = v ?? 'ALL'), _getTypeLabel)),
              const SizedBox(width: 16),
              Expanded(child: _buildFilterDropdown('Public', _selectedAudience, _audiences, (v) => setState(() => _selectedAudience = v ?? 'ALL'), _getAudienceName)),
              const SizedBox(width: 16),
              Expanded(child: _buildFilterDropdown('Statut', _selectedStatus, _statuses, (v) => setState(() => _selectedStatus = v ?? 'ALL'), (s) => s)),
            ],
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _filterBroadcasts(),
        decoration: InputDecoration(
          hintText: 'Rechercher...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          prefixIcon: Icon(Icons.search, color: AppColors.primary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, Function(String?) onChanged, String Function(String) format) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        isExpanded: true,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(format(item), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)))).toList(),
        onChanged: (v) {
          onChanged(v);
          _filterBroadcasts();
        },
      ),
    );
  }

  Widget _buildBroadcastsSection(bool isMobile, bool isTablet) {
    // Get paginated items
    final paginatedBroadcasts = _paginationService.getPageItems(_filteredBroadcasts, _currentPage);

    return _isLoading
        ? Center(child: Column(children: [const SizedBox(height: 60), CircularProgressIndicator(color: AppColors.primary), const SizedBox(height: 16), Text('Chargement...', style: TextStyle(color: Colors.grey[600]))]))
        : _filteredBroadcasts.isEmpty
        ? _buildEmptyState()
        : Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${_filteredBroadcasts.length} annonce(s)', style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        if (isMobile || isTablet)
          Column(
            children: List.generate(
              paginatedBroadcasts.length,
                  (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(height: 300, child: _buildBroadcastCard(paginatedBroadcasts[index], isMobile)),
              ),
            ),
          )
        else
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: List.generate(
              paginatedBroadcasts.length,
                  (index) => SizedBox(
                width: (MediaQuery.of(context).size.width - 96) / 2,
                height: 380,
                child: _buildBroadcastCard(paginatedBroadcasts[index], isMobile),
              ),
            ),
          ),
        if (_filteredBroadcasts.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildPaginationBar(),
        ],
      ],
    );
  }

  Widget _buildBroadcastCard(Map<String, dynamic> broadcast, bool isMobile) {
    final typeColor = _getTypeColor(broadcast['type'] ?? 'BROADCAST');
    final statusColor = _getStatusColor(broadcast['status'] ?? 'SENDING');
    final createdAt = _formatDate(broadcast['createdAt']);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [typeColor.withOpacity(0.15), typeColor.withOpacity(0.05)]),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: typeColor.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: typeColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text(_getTypeIcon(broadcast['type'] ?? 'BROADCAST'), style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(broadcast['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1F2937)), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(createdAt, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(broadcast['status'] ?? 'PENDING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(broadcast['body'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.6), maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.2))),
                          child: Column(
                            children: [
                              Text('📤 Envoyées', style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600)),
                              Text('${broadcast['sentCount'] ?? 0}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.green[700])),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.2))),
                          child: Column(
                            children: [
                              Text('❌ Échouées', style: TextStyle(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.w600)),
                              Text('${broadcast['failedCount'] ?? 0}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.red[700])),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[100]!)),
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildSmallBadge(_getAudienceName(broadcast['targetAudience'] ?? 'ALL'), Colors.blue),
                      _buildSmallBadge(_getTypeLabel(broadcast['type'] ?? 'BROADCAST'), typeColor),
                      _buildSmallBadge(broadcast['isActive'] == true ? '✅ Actif' : '❌ Inactif', broadcast['isActive'] == true ? Colors.green : Colors.red),
                    ],
                  ),
                ),
                PopupMenuButton(
                  position: PopupMenuPosition.under,
                  itemBuilder: (context) => [
                    if (broadcast['isActive'] == true)
                      PopupMenuItem(
                        child: const Row(children: [Icon(Icons.close, size: 18), SizedBox(width: 8), Text('Désactiver')]),
                        onTap: () => _deactivateBroadcast(broadcast['notificationId'] ?? 0),
                      ),
                    PopupMenuItem(
                      child: const Row(children: [Icon(Icons.info_outline, size: 18), SizedBox(width: 8), Text('Détails')]),
                      onTap: () => _showBroadcastDetails(broadcast),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3), width: 1)),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  void _showBroadcastDetails(Map<String, dynamic> broadcast) {
    String _formatDateDetailed(dynamic dateValue) {
      try {
        if (dateValue == null) return 'N/A';
        DateTime? parsedDate;
        if (dateValue is List) {
          parsedDate = DateTime(dateValue[0], dateValue[1], dateValue[2], dateValue.length > 3 ? dateValue[3] : 0, dateValue.length > 4 ? dateValue[4] : 0);
        } else if (dateValue is String) {
          parsedDate = DateTime.parse(dateValue);
        }
        if (parsedDate != null) {
          return DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
        }
      } catch (e) {
        print('Date format error: $e');
      }
      return 'N/A';
    }

    final typeColor = _getTypeColor(broadcast['type'] ?? 'BROADCAST');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [typeColor, typeColor.withOpacity(0.7)]),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Text(_getTypeIcon(broadcast['type'] ?? 'BROADCAST'), style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Détails de l\'annonce', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(broadcast['title'] ?? '', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection('Contenu', [
                      _buildDetailRow('Titre', broadcast['title'] ?? 'N/A'),
                      _buildDetailRow('Message', broadcast['body'] ?? 'N/A'),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailSection('Configuration', [
                      _buildDetailRow('Type', _getTypeLabel(broadcast['type'] ?? 'BROADCAST')),
                      _buildDetailRow('Public cible', _getAudienceName(broadcast['targetAudience'] ?? 'ALL')),
                      _buildDetailRow('Statut', broadcast['status'] ?? 'PENDING'),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailSection('Statistiques', [
                      _buildDetailRow('Envoyées', '${broadcast['sentCount'] ?? 0}'),
                      _buildDetailRow('Échouées', '${broadcast['failedCount'] ?? 0}'),
                      _buildDetailRow('Actif', broadcast['isActive'] == true ? '✅ Oui' : '❌ Non'),
                    ]),
                    const SizedBox(height: 16),
                    _buildDetailSection('Dates', [
                      _buildDetailRow('Créée le', _formatDateDetailed(broadcast['createdAt'])),
                      if (broadcast['sentAt'] != null) _buildDetailRow('Envoyée le', _formatDateDetailed(broadcast['sentAt'])),
                      if (broadcast['scheduledAt'] != null) _buildDetailRow('Programmée pour', _formatDateDetailed(broadcast['scheduledAt'])),
                    ]),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937), letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children.asMap().entries.map((e) => Column(
              children: [
                e.value,
                if (e.key < children.length - 1) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(color: Colors.grey[300], height: 1)),
              ],
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF6B7280))),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Color(0xFF1F2937))),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.withOpacity(0.1), Colors.purple.withOpacity(0.1)]),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_outlined, size: 72, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text('Aucune annonce trouvée', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.grey[800])),
          const SizedBox(height: 8),
          Text('Commencez par créer une nouvelle annonce', style: TextStyle(fontSize: 14, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _showSendBroadcastDialog,
            icon: const Icon(Icons.add_circle),
            label: const Text('Créer première annonce'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 6,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    final totalPages = _paginationService.getTotalPages(_filteredBroadcasts.length);
    final startItem = (_currentPage - 1) * 10 + 1;
    final endItem = (startItem + 9 > _filteredBroadcasts.length) ? _filteredBroadcasts.length : startItem + 9;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage $startItem-$endItem sur ${_filteredBroadcasts.length}',
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}