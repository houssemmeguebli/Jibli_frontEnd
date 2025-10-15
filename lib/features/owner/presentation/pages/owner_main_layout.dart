import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import 'owner_dashboard.dart';
import 'company_page.dart';

class OwnerMainLayout extends StatefulWidget {
  const OwnerMainLayout({super.key});

  @override
  State<OwnerMainLayout> createState() => _OwnerMainLayoutState();
}

class _OwnerMainLayoutState extends State<OwnerMainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const OwnerDashboard(),
    const CompanyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWeb = constraints.maxWidth > 800;
        
        return Scaffold(
          body: isWeb ? _buildWebLayout() : _buildMobileLayout(),
        );
      },
    );
  }

  Widget _buildWebLayout() {
    return Row(
      children: [
        Container(
          width: 250,
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildSidebar()),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: AppColors.background,
            child: _pages[_selectedIndex],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle()),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        elevation: 0,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Tableau de bord',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Entreprise',
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.textLight,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const CircleAvatar(
              radius: 27,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.store, size: 28, color: AppColors.textLight),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Espace Propriétaire',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        const SizedBox(height: 12),
        _buildSidebarItem(0, Icons.dashboard, 'Tableau de bord'),
        const SizedBox(height: 12),
        _buildSidebarItem(1, Icons.business, 'Entreprise'),
        const Spacer(),
        Container(
          margin: const EdgeInsets.all(12),
          child: ListTile(
            leading: const Icon(Icons.logout, color: AppColors.danger),
            title: const Text(
              'Déconnexion',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
            onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {

    bool isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight : null,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Tableau de bord';
      case 1:
        return 'Entreprise';
      default:
        return 'Espace Propriétaire';
    }
  }
}