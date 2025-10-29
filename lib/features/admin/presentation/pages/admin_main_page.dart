import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import 'admin_users_page.dart';
import 'admin_companies_page.dart';
import 'admin_reviews_page.dart';
import 'admin_dashboard_page.dart';

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _selectedIndex = 0;
  bool _isExpanded = true;

  final List<AdminMenuItem> _menuItems = [
    AdminMenuItem(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      title: 'Dashboard',
      page: const AdminDashboardPage(),
    ),
    AdminMenuItem(
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      title: 'Utilisateurs',
      page: const AdminUsersPage(),
    ),
    AdminMenuItem(
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
      title: 'Entreprises',
      page: const AdminCompaniesPage(),
    ),
    AdminMenuItem(
      icon: Icons.rate_review_outlined,
      selectedIcon: Icons.rate_review,
      title: 'Avis',
      page: const AdminReviewsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isExpanded ? 280 : 80,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    height: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.admin_panel_settings,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        if (_isExpanded) ...[
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Admin Panel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          icon: Icon(
                            _isExpanded ? Icons.menu_open : Icons.menu,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Menu Items
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      itemCount: _menuItems.length,
                      itemBuilder: (context, index) {
                        final item = _menuItems[index];
                        final isSelected = _selectedIndex == index;
                        
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  _selectedIndex = index;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                                  border: isSelected ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? item.selectedIcon : item.icon,
                                      color: isSelected ? AppColors.primary : Colors.grey[600],
                                      size: 24,
                                    ),
                                    if (_isExpanded) ...[
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            color: isSelected ? AppColors.primary : Colors.grey[700],
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Footer
                  if (_isExpanded)
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Divider(color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Admin',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Administrateur',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
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
                ],
              ),
            ),
          ),
          // Main Content
          Expanded(
            child: _menuItems[_selectedIndex].page,
          ),
        ],
      ),
    );
  }
}

class AdminMenuItem {
  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final Widget page;

  AdminMenuItem({
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.page,
  });
}