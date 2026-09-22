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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final steps = _steps(context);
              final imageHeight =
                  (constraints.maxHeight * .55).clamp(240.0, 520.0).toDouble();
              return PageView.builder(
                controller: _pageController,
                itemCount: steps.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
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
      ),
    );
  }
}
