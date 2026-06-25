import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth_config.dart';
import '../cubit/auth_cubit.dart';

/// First screen. Offers "Sign in with Microsoft"; on success the [AuthGate]
/// swaps to the home page.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.school,
                        size: 56,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Academy Platform',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in with your company Microsoft account.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      const SizedBox(height: 28),
                      _SignInButton(busy: state.isBusy),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: state.isBusy
                            ? null
                            : () =>
                                context.read<AuthCubit>().continueAsGuest(),
                        child: const Text('Continue without signing in'),
                      ),
                      if (!AuthConfig.isConfigured) ...[
                        const SizedBox(height: 16),
                        _Notice(
                          color: Colors.orange,
                          icon: Icons.settings_outlined,
                          text: 'Not configured yet — add the company Client ID '
                              'and Tenant ID in lib/auth/auth_config.dart.',
                        ),
                      ],
                      if (state.error != null) ...[
                        const SizedBox(height: 16),
                        _Notice(
                          color: Colors.red,
                          icon: Icons.error_outline,
                          text: state.error!,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: busy ? null : () => context.read<AuthCubit>().signIn(),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.login),
        label: Text(busy ? 'Waiting for browser…' : 'Sign in with Microsoft'),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.color,
    required this.icon,
    required this.text,
  });

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
