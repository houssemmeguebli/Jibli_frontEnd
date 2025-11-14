import 'package:flutter/material.dart';

class PromotionBanner extends StatefulWidget {
  final int bannerIndex;

  const PromotionBanner({
    super.key,
    this.bannerIndex = 0,
  });

  @override
  State<PromotionBanner> createState() => _FoodDeliveryBannerState();
}

class _FoodDeliveryBannerState extends State<PromotionBanner>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> getBanners() {
    return [
      {
        'gradient': [Color(0xFFFF6B35), Color(0xFFFF8C42)],
        'accentColor': Color(0xFFFFA500),
        'icon': '🍕',
        'badge': 'أحلى عروض 🔥',
        'title': 'بيتزا ما تتفوتش 🔥',
        'subtitle': 'ذوق و وفّر مع التخفيضات!',
      },
      {
        'gradient': [Color(0xFF00D4FF), Color(0xFF0099FF)],
        'accentColor': Color(0xFF00E5FF),
        'icon': '🍔',
        'badge': ' برومو 💥',
        'title': 'برغر كيما تحب 😍',
        'subtitle': 'طلّبها و خذ عرض خيالي!',
      },
      {
        'gradient': [Color(0xFF10B981), Color(0xFF059669)],
        'accentColor': Color(0xFF34D399),
        'icon': '🥗',
        'badge': 'ماكلة صحّية 🌿',
        'title': 'خِفّة و بنّة',
        'subtitle': 'عيش بصحّتك و اربح بالعروض!',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final banners = getBanners();
    final banner = banners[widget.bannerIndex % banners.length];

    return FadeTransition(
      opacity: _fadeController,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
            .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic)),
        child: Container(
          height: 180,
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: banner['gradient'],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (banner['gradient'][0] as Color).withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: (banner['gradient'][1] as Color).withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Animated background circles
              Positioned(
                top: -80,
                right: -60,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -80,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              // Premium badge
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: banner['accentColor'],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        banner['badge'],
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Icon container with glow effect
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        banner['icon'],
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Subtitle tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              banner['badge'],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Main title
                          Text(
                            banner['title'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          // Subtitle
                          Text(
                            banner['subtitle'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}