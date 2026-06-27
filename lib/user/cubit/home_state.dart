part of 'home_cubit.dart';

enum HomeStatus { loading, ready }

class HomeState extends Equatable {
  const HomeState({
    required this.name,
    required this.region,
    required this.role,
    this.status = HomeStatus.loading,
    this.featured,
    this.myCourses = const [],
  });

  final HomeStatus status;
  final String name;
  final String region;
  final String role;

  /// The "continue learning" item, or null until [HomeCubit.load] runs.
  final Course? featured;
  final List<Course> myCourses;

  String get subtitle => '$region · $role';

  HomeState copyWith({
    HomeStatus? status,
    String? name,
    String? region,
    String? role,
    Course? featured,
    List<Course>? myCourses,
  }) {
    return HomeState(
      status: status ?? this.status,
      name: name ?? this.name,
      region: region ?? this.region,
      role: role ?? this.role,
      featured: featured ?? this.featured,
      myCourses: myCourses ?? this.myCourses,
    );
  }

  @override
  List<Object?> get props => [status, name, region, role, featured, myCourses];
}
