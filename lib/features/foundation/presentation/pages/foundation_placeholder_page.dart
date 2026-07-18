import 'package:flutter/material.dart';

import '../../../../shared/components/feedback_view.dart';
import '../../../../shared/extensions/build_context_x.dart';

final class FoundationPlaceholderPage extends StatelessWidget {
  const FoundationPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.notAvailableTitle)),
    body: const FeedbackView(type: FeedbackViewType.empty),
  );
}
