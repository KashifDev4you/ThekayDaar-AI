import 'dart:async';
import 'package:ali_app/onboardingScreens/onboarding_screen.dart';
import 'package:flutter/material.dart';

class SplashServices {

  void isLogin(BuildContext context) {
    // Wait 3 seconds then go to LoginScreen
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement( // ✅ pushReplacement removes SplashScreen from history
        context,
        MaterialPageRoute(
          builder: (context) => const OnboardingScreen(), // ✅ Navigate to OnboardingScreen after splash
        ),
      );
    });
  }
}