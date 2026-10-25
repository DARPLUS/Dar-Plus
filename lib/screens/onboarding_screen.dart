import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/dar_plus_logo.dart';
import '../widgets/frosted_skip_button.dart';
import '../widgets/page_indicator.dart';
import 'register_screen.dart';
import 'login_screen.dart';

class OnboardingModel {
  final String imagePath;
  final String title;
  final String subtitle;
  final Color primaryColor;

  const OnboardingModel({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingModel> _slides = const [
    OnboardingModel(
      imagePath: 'assets/images/slide_1_bg.png',
      title: 'Des pros à votre service',
      subtitle:
          'Trouvez rapidement un professionnel qualifié pour tous vos besoins à domicile.',
      primaryColor: AppTheme.tealPrimary,
    ),
    OnboardingModel(
      imagePath: 'assets/images/slide_2_bg.png',
      title: 'Réservez en quelques clics',
      subtitle:
          'Choisissez votre date, votre heure et confirmez votre demande facilement.',
      primaryColor: AppTheme.orangePrimary,
    ),
    OnboardingModel(
      imagePath: 'assets/images/slide_3_bg.png',
      title: 'Paiement sécurisé & Avis vérifiés',
      subtitle:
          'Payez en toute sécurité et lisez les avis vérifiés de vrais clients.',
      primaryColor: AppTheme.tealPrimary,
    ),
  ];

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _goToHome();
    }
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => const RegisterScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => const LoginScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSlide = _slides[_currentPage];
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // 1. Swipable PageView
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final slide = _slides[index];

              return Column(
                children: [
                  // Top Image with smooth fade gradient into background
                  SizedBox(
                    height: size.height * 0.50,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background image
                        Image.asset(
                          slide.imagePath,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to full screenshot if background crop is missing
                            return Image.asset(
                              'assets/images/onboarding_${index + 1}.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            );
                          },
                        ),
                        // Smooth gradient overlay to blend into the cream background
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.45, 0.82, 1.0],
                                colors: [
                                  Colors.transparent,
                                  Colors.transparent,
                                  AppTheme.background.withValues(alpha: 0.7),
                                  AppTheme.background,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Middle Content: Page Indicator, Title, Subtitle
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          // Dots Indicator
                          SlidePageIndicator(
                            count: _slides.length,
                            currentIndex: index,
                            activeColor: slide.primaryColor,
                          ),
                          const SizedBox(height: 32),
                          // Title (Serif typography)
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.titleColor,
                              height: 1.25,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Subtitle (Sans-serif typography)
                          Text(
                            slide.subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'sans-serif',
                              fontSize: 15,
                              color: AppTheme.subtitleColor,
                              height: 1.45,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 2. Fixed Top Header: DAR PLUS Logo Pill & Passer Button
          Positioned(
            top: topPadding + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 72), // Spacer to balance with Passer button
                // Center Brand Pill
                DarPlusLogoPill(
                  badgeColor: currentSlide.primaryColor,
                ),
                // Right Passer (Skip) Button
                FrostedSkipButton(
                  onTap: _goToLogin,
                ),
              ],
            ),
          ),

          // 3. Bottom Action Buttons
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _currentPage == _slides.length - 1
                // Last slide: Two buttons ("Commencer" & "Connexion")
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Commencer button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _goToHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.tealPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Commencer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Connexion button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _goToLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryButtonBg,
                            foregroundColor: AppTheme.titleColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Connexion',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                // Slides 1 & 2: Single button ("Suivant")
                : SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentSlide.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Suivant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
