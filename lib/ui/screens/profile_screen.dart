import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../models/learning.dart';
import '../responsive.dart';
import '../widgets/badges.dart';
import '../widgets/brand.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/teal_header.dart';

/// Trainee profile — avatar, region/role, learning stats and certificates.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
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

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = formFactorFor(constraints.maxWidth).contentMaxWidth;
        return Column(
          children: [
            TealHeader(
              maxContentWidth: maxW,
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 26),
              child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.tealDark,
                  child: Text(
                    _initials,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$region · $role',
                        style: GoogleFonts.manrope(fontSize: 11.5, color: AppColors.tealCaption),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        email,
                        style: GoogleFonts.manrope(fontSize: 11.5, color: AppColors.tealCaption),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
            Expanded(
              child: ContentColumn(
                maxWidth: maxW,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  children: [
                    Row(
                      children: const [
                        Expanded(child: _StatCard(value: '6', label: 'Enrolled', icon: TablerIcons.book)),
                        SizedBox(width: 12),
                        Expanded(child: _StatCard(value: '3', label: 'Completed', icon: TablerIcons.discount_check)),
                        SizedBox(width: 12),
                        Expanded(child: _StatCard(value: '3', label: 'Certificates', icon: TablerIcons.certificate)),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const SectionHeader('Certificates'),
                    const SizedBox(height: 8),
                    for (final cert in DemoData.certificates) ...[
                      _CertificateRow(title: cert),
                      const SizedBox(height: 11),
                    ],
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: 'Sign out',
                      icon: TablerIcons.logout,
                      expand: true,
                      onPressed: onSignOut,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.teal),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(fontSize: 10.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _CertificateRow extends StatelessWidget {
  const _CertificateRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const IconTile(
            icon: TablerIcons.certificate,
            fg: AppColors.lime,
            bg: AppColors.teal,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Issued · Nahdi Academy',
                  style: GoogleFonts.manrope(fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const StatusBadge(label: 'Certificate', colors: StatusColors.certificate),
        ],
      ),
    );
  }
}
