import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/theme.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isTablet = MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 1200;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: isMobile
              ? _buildMobileLayout()
              : isTablet
              ? _buildTabletLayout()
              : _buildWebLayout(),
        ),
      ),
    );
  }

  // Mobile Layout
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildLogoSection(isMobile: true),
            _buildFormSection(isMobile: true),
          ],
        ),
      ),
    );
  }

  // Tablet Layout
  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildLogoSection(isMobile: false),
            const SizedBox(height: 40),
            _buildFormSection(isMobile: false),
          ],
        ),
      ),
    );
  }

  // Web Layout - EXACTLY LIKE LOGIN
  Widget _buildWebLayout() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: _buildLogoSection(isMobile: false, isWeb: true),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: AppColors.surface,
              child: _buildFormSection(isMobile: false, isWeb: true),
            ),
          ),
        ],
      ),
    );
  }

  // Logo Section with Glassmorphism
  Widget _buildLogoSection({bool isMobile = false, bool isWeb = false}) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 24 : 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo Container with Glassmorphism Effect
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: isMobile ? 100 : 140,
                  height: isMobile ? 100 : 140,
                  decoration: BoxDecoration(
                    color: AppColors.textLight,
                    borderRadius: BorderRadius.circular(isMobile ? 24 : 35),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isMobile ? 24 : 35),
                    child: Image.asset(
                      'lib/core/assets/jibli_logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.local_shipping_rounded,
                          size: isMobile ? 50 : 70,
                          color: AppColors.primary,
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Animated Title
              TweenAnimationBuilder<double>(
                tween: Tween(begin: -50, end: 0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: (value + 50) / 50,
                    child: Transform.translate(
                      offset: Offset(0, value),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  'Jibli',
                  style: TextStyle(
                    fontSize: isMobile ? 48 : 64,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textLight,
                    letterSpacing: 4,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(0, 4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Subtitle with gradient
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    colors: [
                      AppColors.textLight,
                      AppColors.textLight.withOpacity(0.7),
                    ],
                  ).createShader(bounds);
                },
                child: Text(
                  'Rejoins la communauté',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                  ),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textLight.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.textLight.withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textLight.withOpacity(0.05),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Text(
                    '🎉 Crée ton compte gratuitement',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textLight.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced Form Section with Glassmorphism
  Widget _buildFormSection({bool isMobile = false, bool isWeb = false}) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 24 : isWeb ? 40 : 32),
        child: Container(
          constraints: BoxConstraints(maxWidth: isWeb ? 520 : double.infinity),
          decoration: isWeb
              ? null
              : BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(40),
              topRight: Radius.circular(40),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 40,
                offset: const Offset(0, -10),
                spreadRadius: 4,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 28 : 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with Animation
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: -30, end: 0),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: (value + 30) / 30,
                        child: Transform.translate(
                          offset: Offset(0, value),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          'Inscription',
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 36,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Crée ton compte gratuitement',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Error Message with Animation
                  if (_errorMessage != null)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.scale(
                            scale: 0.8 + (value * 0.2),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.danger.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.danger.withOpacity(0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.danger,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 24),

                  // Full Name Input
                  _buildModernInput(
                    controller: _fullNameController,
                    label: 'Nom complet',
                    hint: 'Ex: Ahmed Mohamed',
                    icon: Icons.person_outline_rounded,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Nom complet requis';
                      if (value!.length < 3) return 'Min. 3 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Email Input
                  _buildModernInput(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'exemple@email.com',
                    icon: Icons.mail_outline_rounded,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Email requis';
                      if (!value!.contains('@') || !value.contains('.')) {
                        return 'Email invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Phone Input
                  _buildModernInput(
                    controller: _phoneController,
                    label: 'Téléphone',
                    hint: '20612345678',
                    icon: Icons.phone_outlined,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Téléphone requis';
                      final digitsOnly = value!.replaceAll(RegExp(r'[^\d]'), '');
                      if (digitsOnly.length != 8) {
                        return 'Le numéro doit contenir 8 chiffres';
                      }
                      return null;
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Password Input
                  _buildPasswordInput(
                    controller: _passwordController,
                    label: 'Mot de passe',
                    obscured: _obscurePassword,
                    onToggle: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Mot de passe requis';
                      if (value!.length < 6) return 'Min. 6 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Confirm Password Input
                  _buildPasswordInput(
                    controller: _confirmPasswordController,
                    label: 'Confirmer le mot de passe',
                    obscured: _obscureConfirmPassword,
                    onToggle: () => setState(
                            () => _obscureConfirmPassword = !_obscureConfirmPassword),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Les mots de passe ne correspondent pas';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Modern Register Button
                  _buildModernButton(
                    label: 'S\'inscrire',
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _register,
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 24),

                  // Modern Divider
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.border.withOpacity(0),
                                AppColors.border.withOpacity(0.5),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Déjà inscrit?',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.border.withOpacity(0.5),
                                AppColors.border.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Login Link with Modern Style
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Se connecter',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Modern Input Field
  Widget _buildModernInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.text,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        filled: true,
        fillColor: AppColors.surfaceVariant.withOpacity(0.8),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withOpacity(0.6),
          fontSize: 14,
        ),
      ),
      validator: validator,
    );
  }

  // Modern Password Input
  Widget _buildPasswordInput({
    required TextEditingController controller,
    required String label,
    required bool obscured,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscured,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(Icons.lock_outline_rounded,
              color: AppColors.primary, size: 22),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: AppColors.textSecondary,
            size: 22,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.danger, width: 2),
        ),
        filled: true,
        fillColor: AppColors.surfaceVariant.withOpacity(0.8),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      validator: validator,
    );
  }

  // Modern Button
  Widget _buildModernButton({
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
    required bool isMobile,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 16 : 18,
            ),
            child: isLoading
                ? Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: AppColors.textLight,
                  strokeWidth: 2.5,
                ),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_rounded,
                    color: AppColors.textLight, size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textLight,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService().register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Inscription réussie! Connecte-toi maintenant.'),
            duration: Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        Navigator.pop(context);
      }
    } catch (e) {
      String errorMessage = 'Erreur lors de l\'inscription.';
      String exceptionString = e.toString();

      print('🔍 Raw error: $exceptionString');

      // ✅ HANDLE SPECIFIC ERROR MESSAGES FROM BACKEND
      if (exceptionString.contains('Email already registered')) {
        errorMessage = 'Cet email est déjà enregistré. Veuillez utiliser un autre email.';
      } else if (exceptionString.contains('Phone number already registered')) {
        errorMessage = 'Ce numéro de téléphone est déjà enregistré. Veuillez utiliser un autre numéro.';
      } else if (exceptionString.contains('Phone number must contain exactly 8 digits')) {
        errorMessage = 'Le numéro de téléphone doit contenir exactement 8 chiffres.';
      } else if (exceptionString.contains('Password must be at least 6 characters')) {
        errorMessage = 'Le mot de passe doit contenir au moins 6 caractères.';
      } else if (exceptionString.contains('Full name is required')) {
        errorMessage = 'Le nom complet est requis.';
      } else if (exceptionString.contains('Phone number is required')) {
        errorMessage = 'Le numéro de téléphone est requis.';
      } else if (exceptionString.contains('Password is required')) {
        errorMessage = 'Le mot de passe est requis.';
      } else if (exceptionString.contains('Invalid email format')) {
        errorMessage = 'Format d\'email invalide.';
      } else if (exceptionString.contains('timeout')) {
        errorMessage = 'Délai d\'attente dépassé. Veuillez réessayer.';
      } else if (exceptionString.contains('Registration failed')) {
        errorMessage = 'Erreur lors de l\'inscription. Veuillez réessayer.';
      }

      setState(() {
        _errorMessage = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}