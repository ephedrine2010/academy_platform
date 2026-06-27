import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth/cubit/auth_cubit.dart';
import 'auth/ui/auth_gate.dart';
import 'firebase_options.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';
import 'user/user_home.dart';

/// Dev preview switch: when true, skip the login screen and open the main
/// shell directly (as admin, so every tab shows) to eyeball the layout.
/// Set back to false to restore the normal login → role-gated flow.
const bool kSkipAuthForPreview = false;

/// Dev preview switch for the trainee experience: when true, skip login and
/// open the trainee [UserHome] directly. Takes precedence over
/// [kSkipAuthForPreview]. Set back to false to restore the normal flow.
const bool kPreviewUserHome = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AcademyApp());
}

class AcademyApp extends StatelessWidget {
  const AcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academy Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // AuthCubit lives above the gate so the home page can also read the
      // signed-in user (to show login details and sign out).
      home: BlocProvider(
        create: (_) => AuthCubit(),
        child: kPreviewUserHome
            ? const UserHome()
            : kSkipAuthForPreview
                ? const AppShell(role: AppRole.manager)
                : const AuthGate(),
      ),
    );
  }
}
