import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'home_state.dart';

/// Drives the trainee Home screen header (greeting identity + subtitle). The
/// course list itself now comes from `CoursesCubit` (Firestore `courses`); this
/// cubit only carries the signed-in trainee's name / region / role.
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required String name,
    String region = 'Eastern Region',
    String role = 'Pharmacist',
  }) : super(HomeState(name: name, region: region, role: role));
}
