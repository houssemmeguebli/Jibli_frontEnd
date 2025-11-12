import 'package:flutter/material.dart';
import 'package:frontend/features/customer/presentation/pages/cart_page.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/cart_service.dart';
import '../../../../core/services/cart_notifier.dart';
import '../../../../core/services/auth_service.dart';
import 'home_page.dart';
import 'customer_orders_page.dart';
import 'favorites_page.dart';
import 'profile_page.dart';

class CustomerMainLayout extends StatefulWidget {
  const CustomerMainLayout({super.key});

  @override
  State<CustomerMainLayout> createState() => _CustomerMainLayoutState();
}

class _CustomerMainLayoutState extends State<CustomerMainLayout>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _cartItemCount = 0;
  final CartService _cartService = CartService();
  final CartNotifier _cartNotifier = CartNotifier();
  final AuthService _authService = AuthService();
  int? _currentUserId;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cartNotifier.addListener(_loadCartItemCount);
    _initializePages();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    _currentUserId = await _authService.getUserId();
    _loadCartItemCount();
  }

  void _initializePages() {
    _pages = [
      const HomePage(),
      const OrdersPage(),
      CartPage(onCartUpdated: _updateCartCount),
      const ProfilePage(),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cartNotifier.removeListener(_loadCartItemCount);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCartItemCount();
    }
  }

  Future<void> _loadCartItemCount() async {
    if (_currentUserId == null) return;
    
    try {
      final groupedCarts = await _cartService.getUserCartsGroupedByCompany(_currentUserId!);

      int totalItems = 0;
      for (var cart in groupedCarts) {
        final cartItems = cart['cartItems'] as List<dynamic>? ?? [];
        for (var item in cartItems) {
          final quantity = item['quantity'] as int? ?? 1;
          totalItems += quantity;
        }
      }

      if (mounted) {
        setState(() {
          _cartItemCount = totalItems;
        });
      }
    } catch (e) {
      debugPrint('Error loading cart count: $e');
      if (mounted) {
        setState(() {
          _cartItemCount = 0;
        });
      }
    }
  }

  void _updateCartCount(int newCount) {
    if (mounted) {
      setState(() {
        _cartItemCount = newCount;
      });
    }
  }

  Widget _buildCartIcon({required bool isSelected}) {
    final icon = isSelected ? Icons.shopping_cart : Icons.shopping_cart_outlined;
    final iconColor = isSelected ? AppColors.primary : Colors.black;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: iconColor),
        if (_cartItemCount > 0)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8)
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints:
              const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                _cartItemCount > 99 ? '99+' : '$_cartItemCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (index == 2) {
              _loadCartItemCount();
            }
          },
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primaryLight,
          elevation: 0,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Accueil',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon:
              Icon(Icons.receipt_long, color: AppColors.primary),
              label: 'Commandes',
            ),
            NavigationDestination(
              icon: _buildCartIcon(isSelected: false),
              selectedIcon: _buildCartIcon(isSelected: true),
              label: 'Panier',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppColors.primary),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}