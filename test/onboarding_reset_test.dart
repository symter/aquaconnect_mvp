import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aquaconnect_mvp/core/providers/onboarding_provider.dart';

void main() {
  test('reset clears every checklist step', () async {
    SharedPreferences.setMockInitialValues({
      'aquaconnect.onboarding.checklist_done': ['farm', 'station', 'memo'],
      'aquaconnect.onboarding.welcome_seen': true,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = await container.read(onboardingProvider.future);
    expect(before.checklistDone.length, 3);

    await container.read(onboardingProvider.notifier).reset();
    expect(container.read(onboardingProvider).value!.checklistDone, isEmpty);
    expect((await container.read(onboardingStoreProvider).read()).checklistDone, isEmpty);
  });
}
