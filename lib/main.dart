import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth/cubit/auth_cubit.dart';
import 'auth/ui/auth_gate.dart';

void main() {
  runApp(const AcademyApp());
}

class AcademyApp extends StatelessWidget {
  const AcademyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academy Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      // AuthCubit lives above the gate so the home page can also read the
      // signed-in user (to show login details and sign out).
      home: BlocProvider(
        create: (_) => AuthCubit(),
        child: const AuthGate(),
      ),
    );
  }
}
