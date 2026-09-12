import 'package:flutter/material.dart';

import '../../../../core/error/result.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/repositories/admin_repository.dart';

/// Admin review moderation (feature-batch §9): approve/reject pending
/// rows. Reads go through the admin RLS policies in 050.
class AdminReviewsPage extends StatefulWidget {
  const AdminReviewsPage({super.key, this.repository});

  final AdminRepository? repository;

  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

final class _AdminReviewsPageState extends State<AdminReviewsPage> {
  List<({String id, String product, String text, int rating})> _pending =
      const [];
  bool _loading = true;
  String? _error;

  AdminRepository get _repo =>
      widget.repository ?? getIt<AdminRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repo.fetchPendingReviews();
    switch (result) {
      case Success(:final value):
        setState(() {
          _pending = value;
          _loading = false;
        });
      case Failure(:final error):
        setState(() {
          _error = error.message;
          _loading = false;
        });
    }
  }

  Future<void> _moderate(String id, bool approve) async {
    final result = await _repo.setReviewStatus(
        id, approve ? 'approved' : 'rejected');
    if (result is Success<void>) {
      setState(() {
        _pending =
            _pending.where((r) => r.id != id).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.reviewModeration)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _pending.isEmpty
                      ? ListView(children: [
                          Padding(
                            padding: const EdgeInsetsDirectional.all(32),
                            child: Center(child: Text(l.noReviewsYet)),
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsetsDirectional.all(16),
                          itemCount: _pending.length,
                          separatorBuilder: (context, i) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final r = _pending[i];
                            return Card(
                              color: Theme.of(context).colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppTheme.cardRadius,
                                side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                    width: 1),
                              ),
                              child: ListTile(
                                title: Text(r.text),
                                subtitle: Text(
                                    '${r.product} · ${'★' * r.rating}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: l.reviewApprove,
                                      onPressed: () => _moderate(r.id, true),
                                      icon: const Icon(Icons.check),
                                    ),
                                    IconButton(
                                      tooltip: l.reviewReject,
                                      onPressed: () => _moderate(r.id, false),
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
