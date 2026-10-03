import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      icon: Icons.search_rounded,
      title: 'Spot Breeding Hazards',
      description:
          'Identify stagnant water, discarded tires, and unmaintained gutters before larvae turn into dangerous dengue vectors.',
      color: Color(0xFF00897B),
    ),
    _OnboardingItem(
      icon: Icons.camera_alt_outlined,
      title: 'AI Hazard Verification',
      description:
          'Snap a photo with instant GPS location. Our backend AI assists health inspectors in identifying larvae breeding environments.',
      color: Color(0xFFFFB300),
    ),
    _OnboardingItem(
      icon: Icons.military_tech_outlined,
      title: 'Protect & Earn Civic Points',
      description:
          'Help Public Health Inspectors verify cleanups, safeguard your neighborhood, and earn community guardian badges.',
      color: Color(0xFF43A047),
    ),
  ];

  Future<void> _finishOnboarding() async {
    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _items.length - 1;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!isLastPage)
            TextButton(
              onPressed: _finishOnboarding,
              child: const Text('Skip', style: TextStyle(color: Color(0xFF00897B), fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, size: 70, color: item.color),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.description,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                                height: 1.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicator dots
                  Row(
                    children: List.generate(
                      _items.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF00897B)
                              : Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Action Button
                  ElevatedButton(
                    key: const Key('onboarding_action_button'),
                    onPressed: () {
                      if (isLastPage) {
                        _finishOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(isLastPage ? 'Get Started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
