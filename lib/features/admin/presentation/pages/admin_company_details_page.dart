import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/company_service.dart';

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
  bool _isLoading = true;
  late AnimationController _slideController;
  String? _selectedStatus;
  bool _isUpdatingStatus = false;

  final List<String> _statuses = ['ACTIVE', 'INACTIVE', 'BLOCKED'];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController.forward();

    // Load data after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanyDetails();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  /// Safe conversion for any type to String
  String _safeToString(dynamic value, [String defaultValue = 'N/A']) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    if (value is List && value.isNotEmpty) return value[0].toString();
    if (value is int || value is double) return value.toString();
    return defaultValue;
  }

  Future<void> _loadCompanyDetails() async {
    try {
      final company = await widget.companyService.getCompanyById(widget.companyId);
      if (mounted) {
        // Safely get status
        String status = _safeToString(company!['companyStatus'], 'ACTIVE');

        setState(() {
          _company = company;
          _selectedStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show error after frame is built
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

  Future<void> _updateCompanyStatus(String newStatus) async {
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

        // Show success message after frame is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Statut mis à jour: ${_getStatusLabel(newStatus)}'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);

        // Show error message after frame is built
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
    final maxWidth = isMobile ? double.infinity : 650.0;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
        CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeOutCubic,
        ),
      ),
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: isMobile ? 12 : 32,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 50,
                offset: const Offset(0, 25),
              ),
            ],
          ),
          child: _isLoading
              ? const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          )
              : _company == null
              ? const SizedBox(
            height: 200,
            child: Center(child: Text('Entreprise non trouvée')),
          )
              : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 20 : 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCompanyCard(),
                      const SizedBox(height: 24),
                      _buildStatusSection(),
                      const SizedBox(height: 24),
                      _buildInfoSection(),
                    ],
                  ),
                ),
              ),
              _buildDialogFooter(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.business_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Détails Entreprise',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${_safeToString(_company!['companyId'])}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            child: Icon(
              Icons.business,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _safeToString(_company!['companyName']),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _safeToString(_company!['companySector'], 'Secteur non spécifié'),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gestion du Statut',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getStatusBackgroundColor(_selectedStatus),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _getStatusColor(_selectedStatus).withOpacity(0.3),
              width: 1.5,
            ),
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
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStatusIcon(_selectedStatus),
                      color: _getStatusColor(_selectedStatus),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statut actuel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getStatusLabel(_selectedStatus),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _getStatusColor(_selectedStatus),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Changer le statut',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statuses.map((status) {
                  final isSelected = _selectedStatus == status;
                  return Opacity(
                    opacity: _isUpdatingStatus ? 0.5 : 1.0,
                    child: InkWell(
                      onTap: _isUpdatingStatus || isSelected
                          ? null
                          : () => _updateCompanyStatus(status),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _getStatusColor(status)
                              : _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? _getStatusColor(status)
                                : _getStatusColor(status).withOpacity(0.3),
                            width: 2,
                          ),
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
                                  Icons.check_circle,
                                  size: 16,
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

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations Détaillées',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('ID Entreprise', _safeToString(_company!['companyId'])),
        _buildInfoRow('Nom', _safeToString(_company!['companyName'])),
        _buildInfoRow('Secteur', _safeToString(_company!['companySector'])),
        _buildInfoRow('Email', _safeToString(_company!['companyEmail'])),
        _buildInfoRow('Téléphone', _safeToString(_company!['companyPhone'])),
        _buildInfoRow('Adresse', _safeToString(_company!['companyAddress'])),
        _buildInfoRow('Heure d\'ouverture', _safeToString(_company!['timeOpen'])),
        _buildInfoRow('Heure de fermeture', _safeToString(_company!['timeClose'])),
        _buildInfoRow(
          'Note moyenne',
          '${_company!['averageRating']?.toStringAsFixed(2) ?? 'N/A'}/5',
        ),
        _buildInfoRow('Date de création', _formatDateTime(_company!['createdAt'])),
        _buildInfoRow(
          'Dernière mise à jour',
          _formatDateTime(_company!['lastUpdated']),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey[300]!, width: 1.5),
              ),
              child: Text(
                'Fermer',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
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
        return Colors.green;
      case 'INACTIVE':
        return Colors.orange;
      case 'BLOCKED':
        return Colors.red;
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
        return Icons.check_circle;
      case 'INACTIVE':
        return Icons.schedule;
      case 'BLOCKED':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'ACTIVE':
        return 'Actif';
      case 'INACTIVE':
        return 'Inactif';
      case 'BLOCKED':
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