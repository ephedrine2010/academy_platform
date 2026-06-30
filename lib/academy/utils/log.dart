import 'package:flutter/foundation.dart';

/// Lightweight tagged console logging for the POC. Output shows up in the
/// `flutter run` console (and the Debug Console in the IDE).
void logScorm(String message) => debugPrint('[SCORM]    $message');

void logServer(String message) => debugPrint('[SERVER]   $message');

void logCubit(String message) => debugPrint('[CUBIT]    $message');

void logAuth(String message) => debugPrint('[AUTH]     $message');

void logCourse(String message) => debugPrint('[COURSE]   $message');

void logInstructor(String message) => debugPrint('[INSTRUCT] $message');

void logError(String where, Object error, [StackTrace? stack]) {
  debugPrint('[ERROR]    $where: $error');
  if (stack != null) debugPrint(stack.toString());
}
