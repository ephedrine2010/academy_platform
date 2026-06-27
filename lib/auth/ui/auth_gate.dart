import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shell/app_shell.dart';
import '../../user/user_home.dart';
import '../cubit/auth_cubit.dart';
import 'login_page.dart';

/// Shows the [LoginPage] until the user is signed in, then routes by role:
/// managers/trainers get the admin [AppShell]; plain trainees get [UserHome].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (a, b) => a.isSignedIn != b.isSignedIn || a.role != b.role,
      builder: (context, state) {
        if (!state.isSignedIn) return const LoginPage();
        if (state.isTrainee) return const UserHome();
        return AppShell(role: state.role);
      },
    );
  }
}
