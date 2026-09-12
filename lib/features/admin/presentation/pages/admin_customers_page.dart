import 'package:flutter/material.dart';

import '../../../../core/error/result.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/services/service_locator.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../domain/entities/admin_customer.dart';
import '../../domain/repositories/admin_repository.dart';

/// Admin customers list (feature-batch §14): profile directory with
/// membership tier + contact columns. Read-only in this batch — tier
/// control lives on the order-detail surface it already belongs to.
class AdminCustomersPage extends StatefulWidget {
  const AdminCustomersPage({super.key, this.repository});

  final AdminRepository? repository;

  @override
  State<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

final class _AdminCustomersPageState extends State<AdminCustomersPage> {
  List<AdminCustomer> _customers = const [];
  List<AdminCustomer> _visible = const [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  AdminRepository get _repo => widget.repository ?? getIt<AdminRepository>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _repo.fetchCustomers();
    switch (result) {
      case Success(:final value):
        setState(() {
          _customers = value;
          _visible = value;
          _loading = false;
        });
      case Failure(:final error):
        setState(() {
          _error = error.message;
          _loading = false;
        });
    }
  }

  void _filter(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _visible = q.isEmpty
          ? _customers
          : _customers
              .where((c) =>
                  c.name.toLowerCase().contains(q) ||
                  c.email.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.adminCustomers)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.all(16),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filter,
                        decoration: InputDecoration(
                          hintText: l.adminSearch,
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _visible.isEmpty
                          ? Center(child: Text(l.adminSearch))
                          : ListView.separated(
                              padding: const EdgeInsetsDirectional.symmetric(
                                  horizontal: 16),
                              itemCount: _visible.length,
                              separatorBuilder: (context, i) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final c = _visible[i];
                                return Card(
                                  color: scheme.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppTheme.cardRadius,
                                    side: BorderSide(
                                        color: scheme.outlineVariant,
                                        width: 1),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          scheme.primaryContainer,
                                      child: Text(
                                        c.name.isEmpty
                                            ? '?'
                                            : c.name[0].toUpperCase(),
                                        style: TextStyle(
                                            color: scheme
                                                .onPrimaryContainer),
                                      ),
                                    ),
                                    title: Text(c.name.isEmpty
                                        ? c.email
                                        : c.name),
                                    subtitle: Text(c.email),
                                    trailing: Text(c.tier),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
