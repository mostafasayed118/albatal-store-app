import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/app_image.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/app_theme.dart';
import '../cubit/onboarding_cubit.dart';
import '../cubit/onboarding_state.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _logoOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .72, curve: Curves.easeOut),
    );
    _logoOffset = Tween<Offset>(
      begin: const Offset(0, .08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, .72, curve: Curves.easeOutCubic),
    ));
    _controller.forward();
    context.read<OnboardingCubit>().resolveDestination();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openDestination(OnboardingDestination destination) {
    if (!mounted) return;
    context.go(
        destination == OnboardingDestination.home ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BlocListener<OnboardingCubit, OnboardingState>(
      listenWhen: (previous, current) =>
          previous.destination != current.destination &&
          current.destination != null,
      listener: (_, state) {
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (mounted && state.destination != null) {
            _openDestination(state.destination!);
          }
        });
      },
      child: BlocBuilder<OnboardingCubit, OnboardingState>(
        builder: (context, state) => Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryStitch,
                      colorScheme.primaryContainer,
                      const Color(0xFF002117),
                      AppTheme.primaryStitch,
                    ],
                    stops: const [0, .35, .7, 1],
                  ),
                ),
              ),
              Opacity(
                opacity: .16,
                child: AppImage(
                  source: 'assets/images/onboarding/fabric-texture.svg',
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      colorScheme.secondary, BlendMode.overlay),
                ),
              ),
              Center(
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: SlideTransition(
                    position: _logoOffset,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: AppImage(
                            source: 'assets/images/onboarding/logo.svg',
                            fit: BoxFit.contain,
                            colorFilter: const ColorFilter.mode(
                                Colors.white, BlendMode.srcIn),
                            placeholder: Icon(
                              Icons.auto_awesome,
                              size: 112,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.secondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.status == OnboardingStatus.failure)
                PositionedDirectional(
                  bottom: 40,
                  start: 32,
                  end: 32,
                  child: FilledButton(
                    onPressed:
                        context.read<OnboardingCubit>().resolveDestination,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      foregroundColor: colorScheme.onSecondary,
                    ),
                    child: Text(context.l10n.retry),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
