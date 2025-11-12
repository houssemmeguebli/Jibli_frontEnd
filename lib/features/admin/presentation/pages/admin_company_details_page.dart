import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/attachment_service.dart';

class AdminCompanyDetailsDialog extends StatefulWidget {
  final int companyId;
  final CompanyService companyService;
  final VoidCallback? onCompanyUpdated;

  const AdminCompanyDetailsDialog({
    super.key,
    required this.companyId,
    required this.companyService,
    this.onCompanyUpdated,
  });

  @override
  State<AdminCompanyDetailsDialog> createState() =>
      _AdminCompanyDetailsDialogState();
}

class _AdminCompanyDetailsDialogState extends State<AdminCompanyDetailsDialog>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _company;
  List<Uint8List> _companyImages = [];
  int _selectedImageIndex = 0;
  bool _isLoading = true;
  late AnimationController _slideController;
  String? _selectedStatus;
  bool _isUpdatingStatus = false;

  final AttachmentService _attachmentService = AttachmentService();
  final List<String> _statuses = ['ACTIVE', 'INACTIVE', 'BANNED'];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanyDetails();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  String _safeToString(dynamic value, [String defaultValue = 'N/A']) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return value[0].toString();
    if (value is int || value is double) return value.toString();
    return defaultValue;
  }

  Future<void> _loadCompanyDetails() async {
    try {
      final company =
      await widget.companyService.getCompanyById(widget.companyId);
      if (mounted) {
        String status = _safeToString(company!['companyStatus'], 'ACTIVE');

        setState(() {
          _company = company;
          _selectedStatus = status;
        });

        await _loadCompanyImages();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: $e'),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _loadCompanyImages() async {
    try {
      final attachments = await _attachmentService.getAttachmentsByEntity(
        'COMPANY',
        widget.companyId,
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
          debugPrint('⚠️ Error downloading attachment: $e');
        }
      }

      if (mounted) {
        setState(() {
          _companyImages = images;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading company images: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmDialog(String newStatus) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getStatusColor(newStatus).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStatusIcon(newStatus),
            color: _getStatusColor(newStatus),
            size: 28,
          ),
        ),
        title: const Text(
          'Confirmer le changement',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          'Voulez-vous vraiment passer le statut de l\'entreprise à\n"${_getStatusLabel(newStatus)}" ?',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(newStatus),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Oui, changer',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<void> _updateCompanyStatus(String newStatus) async {
    if (_selectedStatus == newStatus) return;

    final confirmed = await _showConfirmDialog(newStatus);
    if (!confirmed) return;

    try {
      setState(() => _isUpdatingStatus = true);

      final updatedCompany = {
        ..._company!,
        'companyStatus': newStatus,
      };

      await widget.companyService.updateCompany(
        widget.companyId,
        updatedCompany,
      );

      if (mounted) {
        setState(() {
          _company = updatedCompany;
          _selectedStatus = newStatus;
          _isUpdatingStatus = false;
        });

        widget.onCompanyUpdated?.call();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      'Statut mis à jour → ${_getStatusLabel(newStatus)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: $e'),
                backgroundColor: Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxWidth = isMobile ? double.infinity : 700.0;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
      ),
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 20,
          vertical: isMobile ? 8 : 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: _isLoading
              ? const SizedBox(
            height: 300,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
              : _company == null
              ? const SizedBox(
            height: 200,
            child: Center(
              child: Text('Entreprise non trouvée'),
            ),
          )
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(isMobile),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_companyImages.isNotEmpty)
                        _buildImageCarousel(isMobile),
                      const SizedBox(height: 24),
                      _buildStatusSection(),
                      const SizedBox(height: 24),
                      _buildInfoSection(isMobile),
                    ],
                  ),
                ),
              ),
              _buildDialogFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Détails Entreprise',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${_safeToString(_company!['companyId'])}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(bool isMobile) {
    return Column(
      children: [
        Container(
          height: isMobile ? 200 : 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              PageView.builder(
                itemCount: _companyImages.length,
                onPageChanged: (index) =>
                    setState(() => _selectedImageIndex = index),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      _companyImages[index],
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_companyImages.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _companyImages.asMap().entries.map((entry) {
              final isSelected = _selectedImageIndex == entry.key;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isSelected ? 28 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.3),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 8,
                    )
                  ]
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }


  Widget _buildStatusBadge(String? status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStatusColor(status).withOpacity(0.15),
            _getStatusColor(status).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getStatusIcon(status),
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _getStatusLabel(status),
            style: TextStyle(
              color: _getStatusColor(status),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestion du Statut',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getStatusBackgroundColor(_selectedStatus),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getStatusColor(_selectedStatus).withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _getStatusColor(_selectedStatus).withOpacity(0.08),
                blurRadius: 12,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_selectedStatus).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getStatusIcon(_selectedStatus),
                      color: _getStatusColor(_selectedStatus),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Statut actuel',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _getStatusLabel(_selectedStatus),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _getStatusColor(_selectedStatus),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Changer le statut',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statuses.map((status) {
                  final isSelected = _selectedStatus == status;
                  return Opacity(
                    opacity: _isUpdatingStatus ? 0.6 : 1.0,
                    child: InkWell(
                      onTap: _isUpdatingStatus || isSelected
                          ? null
                          : () => _updateCompanyStatus(status),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                            colors: [
                              _getStatusColor(status),
                              _getStatusColor(status).withOpacity(0.8),
                            ],
                          )
                              : LinearGradient(
                            colors: [
                              _getStatusColor(status).withOpacity(0.1),
                              _getStatusColor(status).withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? _getStatusColor(status)
                                : _getStatusColor(status).withOpacity(0.3),
                            width: isSelected ? 2 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color:
                              _getStatusColor(status).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              if (_isUpdatingStatus)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _getStatusLabel(status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : _getStatusColor(status),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informations Détaillées',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: Column(
            children: [
              // Row 1: ID and Nom
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildInfoRowCompact(
                          'ID Entreprise',
                          _safeToString(_company!['companyId']),
                          Icons.fingerprint_rounded,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Colors.grey[200],
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildInfoRowCompact(
                          'Nom',
                          _safeToString(_company!['companyName']),
                          Icons.label_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              // Row 2: Secteur and Email
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildInfoRowCompact(
                          'Secteur',
                          _safeToString(_company!['companySector']),
                          Icons.category_rounded,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Colors.grey[200],
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildInfoRowCompact(
                          'Email',
                          _safeToString(_company!['companyEmail']),
                          Icons.email_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              // Row 3: Téléphone and Adresse
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildInfoRowCompact(
                          'Téléphone',
                          _safeToString(_company!['companyPhone']),
                          Icons.phone_rounded,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Colors.grey[200],
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildInfoRowCompact(
                          'Adresse',
                          _safeToString(_company!['companyAddress']),
                          Icons.location_on_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              // Row 4: Ouverture and Fermeture
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildInfoRowCompact(
                          'Ouverture',
                          _formatTime(_company!['timeOpen']),
                          Icons.access_time_rounded,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Colors.grey[200],
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildInfoRowCompact(
                          'Fermeture',
                          _formatTime(_company!['timeClose']),
                          Icons.schedule_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              // Row 5: Note moyenne and Date création
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildInfoRowCompact(
                          'Note moyenne',
                          '${_company!['averageRating']?.toStringAsFixed(2) ?? 'N/A'}/5',
                          Icons.star_rounded,
                          iconColor: Colors.amber,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Colors.grey[200],
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: _buildInfoRowCompact(
                          'Date création',
                          _formatDateTime(_company!['createdAt']),
                          Icons.calendar_today_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildDivider(),
              // Row 6: Dernière mise à jour
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: _buildInfoRowCompact(
                  'Dernière mise à jour',
                  _formatDateTime(_company!['lastUpdated']),
                  Icons.update_rounded,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRowCompact(
      String label,
      String value,
      IconData icon, {
        Color? iconColor,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 14,
                color: iconColor ?? AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[600],
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatTime(dynamic time) {
    if (time == null) return 'N/A';
    try {
      if (time is String) {
        // If it's already a time string like "10:30:00"
        if (time.contains(':')) {
          final parts = time.split(':');
          if (parts.length >= 2) {
            return '${parts[0]}:${parts[1]}';
          }
        }
        return time;
      }
      if (time is List) {
        if (time.length >= 2) {
          final hour = time[0].toString().padLeft(2, '0');
          final minute = time[1].toString().padLeft(2, '0');
          return '$hour:$minute';
        }
      }
      return time.toString();
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: Colors.grey[200],
      ),
    );
  }

  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Fermer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'ACTIVE':
        return const Color(0xFF10B981);
      case 'INACTIVE':
        return const Color(0xFFF59E0B);
      case 'BANNED':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBackgroundColor(String? status) {
    return _getStatusColor(status).withOpacity(0.08);
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'ACTIVE':
        return Icons.check_circle_rounded;
      case 'INACTIVE':
        return Icons.pause_circle_rounded;
      case 'BANNED':
        return Icons.block_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'ACTIVE':
        return 'Actif';
      case 'INACTIVE':
        return 'Inactif';
      case 'BANNED':
        return 'Bloqué';
      default:
        return 'N/A';
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      if (dateTime is String) {
        return dateTime.replaceAll('T', ' ').split('.')[0];
      }
      if (dateTime is List) {
        if (dateTime.length >= 3) {
          return '${dateTime[2]}/${dateTime[1]}/${dateTime[0]} ${dateTime.length > 3 ? dateTime[3] : 0}:${dateTime.length > 4 ? dateTime[4] : 0}';
        }
      }
      return dateTime.toString();
    } catch (e) {
      return 'N/A';
    }
  }
}