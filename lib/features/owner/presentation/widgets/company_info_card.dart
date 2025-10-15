import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class CompanyInfoCard extends StatelessWidget {
  final Map<String, dynamic> companyData;

  const CompanyInfoCard({
    super.key,
    required this.companyData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            companyData['name'] ?? 'Company Name',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            companyData['description'] ?? 'No description available',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.email, 'Email', companyData['email']),
          _buildInfoRow(Icons.phone, 'Phone', companyData['phone']),
          _buildInfoRow(Icons.location_on, 'Address', companyData['address']),
          _buildInfoRow(Icons.web, 'Website', companyData['website']),
          _buildInfoRow(Icons.calendar_today, 'Founded', companyData['founded']),
          _buildInfoRow(Icons.people, 'Employees', companyData['employees']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not provided',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}