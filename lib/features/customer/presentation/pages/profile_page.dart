import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/user_service.dart';
import '../widgets/address_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserService _userService = UserService('http://localhost:8080');
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  final int _currentUserId = 1; // Mock user ID

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await _userService.getUserById(_currentUserId);
      setState(() {
        _userData = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text(
                'Mon Profil',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: AppColors.primary,
              pinned: true,
              floating: true,
              elevation: 0,
              expandedHeight: 200,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildProfileHeader(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsSection(),
              const SizedBox(height: 24),
              _buildMenuSection(context),
            ],
          ),
        ),
      ),
    );
  }
  String formatPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    phone = phone.replaceAll(RegExp(r'\D'), ''); // remove spaces or symbols

    // Format: 55 555 555 (for 8 digits)
    if (phone.length == 8) {
      return '${phone.substring(0, 2)} ${phone.substring(2, 5)} ${phone.substring(5)}';
    }

    return phone;
  }


  Widget _buildProfileHeader() {
    final String fullName = _userData?['fullName'] ?? 'Jean Dupont';
    final String email = _userData?['email'] ;
    final String phone = formatPhone(_userData?['phone']) ?? _userData?['email'];
    final String initials = fullName
        .split(' ')
        .map((name) => name.isNotEmpty ? name[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.textLight,
            borderRadius: BorderRadius.circular(24),
          ),
          child: CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              initials.isNotEmpty ? initials : 'JD',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fullName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textLight.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textLight.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _userData?['userStatus'],
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.textLight.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () => _showEditProfileDialog(),
            icon: Icon(
              Icons.edit_rounded,
              color: AppColors.textLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
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
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              icon: Icons.shopping_bag_outlined,
              value: '24',
              label: 'Commandes',
              color: AppColors.primary,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.divider,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.favorite_outline,
              value: '8',
              label: 'Favoris',
              color: AppColors.danger,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.divider,
          ),
          Expanded(
            child: _buildStatItem(
              icon: Icons.star_outline,
              value: '4.8',
              label: 'Note',
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paramètres',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.location_on_outlined,
          title: 'Adresses de livraison',
          subtitle: 'Gérer vos adresses',
          onTap: () => _showAddressesDialog(),
        ),
        _buildMenuItem(
          icon: Icons.person_outline,
          title: 'Informations personnelles',
          subtitle: 'Modifier vos données',
          onTap: () => _showEditProfileDialog(),
        ),
        _buildMenuItem(
          icon: Icons.payment_outlined,
          title: 'Moyens de paiement',
          subtitle: 'Cartes et portefeuilles',
          onTap: () {},
        ),
        _buildMenuItem(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Préférences de notification',
          onTap: () {},
        ),
        _buildMenuItem(
          icon: Icons.language_outlined,
          title: 'Langue',
          subtitle: 'Français',
          onTap: () {},
        ),
        const SizedBox(height: 24),
        Text(
          'Support',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildMenuItem(
          icon: Icons.help_outline_rounded,
          title: 'Centre d\'aide',
          subtitle: 'FAQ et support',
          onTap: () {},
        ),
        _buildMenuItem(
          icon: Icons.chat_bubble_outline,
          title: 'Nous contacter',
          subtitle: 'Support client 24/7',
          onTap: () {},
        ),
        _buildMenuItem(
          icon: Icons.info_outline_rounded,
          title: 'À propos de Jibli',
          subtitle: 'Version 1.0.0',
          onTap: () {},
        ),
        const SizedBox(height: 24),
        _buildMenuItem(
          icon: Icons.logout_rounded,
          title: 'Se déconnecter',
          subtitle: null,
          onTap: () => _showLogoutDialog(context),
          isDestructive: true,
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive 
                ? AppColors.danger.withOpacity(0.1)
                : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isDestructive ? AppColors.danger : AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? AppColors.danger : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textTertiary,
        ),
        onTap: onTap,
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userData?['fullName'] ?? '');
    final emailController = TextEditingController(text: _userData?['email'] ?? '');
    final phoneController = TextEditingController(text: _userData?['phone'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Modifier le profil',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedData = {
                ..._userData!,
                'fullName': nameController.text,
                'email': emailController.text,
                'phone': phoneController.text,
              };
              
              try {
                final result = await _userService.updateUser(_currentUserId, updatedData);
                if (result != null) {
                  setState(() {
                    _userData = result;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profil mis à jour avec succès')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _showAddressesDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mes adresses',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showAddAddressDialog(),
                    icon: Icon(Icons.add, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    AddressCard(
                      title: 'Domicile',
                      address: _userData?['address'] ?? '123 Rue de la Paix, 75001 Paris',
                      isDefault: true,
                      onEdit: () => _showEditAddressDialog(),
                      onDelete: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAddressDialog() {
    final titleController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Ajouter une adresse',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Nom de l\'adresse',
                prefixIcon: Icon(Icons.label_outline, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Adresse complète',
                prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Adresse ajoutée avec succès')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog() {
    final addressController = TextEditingController(
      text: _userData?['address'] ?? '123 Rue de la Paix, 75001 Paris'
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Modifier l\'adresse',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: addressController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Adresse complète',
            prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedData = {
                ..._userData!,
                'address': addressController.text,
              };
              
              try {
                final result = await _userService.updateUser(_currentUserId, updatedData);
                if (result != null) {
                  setState(() {
                    _userData = result;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Adresse mise à jour avec succès')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Se déconnecter',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle logout
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}