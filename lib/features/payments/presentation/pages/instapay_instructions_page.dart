import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/entities/money.dart';
import '../../../../shared/components/step_indicator.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/image_compressor.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/payment_service.dart';
import '../cubit/payment_cubit.dart';
import '../widgets/instapay_error_body.dart';
import '../widgets/instapay_proof_form.dart';
import '../widgets/instapay_proof_picker.dart';
import '../widgets/instapay_transfer_card.dart';

/// InstaPay transfer instructions + proof submission (migration 041).
///
/// Primary path: receives the SAME [PaymentCubit] instance that
/// [PaymentMethodPage] owns (via the route extra) so the single
/// server-authoritative status watch — started when the cubit entered
/// [PaymentStatus.awaitingProof] — keeps running. This page never
/// creates or closes that cubit; it only renders its state and calls
/// [PaymentCubit.submitInstapayProof].
///
/// Rehydration path: when [cubit] is absent (e.g. a restored deep link)
/// but [orderId] is present, the page builds an owned cubit scoped to
/// the order and resumes the server status watch so terminal outcomes
/// still pop this page. The owned cubit cannot recover the
/// server-derived [InstapayInstructions] — re-running initiation would
/// risk a duplicate payment — so the body shows the recoverable error
/// until the watch resolves. Full instruction recovery needs a server
/// `get_instapay_instructions` endpoint (proposal, not implemented).
///
/// SECURITY NOTE: the transfer address and amount come from the
/// server ([InstapayInstructions]) — this page never computes or
/// accepts them from the client side. Success is decided ONLY by
/// admin review server-side; the local cubit observes it through the
/// same status stream used for Paymob.
class InstapayInstructionsPage extends StatefulWidget {
  const InstapayInstructionsPage(
      {super.key,
      this.cubit,
      this.orderId,
      this.paymentService,
      this.imageCompressor});

  /// The cubit owned by [PaymentMethodPage] (production) or injected
  /// by tests. Null (e.g. bad deep link) renders an error body unless
  /// [orderId] allows the rehydration path below.
  final PaymentCubit? cubit;

  /// Canonical order id, carried additively in the route extra (and
  /// accepted by the route alongside `cubit`). Enables the rehydration
  /// path when the shared cubit is unavailable.
  final String? orderId;

  /// [PaymentService] for the rehydrated cubit, resolved at the
  /// composition root (audit 2026-09-13); tests inject a stub. Null
  /// (deep link without a session) renders the error body. Ignored
  /// when [cubit] is provided.
  final PaymentService? paymentService;

  /// §4 proof-screenshot compression, resolved at the composition root.
  /// Null (pre-DI widget tests) falls back to the raw picker bytes — the
  /// server-side guard still bounds the upload size.
  final ImageCompressor? imageCompressor;

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

  /// Owned cubit for the [widget.orderId] rehydration path. Null on the
  /// primary path, where the shared cubit is borrowed, not owned.
  PaymentCubit? _ownedCubit;

  /// The cubit rendering this page: the shared instance when present,
  /// otherwise the rehydrated owned one (possibly null → error body).
  PaymentCubit? get _effectiveCubit => widget.cubit ?? _ownedCubit;

  @override
  void initState() {
    super.initState();
    final orderId = widget.orderId?.trim() ?? '';
    if (widget.cubit == null && orderId.isNotEmpty) {
      final service = widget.paymentService;
      if (service != null) {
        _ownedCubit = PaymentCubit(service)
          ..initPayment(amount: Money.zero, orderId: orderId);
        unawaited(_ownedCubit!.startWatching(orderId));
      }
    }
  }

  static const _maxProofBytes = 5 * 1024 * 1024; // mirrors the server guard

  /// Extensions the server allowlist accepts. Client-side pre-check only —
  /// the edge function re-validates (magic-byte check stays server-side).
  static const _allowedProofExtensions = {'png', 'jpg', 'jpeg', 'webp'};

  /// Reference-field bound (mirrors the server column guard).
  static const _maxReferenceLength = 64;

  @override
  void dispose() {
    _referenceController.dispose();
    // Only the rehydration path owns its cubit; the shared instance
    // belongs to PaymentMethodPage and must outlive this route.
    final owned = _ownedCubit;
    _ownedCubit = null;
    if (owned != null) unawaited(owned.close());
    super.dispose();
  }

  /// One mounted-guard + snackbar (audit 2026-09-21 LOW: the guard block
  /// was hand-repeated at every message site).
  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickScreenshot() async {
    final l = context.l10n;
    final picked = await pickInstapayProofScreenshot(
      picker: _picker,
      compressor: widget.imageCompressor,
      maxBytes: _maxProofBytes,
      allowedExtensions: _allowedProofExtensions,
      emptyError: l.instapayPickScreenshotError,
      tooLargeError: l.instapayFileTooLarge,
      typeNotAllowedError: l.instapayFileTypeNotAllowed,
      onError: _snack,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _attachedBytes = picked.bytes;
      _attachedExt = picked.ext;
      _attachedFileName = picked.fileName;
    });
  }

  Future<void> _submitProof() async {
    final cubit = _effectiveCubit;
    final bytes = _attachedBytes;
    final ext = _attachedExt;
    if (cubit == null || bytes == null || ext == null || _submitting) return;
    final reference = _referenceController.text.trim();
    if (reference.length > _maxReferenceLength) {
      _snack(context.l10n.instapayReferenceTooLong);
      return;
    }
    setState(() => _submitting = true);
    final ok = await cubit.submitInstapayProof(
      proofBytes: bytes,
      fileExt: ext,
      reference: reference,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      setState(() => _submitted = true);
      _snack(context.l10n.instapayProofSubmitted);
    }
    // Failure paths emit PaymentStatus.failed on the cubit; the
    // terminal-state listener below pops this page and
    // PaymentMethodPage surfaces the recoverable error.
  }

  void _copyAddress(String address) {
    final l = context.l10n;
    Clipboard.setData(ClipboardData(text: address));
    _snack(l.instapayCopied);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _effectiveCubit;
    if (cubit == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.instapaySessionMissing)),
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
              body: InstapayErrorBody(errorMessage: state.errorMessage),
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
                InstapayTransferCard(
                  address: instructions.instapayAddress,
                  amountText: instructions.amount.format(),
                  onCopy: () => _copyAddress(instructions.instapayAddress),
                ),
                const SizedBox(height: 24),
                InstapayProofForm(
                  referenceController: _referenceController,
                  maxReferenceLength: _maxReferenceLength,
                  hasAttachment: _attachedBytes != null,
                  attachedFileName: _attachedFileName,
                  submitted: _submitted,
                  submitting: _submitting,
                  onPickScreenshot: _pickScreenshot,
                  onSubmitProof: _submitProof,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
