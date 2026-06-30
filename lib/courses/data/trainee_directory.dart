import 'dart:math';

/// A trainee's full profile as it will eventually be returned by the staff
/// directory API, keyed by the trainee's int id.
///
/// Today only the int id is stored on a session (`session.trainees`); the rest
/// of these fields are **mocked** by [TraineeDirectory]. When the real API lands
/// it should return this same shape so the UI ([EnrolledTraineesTable]) needs no
/// changes.
class TraineeProfile {
  const TraineeProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.department,
    required this.jobTitle,
    required this.status,
  });

  final int id;
  final String name;
  final String email;
  final String phone;
  final String department;
  final String jobTitle;

  /// Enrollment status — one of "Active", "Invited", "Completed".
  final String status;
}

/// Resolves trainee int ids into [TraineeProfile]s.
///
/// **This implementation is a placeholder.** It synthesises stable, realistic
/// looking data from the id (same id → same profile) so the enrolled-trainees
/// table has something to show. Swap [profilesFor] for a real API call later;
/// the int id is the lookup key.
class TraineeDirectory {
  const TraineeDirectory();

  static const _firstNames = [
    'Alex', 'Jordan', 'Taylor', 'Morgan', 'Casey', 'Riley', 'Jamie', 'Avery',
    'Cameron', 'Drew', 'Sam', 'Quinn', 'Reese', 'Skyler', 'Parker', 'Hayden',
    'Emerson', 'Rowan', 'Charlie', 'Finley',
  ];
  static const _lastNames = [
    'Carter', 'Bennett', 'Foster', 'Hughes', 'Morris', 'Reed', 'Sullivan',
    'Brooks', 'Coleman', 'Parker',
  ];
  static const _departments = [
    'Pharmacy', 'Operations', 'Retail', 'Logistics', 'Customer Care',
    'Quality', 'IT', 'Finance',
  ];
  static const _jobTitles = [
    'Pharmacist', 'Trainee', 'Store Associate', 'Team Lead', 'Coordinator',
    'Specialist', 'Supervisor',
  ];
  static const _statuses = ['Active', 'Invited', 'Completed'];

  /// Resolves a batch of trainee ids into profiles, preserving order.
  ///
  /// Replace the body with the directory API call when it is available; keep the
  /// return type so callers are unaffected.
  List<TraineeProfile> profilesFor(List<int> ids) =>
      ids.map(_mock).toList(growable: false);

  TraineeProfile _mock(int id) {
    // Seed by id so a given trainee always renders the same synthetic profile.
    final rng = Random(id);
    final first = _firstNames[rng.nextInt(_firstNames.length)];
    final last = _lastNames[rng.nextInt(_lastNames.length)];
    final name = '$first $last';
    final handle =
        '${first.toLowerCase()}.${last.toLowerCase().replaceAll('-', '')}';
    return TraineeProfile(
      id: id,
      name: name,
      email: '$handle@nahdi.sa',
      phone: '05${(rng.nextInt(9) + 1)}${_digits(rng, 7)}',
      department: _departments[rng.nextInt(_departments.length)],
      jobTitle: _jobTitles[rng.nextInt(_jobTitles.length)],
      status: _statuses[rng.nextInt(_statuses.length)],
    );
  }

  String _digits(Random rng, int count) {
    final b = StringBuffer();
    for (var i = 0; i < count; i++) {
      b.write(rng.nextInt(10));
    }
    return b.toString();
  }
}
