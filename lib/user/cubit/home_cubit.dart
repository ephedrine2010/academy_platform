import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../ui/models/learning.dart';

part 'home_state.dart';

/// Drives the trainee Home screen. The platform has no trainee/course backend
/// yet, so this loads the design-system demo content; when the repository layer
/// lands it should subscribe to a stream here instead. Greeting identity is
/// passed in from the signed-in [AuthUser].
class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required String name,
    String region = 'Eastern Region',
    String role = 'Pharmacist',
  }) : super(HomeState(name: name, region: region, role: role)) {
    load();
  }

  /// Populate the screen with the trainee's continue-learning item and course
  /// list. Synchronous for now (demo data); kept async-shaped for the future
  /// repository call.
  void load() {
    emit(state.copyWith(
      status: HomeStatus.ready,
      featured: DemoData.continueLearning,
      myCourses: DemoData.myCourses,
    ));
  }
}
