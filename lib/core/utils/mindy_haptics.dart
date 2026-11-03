import 'package:flutter/services.dart';

/// Small, optional tactile cues. Flutter and the platform silently ignore
/// these on devices without a supported vibrator or haptic engine.
abstract final class MindyHaptics {
  static Future<void> selection() => HapticFeedback.selectionClick();
  static Future<void> success() => HapticFeedback.mediumImpact();
  static Future<void> error() => HapticFeedback.heavyImpact();
}
