import 'package:flutter_riverpod/legacy.dart';

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

/// True while the main shell (the four tabs) is on screen. The Thumb Dock only
/// shows then, so it never floats over login, semester choice or onboarding.
final mainShellVisibleProvider = StateProvider<bool>((ref) => false);
