import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../academy/utils/log.dart';
import '../data/instructor_repository.dart';
import '../models/today_appointment.dart';

part 'instructor_home_state.dart';

/// Loads the instructor's appointments for **today** (one-shot — call
/// [refresh] to reload). Powers the "Today" tab carousel on the instructor Home.
class InstructorHomeCubit extends Cubit<InstructorHomeState> {
  InstructorHomeCubit({
    InstructorRepository? repository,
    String? instructorId,
  })  : _repo = repository ??
            InstructorRepository(instructorId: instructorId ?? ''),
        super(const InstructorHomeState()) {
    refresh();
  }

  final InstructorRepository _repo;

  Future<void> refresh() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final appointments = await _repo.loadTodayAppointments();
      emit(state.copyWith(loading: false, appointments: appointments));
    } catch (e, s) {
      logError('InstructorHomeCubit.refresh', e, s);
      emit(state.copyWith(loading: false, error: '$e'));
    }
  }
}
