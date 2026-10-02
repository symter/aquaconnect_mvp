/// Lets the screen around a `FarmReportFrame` trigger the browser's print
/// dialog for the report (→ "PDF로 저장").
class FarmReportFrameController {
  void Function()? _print;

  /// False until the frame is attached (and always false off the web).
  bool get canPrint => _print != null;

  void print() => _print?.call();

  // ignore: use_setters_to_change_properties
  void attach(void Function()? print) => _print = print;
}
