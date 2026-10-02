import 'package:shared_preferences/shared_preferences.dart';

/// First-run tutorial progress for the staff app — per-device, persisted
/// locally like [DigestSettingsStore]. It's a personal UI preference, so it
/// never touches the `server/` API (and is shared by accounts on one device).
class OnboardingState {
  const OnboardingState({
    this.welcomeSeen = false,
    this.checklistDone = const {},
    this.checklistHidden = false,
    this.coachmarksSeen = const {},
  });

  final bool welcomeSeen;

  /// Ids of completed start-guide checklist steps.
  final Set<String> checklistDone;

  /// True once the user dismissed the checklist card from Home.
  final bool checklistHidden;

  /// Ids of tabs whose one-time intro overlay was already shown.
  final Set<String> coachmarksSeen;

  OnboardingState copyWith({
    bool? welcomeSeen,
    Set<String>? checklistDone,
    bool? checklistHidden,
    Set<String>? coachmarksSeen,
  }) {
    return OnboardingState(
      welcomeSeen: welcomeSeen ?? this.welcomeSeen,
      checklistDone: checklistDone ?? this.checklistDone,
      checklistHidden: checklistHidden ?? this.checklistHidden,
      coachmarksSeen: coachmarksSeen ?? this.coachmarksSeen,
    );
  }
}

class OnboardingStore {
  static const _welcomeSeenKey = 'aquaconnect.onboarding.welcome_seen';
  static const _checklistDoneKey = 'aquaconnect.onboarding.checklist_done';
  static const _checklistHiddenKey = 'aquaconnect.onboarding.checklist_hidden';
  static const _coachmarksSeenKey = 'aquaconnect.onboarding.coachmarks_seen';

  Future<OnboardingState> read() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingState(
      welcomeSeen: prefs.getBool(_welcomeSeenKey) ?? false,
      checklistDone: (prefs.getStringList(_checklistDoneKey) ?? const []).toSet(),
      checklistHidden: prefs.getBool(_checklistHiddenKey) ?? false,
      coachmarksSeen: (prefs.getStringList(_coachmarksSeenKey) ?? const []).toSet(),
    );
  }

  Future<void> write(OnboardingState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, state.welcomeSeen);
    await prefs.setStringList(_checklistDoneKey, state.checklistDone.toList());
    await prefs.setBool(_checklistHiddenKey, state.checklistHidden);
    await prefs.setStringList(_coachmarksSeenKey, state.coachmarksSeen.toList());
  }
}
