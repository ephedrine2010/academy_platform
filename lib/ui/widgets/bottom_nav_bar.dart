import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

/// One destination in the [BottomNavBar].
class NavDestination {
  const NavDestination(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const List<NavDestination> kUserNavDestinations = [
  NavDestination(TablerIcons.home, TablerIcons.home_filled, 'Home'),
  NavDestination(TablerIcons.book, TablerIcons.book_2, 'Courses'),
  NavDestination(TablerIcons.calendar, TablerIcons.calendar_filled, 'Schedule'),
  NavDestination(TablerIcons.user, TablerIcons.user_filled, 'Profile'),
];

/// White rounded bottom navigation — active item rendered in teal.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.index,
    required this.onChanged,
    this.destinations = kUserNavDestinations,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<NavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == index,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.selected, required this.onTap});

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.teal : const Color(0xFFB3BBB7);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? destination.activeIcon : destination.icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            destination.label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
