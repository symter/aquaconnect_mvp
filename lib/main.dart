import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/ai_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');

  // AI 리포트에 쓸 AI — 둘 중 한 줄만 주석을 풀어 두세요.
  // 모델(Flash/Opus 등)은 서버가 자동으로 고릅니다: 좋은 모델부터 쓰고 한도가 떨어지면 낮은 모델로.
  AiSettings.provider = AiProvider.gemini; // Railway 변수 MODEL_API_KEY (또는 GEMINI_API_KEY)
  // AiSettings.provider = AiProvider.claude; // Railway 변수 ANTHROPIC_API_KEY

  runApp(const ProviderScope(child: AquaConnectApp()));
}
// mains
