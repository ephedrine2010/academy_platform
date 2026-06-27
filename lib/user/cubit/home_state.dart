part of 'home_cubit.dart';

class HomeState extends Equatable {
  const HomeState({
    required this.name,
    required this.region,
    required this.role,
  });

  final String name;
  final String region;
  final String role;

  String get subtitle => '$region · $role';

  HomeState copyWith({
    String? name,
    String? region,
    String? role,
  }) {
    return HomeState(
      name: name ?? this.name,
      region: region ?? this.region,
      role: role ?? this.role,
    );
  }

  @override
  List<Object?> get props => [name, region, role];
}
