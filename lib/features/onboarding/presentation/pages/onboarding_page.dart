import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_image.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/app_colors.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';

final class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

final class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;
  int _currentPage = 0;

  List<_OnboardingStep> _steps(BuildContext context) => [
        _OnboardingStep(
          title: context.l10n.onboardingExquisiteTitle,
          body: context.l10n.onboardingExquisiteBody,
          imagePath: 'assets/images/onboarding/fabric-silk.svg',
        ),
        _OnboardingStep(
          title: context.l10n.onboardingCraftsmanshipTitle,
          body: context.l10n.onboardingCraftsmanshipBody,
          imagePath: 'assets/images/onboarding/fabric-woven.svg',
        ),
        _OnboardingStep(
          title: context.l10n.onboardingExcellenceTitle,
          body: context.l10n.onboardingExcellenceBody,
          imagePath: 'assets/images/onboarding/fabric-velvet.svg',
        ),
      ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _complete() {
    context.read<OnboardingCubit>().complete();
  }

  void _next(List<_OnboardingStep> steps) {
    if (_currentPage == steps.length - 1) {
      _complete();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingCubit, OnboardingState>(
      listenWhen: (previous, current) =>
          previous.destination != current.destination &&
          current.destination == OnboardingDestination.home,
      listener: (_, __) => context.go('/home'),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final steps = _steps(context);
              final imageHeight =
                  (constraints.maxHeight * .55).clamp(240.0, 520.0).toDouble();
              return PageView.builder(
                controller: _pageController,
                itemCount: steps.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (_, index) => _OnboardingStepView(
                  step: steps[index],
                  imageHeight: imageHeight,
                  currentPage: _currentPage,
                  onNext: () => _next(steps),
                  onSkip: _complete,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _OnboardingStepView extends StatelessWidget {
  const _OnboardingStepView({
    required this.step,
    required this.imageHeight,
    required this.currentPage,
    required this.onNext,
    required this.onSkip,
  });

  final _OnboardingStep step;
  final double imageHeight;
  final int currentPage;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isLastPage = currentPage == 2;

    return Column(
      children: [
        SizedBox(
          height: imageHeight,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(
                source: step.imagePath,
                fit: BoxFit.cover,
                placeholder: ColoredBox(
                  color: scheme.surfaceContainerHigh,
                  child: Icon(Icons.texture, size: 72, color: scheme.primary),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.black.withValues(alpha: isDark ? .3 : .12),
                      AppColors.transparent,
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 16),
                  child: AppImage(
                    source: 'assets/images/onboarding/logo.svg',
                    fit: BoxFit.contain,
                    colorFilter: isDark
                        ? const ColorFilter.mode(
                            AppColors.white, BlendMode.srcIn)
                        : null,
                    placeholder: Text(
                      'AL BATAL ELITE',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 16, 12),
            child: Column(
              children: [
                const SizedBox(height: 4),
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    step.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsetsDirectional.only(end: 8),
                      width: index == currentPage ? 32 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == currentPage
                            ? scheme.primary
                            : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: FilledButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(isLastPage
                        ? context.l10n.onboardingGetStarted
                        : context.l10n.onboardingNext),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.secondary,
                      foregroundColor: scheme.onSecondary,
                      minimumSize: const Size.fromHeight(50),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                if (!isLastPage)
                  TextButton(
                    onPressed: onSkip,
                    child: Text(
                      context.l10n.onboardingSkip,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _OnboardingStep {
  const _OnboardingStep({
    required this.title,
    required this.body,
    required this.imagePath,
  });

  final String title;
  final String body;
  final String imagePath;
}
