import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../widgets/bottom_nav_bar.dart';
import 'courses_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'schedule_screen.dart';

/// Trainee app frame: an [IndexedStack] of the four primary screens behind a
/// teal-active [BottomNavBar]. State for each tab is preserved when switching.
class UserShell extends StatefulWidget {
  const UserShell({
    super.key,
    required this.name,
    this.email = 'sara.k@nahdi.sa',
    this.region = 'Eastern Region',
    this.role = 'Pharmacist',
    this.onSignOut,
  });

  final String name;
  final String email;
  final String region;
  final String role;
  final VoidCallback? onSignOut;

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
      const CoursesScreen(),
      const ScheduleScreen(),
      ProfileScreen(
        name: widget.name,
        email: widget.email,
        region: widget.region,
        role: widget.role,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}
