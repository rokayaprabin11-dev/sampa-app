import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Marks the window as secure (Android FLAG_SECURE) for the lifetime of a
/// [State], so screenshots, screen recording and the app-switcher thumbnail are
/// blocked while a sensitive screen is showing.
///
/// Mix into a screen's [State] and it turns on in `initState`, off in `dispose`.
/// The native side ref-counts, so stacking two secure screens and popping one
/// keeps the window secure until the last leaves.
///
/// Android-only: iOS has no direct FLAG_SECURE equivalent and the calls no-op
/// there, which is the honest outcome rather than a false promise.
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }
}

class SecureScreen {
  SecureScreen._();

  static const MethodChannel _channel = MethodChannel('sampada/secure_screen');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> enable() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('enable');
    } catch (_) {
      // Never let a platform hiccup crash a screen over a hardening flag.
    }
  }

  static Future<void> disable() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod('disable');
    } catch (_) {}
  }
}
