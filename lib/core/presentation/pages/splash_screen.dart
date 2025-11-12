import 'package:flutter/material.dart';
import 'dart:math';
import '../../theme/theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _backgroundController;
  late AnimationController _particleController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _backgroundOpacity;
  late Animation<double> _particleRotation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimationSequence();
  }

  void _initAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    // Logo animations
    _logoScale = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    // Text animations
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutCubic,
    ));

    // Background fade
    _backgroundOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    // Particle rotation
    _particleRotation = Tween<double>(
      begin: 0.0,
      end: 360.0,
    ).animate(_particleController);
  }

  void _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 1800));
    _backgroundController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
          widget.nextScreen,
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _backgroundController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(_backgroundOpacity.value),
                  AppColors.primary
                      .withOpacity(_backgroundOpacity.value * 0.85),
                  AppColors.secondary.withOpacity(_backgroundOpacity.value),
                  AppColors.accent.withOpacity(_backgroundOpacity.value * 0.7),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Animated background elements
                _buildAnimatedBackground(),

                // Floating particles
                _buildParticles(),

                // Main content
                Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo with glow effect
                        AnimatedBuilder(
                          animation: _logoController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _logoScale.value,
                              child: Opacity(
                                opacity: _logoOpacity.value,
                                child: Container(
                                  width: isMobile ? 140 : isTablet ? 180 : 200,
                                  height: isMobile ? 140 : isTablet ? 180 : 200,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withOpacity(0.4),
                                        blurRadius: 40,
                                        spreadRadius: 10,
                                        offset: const Offset(0, 15),
                                      ),
                                      BoxShadow(
                                        color: AppColors.secondary
                                            .withOpacity(0.2),
                                        blurRadius: 60,
                                        spreadRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white,
                                          Colors.grey[50]!,
                                        ],
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'lib/core/assets/jibli_logo.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error,
                                            stackTrace) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              gradient:
                                              AppColors.primaryGradient,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.restaurant_menu_rounded,
                                              size: 80,
                                              color: Colors.white,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        SizedBox(
                            height: isMobile ? 40 : isTablet ? 50 : 60),

                        // Text content
                        AnimatedBuilder(
                          animation: _textController,
                          builder: (context, child) {
                            return SlideTransition(
                              position: _textSlide,
                              child: FadeTransition(
                                opacity: _textOpacity,
                                child: Column(
                                  children: [
                                    // App name with letter spacing
                                    Text(
                                      'Jibli',
                                      style: TextStyle(
                                        fontSize: isMobile
                                            ? 56
                                            : isTablet
                                            ? 72
                                            : 88,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -1.5,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black
                                                .withOpacity(0.25),
                                            offset: const Offset(0, 6),
                                            blurRadius: 12,
                                          ),
                                          Shadow(
                                            color: AppColors.primary
                                                .withOpacity(0.3),
                                            offset: const Offset(0, 3),
                                            blurRadius: 20,
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // Tagline
                                    Text(
                                      'Votre plateforme de livraison',
                                      style: TextStyle(
                                        fontSize: isMobile
                                            ? 15
                                            : isTablet
                                            ? 18
                                            : 22,
                                        fontWeight: FontWeight.w600,
                                        color:
                                        Colors.white.withOpacity(0.95),
                                        letterSpacing: 0.3,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    // Subtitle
                                    Text(
                                      'Commandes rapides • Livraison fiable',
                                      style: TextStyle(
                                        fontSize: isMobile ? 12 : 14,
                                        fontWeight: FontWeight.w400,
                                        color:
                                        Colors.white.withOpacity(0.75),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Top-right circle
        Positioned(
          top: -120,
          right: -120,
          child: AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.8 + _logoController.value * 0.3,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.05),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Bottom-left circle
        Positioned(
          bottom: -150,
          left: -150,
          child: AnimatedBuilder(
            animation: _textController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.9 + _textController.value * 0.2,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.03),
                        blurRadius: 40,
                        spreadRadius: 15,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Center accent circle
        Positioned(
          top: MediaQuery.of(context).size.height * 0.5,
          right: MediaQuery.of(context).size.width * 0.05,
          child: AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _particleRotation.value * pi / 180,
                child: Opacity(
                  opacity: 0.03,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParticles() {
    return Stack(
      children: List.generate(6, (index) {
        final delay = index * 0.15;
        final size = 3.0 + (index * 1.5);
        final distance = 60.0 + (index * 20.0);

        return AnimatedBuilder(
          animation: _particleController,
          builder: (context, child) {
            final progress = (_particleController.value + delay) % 1.0;
            final angle =
                (progress * 360 * pi / 180) + (index * 60 * pi / 180);
            final x = distance * cos(angle);
            final y = distance * sin(angle);

            return Transform.translate(
              offset: Offset(x, y),
              child: Opacity(
                opacity: (1 - (progress - 0.8).abs() * 5).clamp(0, 1) * 0.6,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}