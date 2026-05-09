import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:linqoraremote/core/constants/settings.dart';
import 'package:linqoraremote/core/themes/lx_theme.dart';
import 'package:linqoraremote/presentation/widgets/lx_background.dart';
import 'package:linqoraremote/presentation/widgets/lx_glass.dart';
import 'package:linqoraremote/routes/app_routes.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _ctrl = PageController();
  int _page = 0;
  static const _total = 3;

  void _next() {
    if (_page < _total - 1) {
      _ctrl.nextPage(duration: 400.ms, curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _finish() {
    GetStorage(SettingsConst.kSettings)
        .write(SettingsConst.kOnboardingComplete, true);
    Get.offAllNamed(AppRoutes.DEVICE_AUTH);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LxBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 20),
                  child: AnimatedOpacity(
                    opacity: _page < _total - 1 ? 1.0 : 0.0,
                    duration: 300.ms,
                    child: GestureDetector(
                      onTap: _finish,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'SKIP',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.5,
                            color: lxTextFaint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Slide content
              Expanded(
                child: PageView(
                  controller: _ctrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: const [
                    _WelcomeSlide(),
                    _HowItWorksSlide(),
                    _ConnectMethodsSlide(),
                  ],
                ),
              ),
              // Dots + CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Dots(current: _page, total: _total),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: LxGlass(
                        accent: true,
                        onTap: _next,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          _page < _total - 1 ? 'CONTINUE' : 'GET STARTED',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: lxAccent,
                            letterSpacing: 1.5,
                          ),
                        ),
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

// ─── Page indicator dots ─────────────────────────────────────────────────────

class _Dots extends StatelessWidget {
  final int current, total;
  const _Dots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: 300.ms,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? lxAccent : lxTextGhost,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ─── Slide 1: Welcome ────────────────────────────────────────────────────────

class _WelcomeSlide extends StatelessWidget {
  const _WelcomeSlide();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _GlowRing()
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.7, 0.7)),
          const SizedBox(height: 48),
          const Text(
            'LINQORA',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 10,
              color: lxText,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
          const SizedBox(height: 12),
          const Text(
            'Your PC. In your pocket.',
            style: TextStyle(
              fontSize: 17,
              color: lxAccent,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ).animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 20),
          const Text(
            'Secure, fast, beautiful remote control\nfor your desktop — over local Wi-Fi.',
            style: TextStyle(fontSize: 14, color: lxTextDim, height: 1.7),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 500.ms),
        ],
      ),
    );
  }
}

class _GlowRing extends StatefulWidget {
  const _GlowRing();
  @override
  State<_GlowRing> createState() => _GlowRingState();
}

class _GlowRingState extends State<_GlowRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      builder: (_, __) {
        final t = _ac.value;
        final pulse1 = math.sin(t * 2 * math.pi).abs();
        final pulse2 = math.sin(t * 2 * math.pi + 1.0).abs();
        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: lxAccent.withValues(alpha: 0.08 + 0.12 * pulse1),
                    width: 1,
                  ),
                ),
              ),
              Container(
                width: 136,
                height: 136,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: lxAccent.withValues(alpha: 0.18 + 0.10 * pulse2),
                    width: 1,
                  ),
                  color: lxAccent.withValues(alpha: 0.03),
                ),
              ),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lxAccent.withValues(alpha: 0.08),
                  border: Border.all(
                    color: lxAccent.withValues(alpha: 0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: lxAccent.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: -4,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.computer_rounded, size: 36, color: lxAccent),
            ],
          ),
        );
      },
    );
  }
}

// ─── Slide 2: How It Works ───────────────────────────────────────────────────

class _HowItWorksSlide extends StatelessWidget {
  const _HowItWorksSlide();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How it works',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: lxText,
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
          const SizedBox(height: 6),
          const Text(
            "Three steps. That's it.",
            style: TextStyle(fontSize: 14, color: lxTextDim),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 32),
          _HowStep(
            icon: Icons.download_rounded,
            color: lxAccent,
            delay: 0,
            title: 'Install LinqoraHost',
            desc: 'Download and run the host on your Windows, Linux, or macOS PC.',
          ),
          const SizedBox(height: 14),
          _HowStep(
            icon: Icons.wifi_rounded,
            color: lxGreen,
            delay: 100,
            title: 'Same Wi-Fi network',
            desc: 'Connect both your phone and PC to the same local network.',
          ),
          const SizedBox(height: 14),
          _HowStep(
            icon: Icons.flash_on_rounded,
            color: lxAmber,
            delay: 200,
            title: 'Pair & take control',
            desc: 'Scan a QR, auto-discover, or type the IP — one tap to connect.',
          ),
        ],
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, desc;
  final int delay;

  const _HowStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return LxGlass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(lxRadiusInner),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: lxText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: lxTextDim,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.15);
  }
}

// ─── Slide 3: Connection Methods ─────────────────────────────────────────────

class _ConnectMethodsSlide extends StatelessWidget {
  const _ConnectMethodsSlide();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Three ways to connect',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: lxText,
            ),
          ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
          const SizedBox(height: 6),
          const Text(
            'Switch methods anytime from the connect screen.',
            style: TextStyle(fontSize: 14, color: lxTextDim),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 32),
          _MethodCard(
            icon: Icons.qr_code_scanner_rounded,
            color: lxAccent,
            delay: 0,
            title: 'Scan QR Code',
            desc: 'Open LinqoraHost on your PC and scan the QR shown in the app.',
          ),
          const SizedBox(height: 14),
          _MethodCard(
            icon: Icons.radar_rounded,
            color: lxGreen,
            delay: 100,
            title: 'Auto-Discover',
            desc: 'Linqora finds your PC automatically using mDNS on your network.',
          ),
          const SizedBox(height: 14),
          _MethodCard(
            icon: Icons.keyboard_rounded,
            color: lxAmber,
            delay: 200,
            title: 'Manual IP Entry',
            desc: "Know your PC's IP address? Enter it directly to connect.",
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: () => Get.toNamed(AppRoutes.HOW_IT_WORKS),
              child: const Text(
                'Learn how it works →',
                style: TextStyle(
                  color: lxAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, desc;
  final int delay;

  const _MethodCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return LxGlass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(lxRadiusCard),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: lxText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: lxTextDim,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: lxTextFaint,
          ),
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.1);
  }
}
