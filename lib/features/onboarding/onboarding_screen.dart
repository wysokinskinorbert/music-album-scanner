import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/haptic_service.dart';

/// 3-page onboarding flow shown on first launch.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();

  /// Check if onboarding has been completed.
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }

  /// Mark onboarding as completed.
  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
  }
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  static const _totalPages = 3;

  final _pages = [
    _OnboardingPageData(
      icon: Icons.camera_alt_rounded,
      title: 'Scan Your Vinyl',
      description: 'Point your camera at any album cover.\n\nWorks with vinyl records, CDs, cassettes, and digital covers.',
      gradient: [AppColors.primary, AppColors.primaryLight],
      lottieAsset: null,
    ),
    _OnboardingPageData(
      icon: Icons.auto_awesome,
      title: 'Instant Recognition',
      description: 'AI identifies the album using barcode, text recognition, and visual analysis.\n\nWorks offline too!',
      gradient: [Colors.orange, Colors.amber],
      lottieAsset: null,
    ),
    _OnboardingPageData(
      icon: Icons.library_music,
      title: 'Build Your Collection',
      description: 'Organize, filter, and explore your music library.\n\nTrack what you own and what you\'re looking for.',
      gradient: [Colors.green, Colors.teal],
      lottieAsset: null,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skip,
                child: const Text(
                  'Skip',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  HapticService.selection();
                },
                itemCount: _totalPages,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _buildPage(page, index);
                },
              ),
            ),

            // Page indicators + buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppColors.primary
                              : AppColors.textTertiary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Next / Get Started
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _currentPage == _totalPages - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  // Back button (not on first page)
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      child: const Text(
                        'Back',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPageData page, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: page.gradient,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: page.gradient[0].withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                page.icon,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      HapticService.medium();
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _complete();
    }
  }

  void _previousPage() {
    HapticService.light();
    _controller.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _skip() {
    _complete();
  }

  Future<void> _complete() async {
    HapticService.medium();
    await OnboardingScreen.markComplete();
    widget.onComplete();
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  final String? lottieAsset;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    this.lottieAsset,
  });
}
