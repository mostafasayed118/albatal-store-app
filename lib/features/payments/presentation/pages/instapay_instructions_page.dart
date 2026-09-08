import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/components/step_indicator.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/payment.dart';
import '../cubit/payment_cubit.dart';
import '../payment_error_mapper.dart';

/// InstaPay transfer instructions + proof submission (migration 041).
///
/// Receives the SAME [PaymentCubit] instance that [PaymentMethodPage]
/// owns (via the route extra) so the single server-authoritative
/// status watch — started when the cubit entered
/// [PaymentStatus.awaitingProof] — keeps running. This page never
/// creates or closes the cubit; it only renders its state and calls
/// [PaymentCubit.submitInstapayProof].
///
/// SECURITY NOTE: the transfer address and amount come from the
/// server ([InstapayInstructions]) — this page never computes or
/// accepts them from the client side. Success is decided ONLY by
/// admin review server-side; the local cubit observes it through the
/// same status stream used for Paymob.
class InstapayInstructionsPage extends StatefulWidget {
  const InstapayInstructionsPage({super.key, required this.cubit});

  /// The cubit owned by [PaymentMethodPage] (production) or injected
  /// by tests. Null (e.g. bad deep link) renders an error body.
  final PaymentCubit? cubit;

  @override
  State<InstapayInstructionsPage> createState() =>
      _InstapayInstructionsPageState();
}

class _InstapayInstructionsPageState extends State<InstapayInstructionsPage> {
  final _referenceController = TextEditingController();
  final _picker = ImagePicker();
  bool _submitting = false;
  bool _poppedForTerminal = false;
  String? _attachedFileName;
  List<int>? _attachedBytes;
  String? _attachedExt;
  bool _submitted = false;

  static const _maxProofBytes = 5 * 1024 * 1024; // mirrors the server guard

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final l = context.l10n;
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      if (bytes.isEmpty) return;
      if (bytes.length > _maxProofBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.instapayFileTooLarge)),
        );
        return;
      }
      final ext = xfile.name.contains('.')
          ? xfile.name.split('.').last.toLowerCase()
          : 'jpg';
      if (!mounted) return;
      setState(() {
        _attachedBytes = bytes;
        _attachedExt = ext;
        _attachedFileName = xfile.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.instapayPickScreenshotError)),
      );
    }
  }

  Future<void> _submitProof() async {
    final bytes = _attachedBytes;
    final ext = _attachedExt;
    if (bytes == null || ext == null || _submitting) return;
    setState(() => _submitting = true);
    final ok = await widget.cubit!.submitInstapayProof(
      proofBytes: bytes,
      fileExt: ext,
      reference: _referenceController.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      setState(() => _submitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.instapayProofSubmitted)),
      );
    }
    // Failure paths emit PaymentStatus.failed on the cubit; the
    // terminal-state listener below pops this page and
    // PaymentMethodPage surfaces the recoverable error.
  }

  void _copyAddress(String address) {
    final l = context.l10n;
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.instapayCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = widget.cubit;
    if (cubit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Payment session not found')),
      );
    }
    return BlocProvider<PaymentCubit>.value(
      value: cubit,
      child: BlocConsumer<PaymentCubit, PaymentState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.status != PaymentStatus.processing,
        listener: (context, state) {
          // Terminal or back-tracked state: leave this page. The
          // user-facing messaging (snackbar, navigation to
          // order-success) belongs to PaymentMethodPage, which stays
          // mounted beneath this route.
          final terminal = state.status == PaymentStatus.success ||
              state.status == PaymentStatus.failed ||
              state.status == PaymentStatus.cancelled ||
              state.status == PaymentStatus.expired ||
              state.status == PaymentStatus.timedOut ||
              state.status == PaymentStatus.selectingMethod;
          if (terminal && !_poppedForTerminal && context.canPop()) {
            _poppedForTerminal = true;
            context.pop();
          }
        },
        builder: (context, state) {
          final l = context.l10n;
          final scheme = Theme.of(context).colorScheme;
          final instructions = state.instructions;

          if (instructions == null) {
            return Scaffold(
              appBar: AppBar(title: Text(l.instapayInstructionsTitle)),
              body: Center(
                child: Text(
                  paymentMessageForCode(l, state.errorMessage,
                      state.errorMessage ?? l.paymentFailedRetry),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(title: Text(l.instapayInstructionsTitle)),
            body: ListView(
              padding: const EdgeInsetsDirectional.all(16),
              children: [
                // Continuity with checkout's stepper: payment is stage
                // 2 of Address → Payment → Review.
                StepIndicator(
                  steps: [l.shippingAddress, l.payment, l.reviewOrder],
                  currentStep: 1,
                  scheme: scheme,
                ),
                const SizedBox(height: 24),
                Text(
                  l.instapayTransferTo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                // Transfer destination — server-provided address with
                // a one-tap copy affordance.
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: scheme.outline.withValues(alpha: .3),
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.account_balance, color: scheme.primary),
                    title: Text(l.instapayAddressLabel,
                        style: Theme.of(context).textTheme.labelSmall),
                    subtitle: Text(
                      instructions.instapayAddress,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    trailing: IconButton(
                      tooltip: l.instapayCopy,
                      icon: const Icon(Icons.copy),
                      onPressed: () =>
                          _copyAddress(instructions.instapayAddress),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Server-authoritative amount.
                Row(
                  children: [
                    Text(l.instapayAmountLabel,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const Spacer(),
                    Text(
                      instructions.amount.format(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold, color: scheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _referenceController,
                  decoration: InputDecoration(
                    labelText: l.instapayReferenceLabel,
                    hintText: l.instapayReferenceHint,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 24),
                // Screenshot attachment (D3: required).
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.controlRadius),
                  ),
                  icon: Icon(
                    _attachedBytes == null ? Icons.upload_file : Icons.check,
                    color: _attachedBytes == null ? null : scheme.primary,
                  ),
                  label: Text(
                    _attachedBytes == null
                        ? l.instapayAttachScreenshot
                        : l.instapayScreenshotAttached,
                  ),
                  onPressed: _submitted ? null : _pickScreenshot,
                ),
                if (_attachedFileName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _attachedFileName!,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                if (_submitted)
                  // Proof recorded — payment stays pending until the
                  // admin review (or 24h expiry). The status watcher
                  // is live: approval navigates to order success.
                  Card(
                    color: scheme.primaryContainer.withValues(alpha: .3),
                    shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.controlRadius),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, color: scheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.instapayProofPendingNote,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.secondary,
                      foregroundColor: scheme.onSecondary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.controlRadius),
                      textStyle: Theme.of(context).textTheme.labelLarge,
                    ),
                    onPressed: _attachedBytes != null && !_submitting
                        ? _submitProof
                        : null,
                    child: _submitting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: scheme.onSecondary),
                          )
                        : Text(l.instapaySubmitProof),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
