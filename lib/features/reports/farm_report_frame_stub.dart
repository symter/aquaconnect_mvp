import 'package:flutter/material.dart';

import 'farm_report_frame_controller.dart';

export 'farm_report_frame_controller.dart';

/// Non-web fallback (VM tests): the report HTML can only be rendered in a
/// browser, so this shows a placeholder.
class FarmReportFrame extends StatelessWidget {
  const FarmReportFrame({super.key, required this.html, required this.controller});

  final String html;
  final FarmReportFrameController controller;

  @override
  Widget build(BuildContext context) => const Center(child: Text('리포트는 웹에서만 볼 수 있습니다.'));
}
