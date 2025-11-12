class User {
  final int id;
  final String email;
  final String? phone;
  final String? fullName;
  final List<String> roles;

  User({
    required this.id,
    required this.email,
    this.phone,
    this.fullName,
    required this.roles,
  });

  bool hasRole(String role) => roles.contains(role.toUpperCase());
  bool get isAdmin => hasRole('ADMIN');
  bool get isOwner => hasRole('OWNER');
  bool get isDelivery => hasRole('DELIVERY');
  bool get isCustomer => hasRole('CUSTOMER');
}