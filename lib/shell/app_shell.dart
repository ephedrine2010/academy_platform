import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../academy/cubit/courses_cubit.dart';
import '../academy/ui/home_page.dart';
import '../admin/cubit/contractors_cubit.dart';
import '../admin/cubit/regions_cubit.dart';
import '../admin/ui/admin_dashboard_page.dart';
import '../admin/ui/contractors_page.dart';
import '../admin/ui/regions_page.dart';
import '../auth/cubit/auth_cubit.dart';
import '../theme/app_theme.dart';

/// One entry in the left navigation.
class _Tab {
  const _Tab({required this.label, required this.icon, required this.builder});

  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

/// The main authenticated screen: a left sidebar (NavigationRail on wide
/// layouts, a Drawer on narrow ones) plus the selected tab's content. The tab
/// set depends on the signed-in role.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.isAdmin, this.accessToken});

  final bool isAdmin;

  /// OneDrive Graph access token, forwarded to the Courses tab so it can stream
  /// SCORM packages from the shared OneDrive folder when configured.
  final String? accessToken;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  List<_Tab> get _tabs => [
        if (widget.isAdmin) ...[
          _Tab(
            label: 'Dashboard',
            icon: TablerIcons.layout_dashboard,
            builder: (_) => const AdminDashboardPage(),
          ),
          _Tab(
            label: 'Regions',
            icon: TablerIcons.map_pin,
            builder: (_) => const RegionsPage(),
          ),
          _Tab(
            label: 'Contractors',
            icon: TablerIcons.users,
            builder: (_) => const ContractorsPage(),
          ),
        ],
        _Tab(
          label: 'Courses',
          icon: TablerIcons.book,
          builder: (_) => BlocProvider(
            create: (_) =>
                CoursesCubit(accessToken: widget.accessToken)..loadCourses(),
            child: const HomePage(),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final index = _index.clamp(0, tabs.length - 1);

    // Admin tabs share live region + contractor data, created once here.
    Widget shell = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final body = tabs[index].builder(context);
        return wide
            ? _WideLayout(tabs: tabs, index: index, body: body, onSelect: _select)
            : _NarrowLayout(
                tabs: tabs, index: index, body: body, onSelect: _select);
      },
    );

    if (widget.isAdmin) {
      shell = MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => RegionsCubit()),
          BlocProvider(create: (_) => ContractorsCubit()),
        ],
        child: shell,
      );
    }
    return shell;
  }

  void _select(int i) => setState(() => _index = i);
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.tabs,
    required this.index,
    required this.body,
    required this.onSelect,
  });

  final List<_Tab> tabs;
  final int index;
  final Widget body;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 220,
            selectedIndex: index,
            onDestinationSelected: onSelect,
            leading: const _RailHeader(),
            trailing: const Expanded(child: _RailFooter()),
            destinations: [
              for (final t in tabs)
                NavigationRailDestination(
                  icon: Icon(t.icon),
                  label: Text(t.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.tabs,
    required this.index,
    required this.body,
    required this.onSelect,
  });

  final List<_Tab> tabs;
  final int index;
  final Widget body;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tabs[index].label)),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const _RailHeader(),
              const Divider(height: 1),
              for (var i = 0; i < tabs.length; i++)
                ListTile(
                  leading: Icon(tabs[i].icon),
                  title: Text(tabs[i].label),
                  selected: i == index,
                  onTap: () {
                    onSelect(i);
                    Navigator.pop(context);
                  },
                ),
              const Spacer(),
              const Divider(height: 1),
              const _RailFooter(),
            ],
          ),
        ),
      ),
      body: body,
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(TablerIcons.school, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Academy',
              style: TextStyle(
                color: DefaultTextStyle.of(context).style.color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// User identity + sign-out, pinned to the bottom of the sidebar.
class _RailFooter extends StatelessWidget {
  const _RailFooter();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (a, b) => a.user != b.user || a.role != b.role,
      builder: (context, state) {
        final user = state.user;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.tealLight,
                    foregroundColor: Colors.white,
                    child: Text(_initials(user?.name ?? '?')),
                  ),
                  title: Text(
                    user?.name ?? 'User',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    state.isAdmin ? 'Administrator' : 'Trainee',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<AuthCubit>().signOut(),
                    icon: const Icon(TablerIcons.logout, size: 18),
                    label: const Text('Sign out'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
