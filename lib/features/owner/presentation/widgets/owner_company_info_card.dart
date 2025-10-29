import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class CompanyInfoCard extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const CompanyInfoCard({
    super.key,
    required this.companyData,
  });

  String _parseValue(dynamic value) {
    if (value == null) return 'Non fourni';

    if (value is String) {
      return value.isEmpty ? 'Non fourni' : value;
    }

    if (value is List) {
      if (value.isEmpty) return 'Non fourni';
      return value.join(', ');
    }

    if (value is int || value is double) {
      return value.toString();
    }

    return 'Non fourni';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1024;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section with gradient background
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyData['companyName'] ?? 'Company Name',
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textLight,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.textLight.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    companyData['companySector'] ?? 'Secteur non spécifié',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Description Section
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyData['companyDescription'] ?? 'No description available',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // Info Grid
                isMobile
                    ? _buildMobileInfoGrid()
                    : isTablet
                    ? _buildTabletInfoGrid()
                    : _buildDesktopInfoGrid(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mobile: Single column layout
  Widget _buildMobileInfoGrid() {
    return Column(
      children: [
        _buildInfoRow(
          Icons.email,
          'Email',
          companyData['companyEmail'],
          Icons.copy,
        ),
        _buildDivider(),
        _buildInfoRow(
          Icons.phone,
          'Téléphone',
          companyData['companyPhone'],
          Icons.call,
        ),
        _buildDivider(),
        _buildInfoRow(
          Icons.location_on,
          'Adresse',
          companyData['companyAddress'],
          Icons.navigation,
        ),
        _buildDivider(),
        _buildInfoRow(
          Icons.calendar_today,
          'Crée le ',
          companyData['createdAt'],
          Icons.info,
        ),
        _buildDivider(),
      ],
    );
  }

  // Tablet: 2 column layout
  Widget _buildTabletInfoGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                Icons.email,
                'Email',
                companyData['companyEmail'],
                Icons.copy,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInfoRow(
                Icons.phone,
                'Téléphone',
                companyData['companyPhone'],
                Icons.call,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                Icons.location_on,
                'Adresse',
                companyData['companyAddress'],
                Icons.navigation,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                Icons.calendar_today,
                'Crée le ',
                companyData['createdAt'],
                Icons.info,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Desktop: 2 column layout with better spacing
  Widget _buildDesktopInfoGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                Icons.email,
                'Email',
                companyData['companyEmail'],
                Icons.copy,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildInfoRow(
                Icons.phone,
                'Téléphone',
                companyData['companyPhone'],
                Icons.call,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                Icons.location_on,
                'Adresse',
                companyData['companyAddress'],
                Icons.navigation,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildInfoRow(
                Icons.calendar_today,
                'Crée le ',
                companyData['createdAt'],
                Icons.info,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        color: AppColors.border.withOpacity(0.5),
        height: 1,
      ),
    );
  }

  Widget _buildInfoRow(
      IconData mainIcon,
      String label,
      dynamic value,
      IconData actionIcon,
      ) {
    final displayValue = _parseValue(value);
    final hasValue = displayValue != 'Non fourni';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  mainIcon,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: hasValue
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (hasValue)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        actionIcon,
                        size: 16,
                        color: AppColors.primary.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}