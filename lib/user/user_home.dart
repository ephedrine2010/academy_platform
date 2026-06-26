import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../auth/cubit/auth_cubit.dart';
import '../theme/app_theme.dart';

/// Home screen for a plain trainee (no `admins` doc). Placeholder for now —
/// the trainee's courses / sessions / attendance UI goes here next.
class UserHome extends StatelessWidget {
  const UserHome({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.state.user);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.tealDark,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/brand/logo/logo-white.png', height: 32),
            const SizedBox(width: 12),
            const Text('Academy'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(TablerIcons.logout),
            onPressed: () => context.read<AuthCubit>().signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(TablerIcons.school, size: 48, color: AppColors.tealDark),
            const SizedBox(height: 16),
            Text(
              'Welcome${user?.name != null ? ', ${user!.name}' : ''}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Your courses will appear here.'),
          ],
        ),
      ),
    );
  }
}
