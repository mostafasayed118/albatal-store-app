import 'package:flutter/material.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/theme/app_theme.dart';

/// Reference field + screenshot attachment + proof submission.
///
/// All decisions stay with the owning page: screenshot picking
/// ([onPickScreenshot]), proof upload ([onSubmitProof]) and the
/// server-mirroring bounds ([maxReferenceLength]) are injected, so this
/// widget only renders the [submitted]/[submitting]/[hasAttachment] states.
class InstapayProofForm extends StatelessWidget {
  const InstapayProofForm({
    super.key,
    required this.referenceController,
    required this.maxReferenceLength,
    required this.hasAttachment,
    this.attachedFileName,
    required this.submitted,
    required this.submitting,
    required this.onPickScreenshot,
    required this.onSubmitProof,
  });

  final TextEditingController referenceController;
  final int maxReferenceLength;
  final bool hasAttachment;
  final String? attachedFileName;
  final bool submitted;
  final bool submitting;
  final VoidCallback onPickScreenshot;
  final VoidCallback onSubmitProof;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: referenceController,
          decoration: InputDecoration(
            labelText: l.instapayReferenceLabel,
            hintText: l.instapayReferenceHint,
            border: const OutlineInputBorder(),
          ),
          maxLength: maxReferenceLength,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 24),
        // Screenshot attachment (D3: required).
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: const RoundedRectangleBorder(
                borderRadius: AppTheme.controlRadius),
          ),
          icon: Icon(
            hasAttachment ? Icons.check : Icons.upload_file,
            color: hasAttachment ? scheme.primary : null,
          ),
          label: Text(
            hasAttachment
                ? l.instapayScreenshotAttached
                : l.instapayAttachScreenshot,
          ),
          onPressed: submitted ? null : onPickScreenshot,
        ),
        if (attachedFileName != null) ...[
          const SizedBox(height: 4),
          Text(
            attachedFileName!,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        if (submitted)
          // Proof recorded — payment stays pending until the
          // admin review (or 24h expiry). The status watcher
          // is live: approval navigates to order success.
          Card(
            color: scheme.primaryContainer.withValues(alpha: .3),
            shape: const RoundedRectangleBorder(
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
              shape: const RoundedRectangleBorder(
                  borderRadius: AppTheme.controlRadius),
              textStyle: Theme.of(context).textTheme.labelLarge,
            ),
            onPressed: hasAttachment && !submitting ? onSubmitProof : null,
            child: submitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: scheme.onSecondary),
                  )
                : Text(l.instapaySubmitProof),
          ),
      ],
    );
  }
}
