// =============================================================================
// language_toggle_widget.dart
// A compact EN / UR toggle chip for Thekaydaar.pk screens.
// Listens to TranslationService and rebuilds when language changes.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:ali_app/services/translation_service.dart';

const Color _navy = Color(0xFF0E3B2E);
const Color _amber = Color(0xFFC9A227);
const Color _surface = Color(0xFFF7F5EF);
const Color _border = Color(0xFFE3E0D5);

/// A small, pill-shaped language toggle chip.
/// Place it in AppBars, headers, or anywhere users should be able
/// to switch between English and Urdu.
class LanguageToggleChip extends StatelessWidget {
  final bool compact; // smaller variant for tight spaces

  const LanguageToggleChip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TranslationService.instance,
      builder: (context, _) {
        final isUrdu = TranslationService.instance.isUrdu;
        return GestureDetector(
          onTap: () => TranslationService.instance.toggleLanguage(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: isUrdu ? _navy : _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isUrdu ? _amber : _border,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: isUrdu ? 0.15 : 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: compact ? 13 : 15,
                  color: isUrdu ? _amber : _navy,
                ),
                SizedBox(width: compact ? 4 : 6),
                Text(
                  isUrdu ? 'اردو' : 'EN',
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: isUrdu ? Colors.white : _navy,
                    fontFamily: isUrdu ? 'Jameel-Noori-Nastaleeq' : null,
                  ),
                ),
                SizedBox(width: compact ? 4 : 6),
                // Toggle dots
                Container(
                  width: compact ? 28 : 34,
                  height: compact ? 12 : 14,
                  decoration: BoxDecoration(
                    color: (isUrdu ? _amber : _navy).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _dot(!isUrdu, compact), // EN dot
                      SizedBox(width: compact ? 2 : 3),
                      _dot(isUrdu, compact),  // UR dot
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dot(bool active, bool compact) {
    return Container(
      width: compact ? 8 : 10,
      height: compact ? 8 : 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? _amber : Colors.grey.shade300,
      ),
      child: active
          ? Icon(
              Icons.check_rounded,
              size: compact ? 6 : 8,
              color: Colors.white,
            )
          : null,
    );
  }
}

/// A builder widget that listens to TranslationService and rebuilds.
/// Wrap any widget tree with this to get automatic language switching.
class LanguageBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, TranslationService t) builder;

  const LanguageBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: TranslationService.instance,
      builder: (context, _) => builder(context, TranslationService.instance),
    );
  }
}
