import 'package:ali_app/services/splash_services.dart';
import 'package:ali_app/utils/app_theme.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  // Create an instance of SplashServices
  SplashServices splashServices = SplashServices();

  @override
  void initState() {
    super.initState();
    // This runs once when screen opens — starts the 3 second timer
    splashServices.isLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.emerald,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.construction_rounded,
                size: 48,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 24),
            // App logo or name
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Thekay',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  TextSpan(
                    text: 'Daar.ᴘᴋ',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.gold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Loading spinner
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}