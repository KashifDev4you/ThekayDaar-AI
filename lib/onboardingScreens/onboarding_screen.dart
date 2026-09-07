// =============================================================================
// onboarding_Screen.dart — Minimal, light, smooth
//
// Design philosophy:
//   • Pure white background — nothing competing with the Lottie
//   • Navy + amber only where they COUNT (one word, one button)
//   • Text fades + slides up on page change — nothing else animates
//   • No badges, no pills, no cards, no shadows, no heavy containers
//   • Auto-advance 5s, manual swipe, hot-restart safe (no _currentPage)
// =============================================================================

import 'dart:async';
import 'package:ali_app/main.dart';
import 'package:ali_app/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// ─────────────────────────────────────────────────────────────────
// Slide data
// ─────────────────────────────────────────────────────────────────
class _Slide {
  final String heading;   // plain part
  final String accent;    // amber word (appended after heading)
  final String urdu;
  final String lottie;
  const _Slide(this.heading, this.accent, this.urdu, this.lottie);
}

const _slides = [
  _Slide(
    'Build with\n',
    'TheKaydaar',
    'ہمارے ساتھ اپنے خواب گھر کی تعمیر کریں',
    'assets/animation/Construction.json',
  ),
  _Slide(
    'Trusted by\n',
    'Thousands',
    'ہمارے ساتھ آسانی سے بناوٹ کریں اور محفوظ رہیں',
    'assets/animation/Business_deal.json',
  ),
  _Slide(
    'Right from\nyour ',
    'Mobile',
    'ہماری پیش کش کا انتخاب کریں اور اپنی ضروریات کے مطابق بات کریں',
    'assets/animation/Voicemail.json',
  ),
];

// ─────────────────────────────────────────────────────────────────
// OnboardingScreen
// ─────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {

  final _pageCtrl = PageController();
  int _idx = 0;
  Timer? _timer;

  // Text fade+slide animation
  late AnimationController _textCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _textCtrl = AnimationController(
      vsync   : this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim  = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end  : Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    _textCtrl.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _advance());
  }

  void _advance() {
    final next = (_idx + 1) % _slides.length;
    _pageCtrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 500),
      curve   : Curves.easeInOut,
    );
  }

  void _onPageChanged(int i) {
    // Fade out → update → fade in
    _textCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _idx = i);
      _textCtrl.forward();
    });
    _startTimer(); // reset timer on manual swipe too
  }

  void _next() {
    if (_idx == _slides.length - 1) {
      _goHome();
    } else {
      _advance();
    }
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder    : (_, a, _) => const HomeScreen(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: a,
          child  : child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide  = _slides[_idx];
    final isLast = _idx == _slides.length - 1;
    final size   = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [

            // ── Skip ──────────────────────────────────────────
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 20),
                child: TextButton(
                  onPressed: _goHome,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textMuted,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),

            // ── Lottie — full width, clean white bg ───────────
            SizedBox(
              height: size.height * 0.42,
              child: PageView.builder(
                controller  : _pageCtrl,
                onPageChanged: _onPageChanged,
                itemCount   : _slides.length,
                itemBuilder : (_, i) => Lottie.asset(
                  _slides[i].lottie,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // ── Dot indicators ────────────────────────────────
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _idx;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve   : Curves.easeInOut,
                  margin  : const EdgeInsets.symmetric(horizontal: 4),
                  width   : active ? 22 : 7,
                  height  : 7,
                  decoration: BoxDecoration(
                    color       : active ? AppTheme.emerald : AppTheme.textMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            // ── Text block — fades + slides on change ─────────
            const SizedBox(height: 28),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Headline
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontFamily  : 'Poppins',
                              fontSize    : 28,
                              fontWeight  : FontWeight.w700,
                              color       : AppTheme.emerald,
                              height      : 1.2,
                              letterSpacing: -0.3,
                            ),
                            children: [
                              TextSpan(text: slide.heading),
                              TextSpan(
                                text : slide.accent,
                                style: const TextStyle(color: AppTheme.gold),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Urdu subtitle
                        Text(
                          slide.urdu,
                          textAlign    : TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontFamily: 'Jameel-Noori-Nastaleeq',
                            fontSize  : 16,
                            color     : AppTheme.textMuted,
                            height    : 1.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Next / Get Started button ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: SizedBox(
                width : double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.emerald,
                    elevation      : 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLast ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          fontSize  : 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}