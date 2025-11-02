import 'package:flutter/material.dart';
import 'package:frontend/features/delievery/presentation/pages/delivery_statistics_page.dart';
import '../../../../core/theme/theme.dart';
import 'delivery_dashboard.dart';
import 'delivery_orders_page.dart';
import 'delivery_profile_page.dart';

class DeliveryMainLayout extends StatefulWidget {
  const DeliveryMainLayout({super.key});

  @override
  State<DeliveryMainLayout> createState() => _DeliveryMainLayoutState();
}

class _DeliveryMainLayoutState extends State<DeliveryMainLayout> {
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;

  final List<Widget> _pages = [
    const DeliveryDashboard(),
    const DeliveryOrdersPage(),
    const DeliveryProfilePage(),
    const DeliveryStatisticsPage()
  ];

  final List<({IconData icon, String label, String route})> _menuItems = [
    (icon: Icons.dashboard_rounded, label: 'Tableau de bord', route: 'dashboard'),
    (icon: Icons.local_shipping_rounded, label: 'Mes Livraisons', route: 'orders'),
    (icon: Icons.analytics_rounded, label: 'Statistiques', route: 'statistics'),
    (icon: Icons.person_rounded, label: 'Profil', route: 'profile'),



  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWeb = constraints.maxWidth > 900;
        bool isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 900;

        return Scaffold(
          body: isWeb
              ? _buildWebLayout()
              : isTablet
              ? _buildTabletLayout()
              : _buildMobileLayout(),
        );
      },
    );
  }

  Widget _buildWebLayout() {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _sidebarCollapsed ? 80 : 280,
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(isCollapsed: _sidebarCollapsed),
              Expanded(child: _buildSidebar(isCollapsed: _sidebarCollapsed)),
              _buildSidebarFooter(isCollapsed: _sidebarCollapsed),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: AppColors.background,
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      children: [
        _buildMobileTopBar(),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 70,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadow.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: _buildCompactSidebar(),
              ),
              Expanded(
                child: Container(
                  color: AppColors.background,
                  child: _pages[_selectedIndex],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        elevation: 1,
        centerTitle: false,
        title: const Text('Espace Livreur'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withOpacity(0.3)),
              ),
              child: IconButton(
                onPressed: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                icon: Icon(
                  _sidebarCollapsed ? Icons.menu : Icons.menu_open,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTopBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: AppColors.accent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Espace Livreur',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({bool isCollapsed = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 12 : 20,
        vertical: 24,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.textLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: isCollapsed ? 48 : 60,
              height: isCollapsed ? 48 : 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent, AppColors.accent.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(height: 16),
            const Text(
              'Espace Livreur',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Gérez vos livraisons',
              style: TextStyle(
                color: AppColors.textLight.withOpacity(0.75),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSidebar({bool isCollapsed = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 12,
        vertical: 16,
      ),
      child: Column(
        children: [
          ...List.generate(
            _menuItems.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildSidebarItem(
                index,
                _menuItems[index].icon,
                _menuItems[index].label,
                isCollapsed: isCollapsed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSidebar() {
    return Column(
      children: [
        const SizedBox(height: 12),
        ...List.generate(
          _menuItems.length,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildCompactSidebarItem(
              index,
              _menuItems[index].icon,
              _menuItems[index].label,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem(
    int index,
    IconData icon,
    String title, {
    bool isCollapsed = false,
  }) {
    bool isSelected = _selectedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 12 : 16,
              vertical: 12,
            ),
            child: isCollapsed
                ? Tooltip(
                    message: title,
                    child: Icon(
                      icon,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      size: 24,
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSidebarItem(int index, IconData icon, String title) {
    bool isSelected = _selectedIndex == index;

    return Tooltip(
      message: title,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _selectedIndex = index),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter({bool isCollapsed = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 12,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border.withOpacity(0.1)),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: isCollapsed
                ? const Icon(Icons.logout_rounded, color: AppColors.danger, size: 24)
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout_rounded, color: AppColors.danger, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Déconnexion',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _selectedIndex == 0 ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.dashboard_rounded, size: 24),
          ),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _selectedIndex == 1 ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping_rounded, size: 24),
          ),
          label: 'Livraisons',
        ),

        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _selectedIndex == 5
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.analytics_rounded, size: 24),
          ),
          label: 'Stats',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _selectedIndex == 2 ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_rounded, size: 24),
          ),
          label: 'Profil',
        ),
      ],
    );
  }
}