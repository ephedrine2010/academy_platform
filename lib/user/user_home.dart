import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/cubit/auth_cubit.dart';
import '../courses/cubit/courses_cubit.dart';
import '../ui/screens/user_shell.dart';
import 'cubit/home_cubit.dart';

/// Home experience for a plain trainee (no `admins` doc). Provides the
/// [HomeCubit] and hosts the trainee [UserShell] — Home / Courses / Schedule /
/// Profile — built against the Nahdi Academy design system
/// (see `assets/design/DESIGN_SYSTEM.md`). Responsive across phone, tablet and
/// Windows/desktop widths.
class UserHome extends StatelessWidget {
  const UserHome({super.key});

  // Region / role aren't in the auth token yet; placeholder until the trainee
  // profile lands in Firestore.
  static const String _region = 'Eastern Region';
  static const String _role = 'Pharmacist';

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthCubit c) => c.state.user);
    final name = _firstName(user?.name);
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => HomeCubit(name: name, region: _region, role: _role),
        ),
        // Live course list from Firestore, shared by Home / Courses / Schedule.
        BlocProvider(create: (_) => CoursesCubit()),
      ],
      child: UserShell(
        name: name,
        email: (user?.email.isNotEmpty ?? false) ? user!.email : 'sara.k@nahdi.sa',
        region: _region,
        role: _role,
        onSignOut: () => context.read<AuthCubit>().signOut(),
      ),
    );
  }

  /// Greeting uses just the first name; falls back to a friendly default when
  /// the token carries no display name.
  static String _firstName(String? name) {
    if (name == null || name.trim().isEmpty) return 'there';
    return name.trim().split(RegExp(r'\s+')).first;
  }
}
