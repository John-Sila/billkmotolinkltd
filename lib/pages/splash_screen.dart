import 'package:flutter/material.dart';

/// The launch screen.
///
/// Android (res/drawable/launch_background.xml, values-v31 splash) and iOS
/// (LaunchImage) already show the ultracem mark, centred, at [_markHeight]
/// the instant the app starts. This widget picks up from exactly that frame -
/// same mark, same size, same position, same background - so there is no jump
/// when Flutter takes over, then adds the wordmark and a loading bar while the
/// app initialises.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.error,
    this.onRetry,
    this.settled = false,
  });

  /// When set, replaces the loading bar with a message and a retry button.
  final String? error;
  final VoidCallback? onRetry;

  /// Skip the intro animation (used for short waits after launch, e.g. the
  /// auth check, so the logo doesn't replay).
  final bool settled;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Keep in sync with H in the native launch resources.
  static const double _markHeight = 104;
  static const double _wordmarkHeight = 22;
  static const Color _accent = Color(0xFF00A087);

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  late final Animation<double> _pulseScale = Tween<double>(begin: 1.0, end: 1.045)
      .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  late final Animation<double> _wordFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
  );
  late final Animation<double> _loaderFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    if (widget.settled) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Must match ultracem_splash_bg in android res/values(-night)/colors.xml.
    final background = dark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: background,
      body: Semantics(
        label: 'ultracem is loading',
        child: Stack(
          children: [
            // Mark - dead centre, like the native splash.
            Center(
              child: ScaleTransition(
                scale: _pulseScale,
                child: Image.asset(
                  'assets/branding/ultracem_mark.png',
                  height: _markHeight,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
            ),

            // Wordmark - fades in and settles just under the mark.
            Center(
              child: AnimatedBuilder(
                animation: _wordFade,
                builder: (context, child) => Opacity(
                  opacity: _wordFade.value,
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      _markHeight / 2 + 30 + _wordmarkHeight / 2 + (1 - _wordFade.value) * 10,
                    ),
                    child: child,
                  ),
                ),
                child: Image.asset(
                  dark
                      ? 'assets/branding/ultracem_wordmark_light.png'
                      : 'assets/branding/ultracem_wordmark_dark.png',
                  height: _wordmarkHeight,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
            ),

            // Loading bar, or the error + retry if start-up failed.
            Positioned(
              left: 24,
              right: 24,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: FadeTransition(
                    opacity: _loaderFade,
                    child: widget.error == null ? _loadingBar() : _errorBlock(dark),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingBar() {
    return Center(
      child: SizedBox(
        width: 112,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 3,
            color: _accent,
            backgroundColor: _accent.withValues(alpha: 0.18),
          ),
        ),
      ),
    );
  }

  Widget _errorBlock(bool dark) {
    final muted = dark ? Colors.white70 : Colors.black54;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Couldn't start the app",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: dark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.error!,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: muted),
        ),
        if (widget.onRetry != null) ...[
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.onRetry,
            style: FilledButton.styleFrom(backgroundColor: _accent),
            child: const Text('Try again'),
          ),
        ],
      ],
    );
  }
}
