import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/user_service.dart';

class AdminUserDetailsDialog extends StatefulWidget {
  final int userId;
  final UserService userService;
  final VoidCallback? onUserUpdated;

  const AdminUserDetailsDialog({
    super.key,
    required this.userId,
    required this.userService,
    this.onUserUpdated,
  });

  @override
  State<AdminUserDetailsDialog> createState() => _AdminUserDetailsDialogState();
}

class _AdminUserDetailsDialogState extends State<AdminUserDetailsDialog>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isEditing = false;
  late AnimationController _slideController;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  String? _selectedGender;
  String? _selectedUserStatus;
  String? _selectedUserRole;
  DateTime? _selectedDateOfBirth;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController.forward();
    _initializeControllers();
    _loadUserDetails();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _initializeControllers() {
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
  }

  void _populateControllers() {
    if (_user != null) {
      _fullNameController.text = _user!['fullName'] ?? '';
      _emailController.text = _user!['email'] ?? '';
      _phoneController.text = _user!['phone'] ?? '';
      _addressController.text = _user!['address'] ?? '';
      _selectedGender = _user!['gender'];
      _selectedUserStatus = _user!['userStatus'];
      _selectedUserRole = _user!['userRole'];
      if (_user!['dateOfBirth'] != null) {
        try {
          _selectedDateOfBirth = DateTime.parse(_user!['dateOfBirth'].toString().split('T')[0]);
        } catch (e) {
          _selectedDateOfBirth = null;
        }
      }
    }
  }

  Future<void> _loadUserDetails() async {
    try {
      final user = await widget.userService.getUserById(widget.userId);
      setState(() {
        _user = user;
        _isLoading = false;
      });
      _populateControllers();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final updatedUser = {
        'fullName': _fullNameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'gender': _selectedGender,
        'userStatus': _selectedUserStatus,
        'userRole': _selectedUserRole,
        'dateOfBirth': _selectedDateOfBirth?.toIso8601String().split('T')[0],
      };

      await widget.userService.updateUser(widget.userId, updatedUser);
      
      setState(() {
        _isEditing = false;
      });
      
      await _loadUserDetails();
      widget.onUserUpdated?.call();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Utilisateur mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatusUpdateDialog(String newStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer le changement de statut'),
        content: Text('Êtes-vous sûr de vouloir changer le statut de cet utilisateur à "$newStatus" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _selectedUserStatus = newStatus;
              });
              await _updateUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(newStatus),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showRoleUpdateDialog(String newRole) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer le changement de rôle'),
        content: Text('Êtes-vous sûr de vouloir changer le rôle de cet utilisateur à "$newRole" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _selectedUserRole = newRole;
              });
              await _updateUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getRoleColor(newRole),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxWidth = isMobile ? double.infinity : 600.0;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic)),
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
              : _user == null
              ? const SizedBox(
            height: 200,
            child: Center(child: Text('Utilisateur non trouvé')),
          )
              : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDialogHeader(),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 20 : 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildUserCard(),
                            const SizedBox(height: 24),
                            _isEditing ? _buildEditForm() : _buildInfoSection(),
                          ],
                        ),
                      ),
                    ),
                    _buildDialogFooter(isMobile),
                  ],
                ),
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
            child: const Icon(Icons.person_outline, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Détails Utilisateur',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${_user!['userId']}',
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
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getRoleColor(_user!['userRole']).withOpacity(0.1),
            _getRoleColor(_user!['userRole']).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _getRoleColor(_user!['userRole']).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: _getRoleColor(_user!['userRole']).withOpacity(0.15),
            child: Text(
              _getInitials(_user!['fullName'] ?? ''),
              style: TextStyle(
                color: _getRoleColor(_user!['userRole']),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _user!['fullName'] ?? 'N/A',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSmallBadge(
                _user!['userRole'],
                _getRoleColor(_user!['userRole']),
              ),
              const SizedBox(width: 8),
              _buildSmallBadge(
                _user!['userStatus'],
                _getStatusColor(_user!['userStatus']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String? text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        text ?? 'N/A',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Informations Personnelles',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildRoleComboBox(),
                  const SizedBox(height: 8),
                  _buildStatusComboBox(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoRow('ID Utilisateur', _user!['userId'].toString()),
        _buildInfoRow('Nom Complet', _user!['fullName'] ?? 'N/A'),
        _buildInfoRow('Email', _user!['email'] ?? 'N/A'),
        _buildInfoRow('Téléphone', _user!['phone'] ?? 'N/A'),
        _buildInfoRow('Adresse', _user!['address'] ?? 'N/A'),
        _buildInfoRow('Genre', _user!['gender'] ?? 'N/A'),
        _buildInfoRow('Date de Naissance', _formatDate(_user!['dateOfBirth'])),
        const SizedBox(height: 20),
        const Text(
          'Informations de Compte',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow('Rôle', _user!['userRole'] ?? 'N/A'),
        _buildInfoRow('Statut', _user!['userStatus'] ?? 'N/A'),
        _buildInfoRow('Date de Création', _formatDateTime(_user!['createdAt'])),
        _buildInfoRow('Dernière Mise à Jour', _formatDateTime(_user!['lastUpdated'])),
        _buildAvailabilityRow(),
      ],
    );
  }

  Widget _buildRoleComboBox() {
    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 160),
      child: DropdownButtonFormField<String>(
        value: _user!['userRole'],
        decoration: InputDecoration(
          labelText: 'Rôle',
          labelStyle: const TextStyle(fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _getRoleColor(_user!['userRole']), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _getRoleColor(_user!['userRole']), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _getRoleColor(_user!['userRole']), width: 2),
          ),
        ),
        style: TextStyle(
          color: _getRoleColor(_user!['userRole']),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        items: ['ADMIN', 'Delivery', 'Owner', 'Customer'].map((role) {
          return DropdownMenuItem(
            value: role,
            child: Text(
              role,
              style: TextStyle(
                color: _getRoleColor(role),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
        onChanged: (newRole) {
          if (newRole != null && newRole != _user!['userRole']) {
            _showRoleUpdateDialog(newRole);
          }
        },
      ),
    );
  }

  Widget _buildStatusComboBox() {
    return Container(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 160),
      child: DropdownButtonFormField<String>(
        value: _user!['userStatus'],
        decoration: InputDecoration(
          labelText: 'Statut',
          labelStyle: const TextStyle(fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _getStatusColor(_user!['userStatus']), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _getStatusColor(_user!['userStatus']), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _getStatusColor(_user!['userStatus']), width: 2),
          ),
        ),
        style: TextStyle(
          color: _getStatusColor(_user!['userStatus']),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        items: ['ACTIVE', 'INACTIVE', 'BANNED'].map((status) {
          return DropdownMenuItem(
            value: status,
            child: Text(
              status,
              style: TextStyle(
                color: _getStatusColor(status),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
        onChanged: (newStatus) {
          if (newStatus != null && newStatus != _user!['userStatus']) {
            _showStatusUpdateDialog(newStatus);
          }
        },
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modifier les Informations',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _fullNameController,
          decoration: const InputDecoration(
            labelText: 'Nom Complet',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty == true ? 'Requis' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty == true ? 'Requis' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Téléphone',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Adresse',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: const InputDecoration(
            labelText: 'Genre',
            border: OutlineInputBorder(),
          ),
          items: ['MALE', 'FEMALE', 'OTHER'].map((gender) {
            return DropdownMenuItem(value: gender, child: Text(gender));
          }).toList(),
          onChanged: (value) => setState(() => _selectedGender = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedUserRole,
          decoration: const InputDecoration(
            labelText: 'Rôle',
            border: OutlineInputBorder(),
          ),
          items: ['ADMIN', 'Delivery', 'Owner', 'Customer'].map((role) {
            return DropdownMenuItem(value: role, child: Text(role));
          }).toList(),
          onChanged: (value) => setState(() => _selectedUserRole = value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedUserStatus,
          decoration: const InputDecoration(
            labelText: 'Statut',
            border: OutlineInputBorder(),
          ),
          items: ['ACTIVE', 'INACTIVE', 'BANNED'].map((status) {
            return DropdownMenuItem(value: status, child: Text(status));
          }).toList(),
          onChanged: (value) => setState(() => _selectedUserStatus = value),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDateOfBirth ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() => _selectedDateOfBirth = date);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDateOfBirth != null
                      ? _formatDate(_selectedDateOfBirth)
                      : 'Date de Naissance',
                ),
                const Icon(Icons.calendar_today),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

  Widget _buildAvailabilityRow() {
    final isAvailable = _user!['isAvailable'] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              'Disponibilité',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isAvailable ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isAvailable ? Colors.green.withOpacity(0.25) : Colors.orange.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAvailable ? 'Disponible' : 'Occupé',
                    style: TextStyle(
                      color: isAvailable ? Colors.green : Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
              onPressed: () {
                if (_isEditing) {
                  setState(() {
                    _isEditing = false;
                    _populateControllers();
                  });
                } else {
                  Navigator.pop(context);
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey[300]!, width: 1.5),
              ),
              child: Text(
                _isEditing ? 'Annuler' : 'Fermer',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (_isEditing)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _updateUser,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Sauvegarder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Modifier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showDeleteDialog(),
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Supprimer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet utilisateur ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await widget.userService.deleteUser(widget.userId);
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Utilisateur supprimé avec succès'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'ADMIN':
        return Colors.brown;
      case 'Owner':
        return Colors.blue;
      case 'Delivery':
        return Colors.orange;
      case 'Customer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'INACTIVE':
        return Colors.orange;
      case 'BLOCKED':
      case 'BANNED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date.split('T')[0]);
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return 'N/A';
      }
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
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