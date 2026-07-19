import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../cubit/payment_cubit.dart';

/// Vodafone Cash payment page — enter phone number and confirm.
class VodafoneCashPage extends StatefulWidget {
  const VodafoneCashPage({super.key});

  @override
  State<VodafoneCashPage> createState() => _VodafoneCashPageState();
}

class _VodafoneCashPageState extends State<VodafoneCashPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.vodafoneCash)),
      body: BlocListener<PaymentCubit, PaymentState>(
        listener: (context, state) {
          if (state.status == PaymentStatus.success) {
            context.go('/order-success');
          } else if (state.status == PaymentStatus.failed &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!)));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.phone_android,
                    size: 64, color: scheme.primary),
                const SizedBox(height: 24),
                Text(l.vodafoneCashDescription,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: InputDecoration(
                    labelText: l.phoneNumber,
                    prefixText: '+20 ',
                    prefixIcon: const Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l.phoneNumberRequired;
                    }
                    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 10) {
                      return l.invalidPhoneNumber;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                BlocBuilder<PaymentCubit, PaymentState>(
                  builder: (context, state) {
                    return FilledButton(
                      onPressed: state.status == PaymentStatus.processing
                          ? null
                          : _submit,
                      child: state.status == PaymentStatus.processing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : Text(l.payWithVodafoneCash),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(l.vodafoneCashNote,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<PaymentCubit>().processVodafoneCash(
            phoneNumber: _phoneCtrl.text.trim(),
          );
    }
  }
}
