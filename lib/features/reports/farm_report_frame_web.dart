import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'farm_report_frame_controller.dart';

export 'farm_report_frame_controller.dart';

/// Renders a report built by `buildFarmReportHtml` in an `<iframe srcdoc>`,
/// so the page keeps its own A4 CSS and prints exactly like the standalone
/// HTML file.
class FarmReportFrame extends StatefulWidget {
  const FarmReportFrame({super.key, required this.html, required this.controller});

  final String html;
  final FarmReportFrameController controller;

  @override
  State<FarmReportFrame> createState() => _FarmReportFrameState();
}

class _FarmReportFrameState extends State<FarmReportFrame> {
  web.HTMLIFrameElement? _frame;

  @override
  void didUpdateWidget(FarmReportFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.attach(null);
      widget.controller.attach(_print);
    }
    if (oldWidget.html != widget.html) _frame?.srcdoc = widget.html.toJS;
  }

  @override
  void dispose() {
    widget.controller.attach(null);
    super.dispose();
  }

  void _print() => _frame?.contentWindow?.print();

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (element) {
        final frame = element as web.HTMLIFrameElement
          ..title = '양식장 관리 리포트'
          ..srcdoc = widget.html.toJS;
        frame.style
          ..border = 'none'
          ..width = '100%'
          ..height = '100%';
        _frame = frame;
        widget.controller.attach(_print);
      },
    );
  }
}
