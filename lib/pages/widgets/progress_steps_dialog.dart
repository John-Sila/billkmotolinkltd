import 'package:flutter/material.dart';

enum StepStatus { pending, active, done, failed }

class ProgressStep {
  ProgressStep(this.label);
  final String label;
  StepStatus status = StepStatus.pending;
}

/// Drives the dialog. Usage:
///   final p = ProgressStepsController([...labels], title: '...');
///   p.show(context);
///   p.begin();              // first step starts spinning
///   await p.next();         // current step ticks green, next one starts
///   await p.finish();       // brief "All done", then closes
///   await p.abort();        // current step goes red, then closes
class ProgressStepsController extends ChangeNotifier {
  ProgressStepsController(List<String> labels, {this.title = 'Processing'})
      : steps = [for (final l in labels) ProgressStep(l)];

  final String title;
  final List<ProgressStep> steps;

  NavigatorState? _nav;
  bool _open = false;

  /// How long each tick stays visible before moving on.
  static const _tick = Duration(milliseconds: 450);

  bool get allDone => steps.every((s) => s.status == StepStatus.done);
  bool get hasFailed => steps.any((s) => s.status == StepStatus.failed);
  int get _activeIndex => steps.indexWhere((s) => s.status == StepStatus.active);

  String get headline =>
      hasFailed ? 'Something went wrong' : (allDone ? 'All done' : title);

  void show(BuildContext context) {
    if (_open) return;
    _open = true;

    // Drop the keyboard (left over from the M-Pesa phone field) so it can't
    // resize the dialog while it animates away.
    FocusManager.instance.primaryFocus?.unfocus();

    _nav = Navigator.of(context, rootNavigator: true);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Progress',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      useRootNavigator: true,
      pageBuilder: (_, __, ___) => _ProgressStepsDialog(controller: this),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void begin() {
    if (steps.isNotEmpty) steps.first.status = StepStatus.active;
    notifyListeners();
  }

  /// Completes the step that is running and starts the next one.
  Future<void> next() async {
    final i = _activeIndex;
    if (i < 0) return;
    steps[i].status = StepStatus.done;
    if (i + 1 < steps.length) steps[i + 1].status = StepStatus.active;
    notifyListeners();
    await Future.delayed(_tick);
  }

  /// Everything is saved: let the rider see all-green, then close.
  Future<void> finish() async {
    await Future.delayed(const Duration(milliseconds: 600));
    close();
  }

  /// Something failed: mark the running step red, then close.
  Future<void> abort() async {
    final i = _activeIndex;
    if (i >= 0) {
      steps[i].status = StepStatus.failed;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 700));
    }
    close();
  }

  /// Safe to call any number of times.
  void close() {
    if (!_open) return;
    _open = false;
    final nav = _nav;
    if (nav != null && nav.mounted && nav.canPop()) nav.pop();
  }
}

class _ProgressStepsDialog extends StatelessWidget {
  const _ProgressStepsDialog({required this.controller});
  final ProgressStepsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false, // no back-button escape while writing
      // Ignore the keyboard completely: the card never resizes because of it.
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Center(
          // Center gives the card loose constraints, so it is exactly as
          // tall as its content, never the full screen height.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 340),
              child: Material(
                color: theme.colorScheme.surfaceContainerHigh,
                elevation: 6,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) {
                      final steps = controller.steps;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              controller.headline,
                              key: ValueKey(controller.headline),
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please keep the app open.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 20),
                          for (var i = 0; i < steps.length; i++)
                            _StepRow(
                                step: steps[i], isLast: i == steps.length - 1),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.isLast});
  final ProgressStep step;
  final bool isLast;

  static const double _nodeSize = 26;
  static const double _lineHeight = 28;
  static const double _lineGap = 4; // space above and below the line

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = step.status;
    final Color textColor = switch (status) {
      StepStatus.pending => theme.colorScheme.outline,
      StepStatus.active => theme.colorScheme.onSurface,
      StepStatus.done => Colors.green[700]!,
      StepStatus.failed => theme.colorScheme.error,
    };

    // Every row is exactly as tall as its rail, so no intrinsic sizing is needed.
    final double rowHeight =
        isLast ? _nodeSize : _nodeSize + _lineGap * 2 + _lineHeight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepNode(status: status),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: _lineGap),
                  child: _StepLine(
                    filled: status == StepStatus.done,
                    height: _lineHeight,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: rowHeight),
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: status == StepStatus.active
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: textColor,
                ),
                child: Text(step.label),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({required this.status});
  final StepStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color = switch (status) {
      StepStatus.pending => scheme.outlineVariant,
      StepStatus.active => scheme.primary,
      StepStatus.done => Colors.green,
      StepStatus.failed => scheme.error,
    };
    final filled = status == StepStatus.done || status == StepStatus.failed;

    final Widget icon = switch (status) {
      StepStatus.done => const Icon(Icons.check,
          key: ValueKey('done'), size: 16, color: Colors.white),
      StepStatus.failed => const Icon(Icons.close,
          key: ValueKey('failed'), size: 16, color: Colors.white),
      StepStatus.active => SizedBox(
          key: const ValueKey('active'),
          height: 14,
          width: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
      StepStatus.pending => const SizedBox.shrink(key: ValueKey('pending')),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: icon,
      ),
    );
  }
}

/// Grey track that fills green from top to bottom when its step completes.
class _StepLine extends StatelessWidget {
  const _StepLine({required this.filled, required this.height});
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.outlineVariant;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: filled ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (_, v, __) => SizedBox(
        width: 2,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: v,
                child: const ColoredBox(color: Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
