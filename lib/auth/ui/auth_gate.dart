import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/cubit/courses_cubit.dart';
import '../../academy/ui/home_page.dart';
import '../cubit/auth_cubit.dart';
import 'login_page.dart';

/// Shows the [LoginPage] until the user is signed in, then the [HomePage].
///
/// The [CoursesCubit] is created only once we reach the home page so the course
/// folder is scanned after a successful sign-in, not before.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (a, b) => a.isSignedIn != b.isSignedIn,
      builder: (context, state) {
        if (state.isSignedIn) {
          return BlocProvider(
            create: (_) => CoursesCubit()..loadCourses(),
            child: const HomePage(),
          );
        }
        return const LoginPage();
      },
    );
  }
}
