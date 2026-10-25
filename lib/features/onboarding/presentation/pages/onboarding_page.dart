import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/routing/app_routes.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';
import '../widgets/onboarding_step.dart';
import '../widgets/onboarding_step_view.dart';

final class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

final class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;
  int _currentPage = 0;

  List<OnboardingStep> _steps(BuildContext context) => [
        OnboardingStep(
          title: context.l10n.onboardingExquisiteTitle,
          body: context.l10n.onboardingExquisiteBody,
          imagePath: 'assets/images/onboarding/fabric-silk.svg',
        ),
        OnboardingStep(
          title: context.l10n.onboardingCraftsmanshipTitle,
          body: context.l10n.onboardingCraftsmanshipBody,
          imagePath: 'assets/images/onboarding/fabric-woven.svg',
        ),
        OnboardingStep(
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

  void _next(List<OnboardingStep> steps) {
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
      listener: (_, __) => context.go(Routes.home),
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<OnboardingCubit, OnboardingState>(
            buildWhen: (previous, current) => previous.status != current.status,
            builder: (context, state) => Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final steps = _steps(context);
                      final imageHeight = (constraints.maxHeight * .55)
                          .clamp(240.0, 520.0)
                          .toDouble();
                      return PageView.builder(
                        controller: _pageController,
                        itemCount: steps.length,
                        onPageChanged: (page) =>
                            setState(() => _currentPage = page),
                        itemBuilder: (_, index) => OnboardingStepView(
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
                // A failed completion used to be silent: the page only
                // reacted to `destination == home`, so the user stayed on
                // the last slide with no feedback. Surface it with the
                // existing localized copy and a retry.
                if (state.status == OnboardingStatus.failure)
                  _CompletionFailureBanner(
                    message: context.l10n.errorTitle,
                    retryLabel: context.l10n.retry,
                    onRetry: _complete,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact inline banner shown when persisting onboarding completion fails.
final class _CompletionFailureBanner extends StatelessWidget {
  const _CompletionFailureBanner({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
