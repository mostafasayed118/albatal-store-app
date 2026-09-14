import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/email_validator.dart';
import '../../../../shared/components/feedback.dart';
import '../../../../shared/extensions/build_context_x.dart';
import '../../../../shared/utils/error_l10n.dart';
import '../cubit/auth_cubit.dart';

/// Minimum accepted password length for new accounts (audit S9).
const int minPasswordLength = 8;

/// Password rule for the sign-in / reset forms: at least
/// [minPasswordLength] characters.
///
/// Top-level (not a closure) so the rule is unit-testable without a
/// widget tree. [tooShortMessage] carries the localized copy from the
/// page; the fallback exists only so the validator is testable
/// standalone. Returns null when the value is acceptable.
///
/// Length-only on purpose: sign-in and password-reset must not reject
/// credentials created before the complexity rule existed (audit
/// 2026-09-14). New accounts go through [signUpPasswordValidator].
String? passwordValidator(String? value, {String? tooShortMessage}) =>
    (value == null || value.length < minPasswordLength)
        ? tooShortMessage ??
            'Password must be at least $minPasswordLength characters'
        : null;

/// Password rule for NEW accounts: [passwordValidator] plus at least one
/// letter and one digit (audit 2026-09-14). Length-only passwords like
/// `12345678` or `longenough` are no longer accepted at sign-up.
///
/// Kept separate from [passwordValidator] so legacy credentials still
/// sign in. Returns null when the value is acceptable.
String? signUpPasswordValidator(
  String? value, {
  String? tooShortMessage,
  String? tooWeakMessage,
}) {
  final tooShort =
      passwordValidator(value, tooShortMessage: tooShortMessage);
  if (tooShort != null) return tooShort;
  final password = value!;
  final hasLetter = password.contains(RegExp(r'[A-Za-z]'));
  final hasDigit = password.contains(RegExp(r'\d'));
  if (!hasLetter || !hasDigit) {
    return tooWeakMessage ??
        'Password must contain at least one letter and one digit';
  }
  return null;
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.signUp)),
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.isAuthenticated) {
            hapticSuccess();
            context.go('/home');
          } else if (state.status == AuthStatus.failure &&
              state.errorMessage != null) {
            // Code-based localization (audit 2026-09-14): failures with a
            // machine code map to localized copy; unknown/missing codes
            // keep the English fallback message verbatim.
            showFloatingError(
              context,
              localizedErrorMessage(
                      context, state.errorMessage!, code: state.errorCode) ??
                state.errorMessage!,
            );
          } else if (state.status == AuthStatus.unauthenticated) {
            // Email confirmation required
            showConfirmation(context, l.checkEmailToVerify);
            context.go('/sign-in');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              children: [
                const SizedBox(height: 32),
                Text(l.createAccount,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: l.fullName),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? l.nameRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(labelText: l.email),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      emailValidator(v, invalidMessage: l.invalidEmail),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(
                    labelText: l.password,
                    // State the full rule up front so the user never has
                    // to learn it from a validation error.
                    helperText: l.passwordRuleHint,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  validator: (v) => signUpPasswordValidator(
                    v,
                    tooShortMessage: l.passwordTooShort,
                    tooWeakMessage: l.passwordNeedsLetterDigit,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  decoration: InputDecoration(labelText: l.confirmPassword),
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      v != _passwordCtrl.text ? l.passwordsDoNotMatch : null,
                ),
                const SizedBox(height: 32),
                BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    return FilledButton(
                      onPressed: state.isLoading ? null : _submit,
                      child: state.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l.signUp),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l.alreadyHaveAccount),
                    TextButton(
                      onPressed: () => context.push('/sign-in'),
                      child: Text(l.signIn),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthCubit>().signUp(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            fullName: _nameCtrl.text.trim(),
          );
    }
  }
}
