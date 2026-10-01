import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/onboarding_store.dart';

final onboardingStoreProvider = Provider<OnboardingStore>((ref) => OnboardingStore());

final onboardingProvider = AsyncNotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);

class OnboardingNotifier extends AsyncNotifier<OnboardingState> {
  @override
  Future<OnboardingState> build() {
    return ref.watch(onboardingStoreProvider).read();
  }

  Future<void> _update(OnboardingState Function(OnboardingState) transform) async {
    final current = state.valueOrNull ?? await ref.read(onboardingStoreProvider).read();
    final next = transform(current);
    await ref.read(onboardingStoreProvider).write(next);
    state = AsyncValue.data(next);
  }

  Future<void> markWelcomeSeen() => _update((s) => s.copyWith(welcomeSeen: true));

  Future<void> markCoachmarkSeen(String tabId) =>
      _update((s) => s.copyWith(coachmarksSeen: {...s.coachmarksSeen, tabId}));

  Future<void> completeStep(String stepId) {
    if (state.valueOrNull?.checklistDone.contains(stepId) == true) return Future.value();
    return _update((s) => s.copyWith(checklistDone: {...s.checklistDone, stepId}));
  }

  Future<void> hideChecklist() => _update((s) => s.copyWith(checklistHidden: true));

  /// "사용 가이드 다시 보기" — wipes all progress so the tutorial replays.
  Future<void> reset() => _update((_) => const OnboardingState());
}
