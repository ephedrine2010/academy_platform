import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin/ui/admin_widgets.dart';
import '../../theme/app_theme.dart';
import '../cubit/materials_cubit.dart';
import '../models/training_material.dart';
import 'material_filtering.dart';
import 'material_upload_dialog.dart';

/// Admin Materials tab (admin01 / admin02): the shared material library. Lists
/// every uploaded material (searchable + filterable by year / type) and lets an
/// admin upload / edit / delete them. Sessions attach these by id — see the
/// session dialog's material picker.
class MaterialsPage extends StatelessWidget {
  const MaterialsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MaterialsCubit, MaterialsState>(
      builder: (context, state) => _MaterialsView(state: state),
    );
  }
}

class _MaterialsView extends StatefulWidget {
  const _MaterialsView({required this.state});

  final MaterialsState state;

  @override
  State<_MaterialsView> createState() => _MaterialsViewState();
}

class _MaterialsViewState extends State<_MaterialsView> {
  MaterialQuery _query = const MaterialQuery();

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final all = state.materials;
    final filtered = filterMaterials(all, _query);
    final showFilters = !state.loading && state.error == null && all.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminToolbar(
          icon: TablerIcons.folder,
          title: 'Materials',
          subtitle:
              state.loading ? 'Loading…' : '${all.length} material(s)',
          actionLabel: 'Upload material',
          onAction: () => showMaterialUploadDialog(
            context,
            cubit: context.read<MaterialsCubit>(),
          ),
        ),
        if (showFilters)
          MaterialFilterBar(
            query: _query,
            years: distinctYears(all),
            onChanged: (q) => setState(() => _query = q),
          ),
        Expanded(child: _Body(state: state, filtered: filtered)),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.filtered});

  final MaterialsState state;
  final List<TrainingMaterial> filtered;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return AdminMessage(
        icon: TablerIcons.alert_triangle,
        text: 'Could not load materials:\n${state.error}',
      );
    }
    if (state.materials.isEmpty) {
      return const AdminMessage(
        icon: TablerIcons.folder_off,
        text: 'No materials yet.\nUpload a .zip to add one to the library.',
      );
    }
    if (filtered.isEmpty) {
      return const AdminMessage(
        icon: TablerIcons.search_off,
        text: 'No materials match the current filters.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _MaterialCard(material: filtered[i]),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material});

  final TrainingMaterial material;

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<MaterialsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDelete(
      context,
      message: 'Delete material “${material.title}”?\n'
          'This removes the uploaded file. Sessions using it will block deletion.',
    );
    if (!ok) return;
    try {
      await cubit.deleteMaterial(material);
    } catch (e) {
      final msg = e is StateError ? e.message : '$e';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = [
      material.type.label,
      if (material.year != null) '${material.year}',
      if (material.sizeLabel.isNotEmpty) material.sizeLabel,
      if (material.durationMinutes != null) '${material.durationMinutes} min',
      if (material.hasExam)
        'Exam${material.passThreshold != null ? ' ≥${material.passThreshold}%' : ''}',
      'ID ${material.materialId ?? material.id}',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.teal.withValues(alpha: 0.12),
            child: const Icon(TablerIcons.file_zip, color: AppColors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.title,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: GoogleFonts.manrope(fontSize: 10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          _StatusPill(material: material),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(TablerIcons.pencil, size: 18),
            tooltip: 'Edit details',
            color: AppColors.muted,
            onPressed: () => showMaterialEditDialog(
              context,
              cubit: context.read<MaterialsCubit>(),
              material: material,
            ),
          ),
          IconButton(
            icon: const Icon(TablerIcons.trash, size: 18),
            tooltip: 'Delete',
            color: AppColors.red,
            onPressed: () => _delete(context),
          ),
        ],
      ),
    );
  }
}

/// Small pill reflecting the unzip pipeline state: Pending / Processing /
/// Ready / Failed.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.material});

  final TrainingMaterial material;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (material.status) {
      'ready' => (const Color(0xFFE6F4EA), const Color(0xFF1E7B34)),
      'processing' => (const Color(0xFFFFF4E5), const Color(0xFFB5651D)),
      'failed' => (const Color(0xFFFCE8E6), AppColors.red),
      _ => (const Color(0xFFEDEEF0), AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        material.statusLabel,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
