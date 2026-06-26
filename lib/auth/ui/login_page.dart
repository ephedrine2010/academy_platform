import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../theme/app_theme.dart';
import '../cubit/auth_cubit.dart';

/// First screen. Email + password sign-in against Firebase Auth. The Microsoft
/// path is disabled for now (the company tenant isn't wired up yet).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthCubit>().signInWithEmail(_email.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.teal,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: BlocBuilder<AuthCubit, AuthState>(
                  builder: (context, state) {
                    return Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Brand(),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            enabled: !state.isBusy,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(TablerIcons.mail),
                            ),
                            validator: (v) =>
                                (v == null || !v.contains('@'))
                                    ? 'Enter a valid email'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            enabled: !state.isBusy,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(TablerIcons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? TablerIcons.eye
                                    : TablerIcons.eye_off),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter your password'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: state.isBusy ? null : _submit,
                              icon: state.isBusy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(TablerIcons.login_2),
                              label: Text(state.isBusy
                                  ? 'Signing in…'
                                  : 'Sign in'),
                            ),
                          ),
                          if (state.error != null) ...[
                            const SizedBox(height: 16),
                            _Notice(text: state.error!),
                          ],
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: state.isBusy
                                ? null
                                : () =>
                                    context.read<AuthCubit>().continueAsGuest(),
                            child: const Text('Continue without signing in'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.teal,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(TablerIcons.school, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 16),
        Text(
          'Academy Platform',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.teal,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in to continue',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(TablerIcons.alert_circle, color: AppColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: AppColors.red.withValues(alpha: 0.9), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
