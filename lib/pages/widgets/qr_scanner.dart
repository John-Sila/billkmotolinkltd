import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> with TickerProviderStateMixin {
  bool _isProcessing = false;
  bool _torchOn = false;
  final MobileScannerController controller = MobileScannerController();

  late AnimationController _dotsController;
  late Animation<int> _dotsAnimation;
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();

    // Dots animation
    _dotsController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _dotsAnimation = IntTween(begin: 1, end: 3).animate(
      CurvedAnimation(
        parent: _dotsController,
        curve: const Interval(0.0, 0.9, curve: Curves.easeInOut),
      ),
    );

    // Scanning line animation
    _scanLineController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scanLineController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    _dotsController.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  String _getDots() {
    final dotCount = _dotsAnimation.value;
    return '.' * dotCount;
  }

  void _toggleTorch() async {
    try {
      await controller.toggleTorch();
      setState(() => _torchOn = !_torchOn);
    } catch (e) {
      // Silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: _dotsController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.withValues(alpha: 0.3),
                    Colors.green.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.green, blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Scanner${_getDots()}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        backgroundColor: Colors.black87,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          GestureDetector(
            onTap: _toggleTorch,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withValues(alpha: 0.3),
                    Colors.yellow.withValues(alpha: 0.2),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _torchOn
                        ? Colors.yellow.withValues(alpha: 0.5)
                        : Colors.orange.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                color: _torchOn ? Colors.yellow[300] : Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            fit: BoxFit.cover,
            onDetect: (capture) async {
              if (_isProcessing) return;
              _isProcessing = true;

              final barcode = capture.barcodes.first;
              final raw = barcode.rawValue ?? "";
              await controller.stop();

              if (mounted) {
                Navigator.pop(context, raw);
              }
            },
          ),

          // Vignette
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.4),
                radius: 0.7,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),

          // Scanning line
          AnimatedBuilder(
            animation: _scanLineController,
            builder: (context, child) {
              return CustomPaint(
                painter: _ScanningLinePainter(scanPosition: _scanLineAnimation.value),
                size: Size.infinite,
              );
            },
          ),

          // Scanning frame
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.9),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.5),
                    blurRadius: 30,
                    spreadRadius: 3,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Positioned(top: 0, left: 0, child: _Corner()),
                  const Positioned(top: 0, right: 0, child: _Corner()),
                  const Positioned(bottom: 0, left: 0, child: _Corner()),
                  const Positioned(bottom: 0, right: 0, child: _Corner()),

                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Position QR code here",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Scanning line painter
class _ScanningLinePainter extends CustomPainter {
  final double scanPosition;

  const _ScanningLinePainter({required this.scanPosition});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.green.withValues(alpha: 0.3),
          Colors.green.withValues(alpha: 0.8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 6))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0);

    final lineHeight = 6.0;
    final scanY = size.height * 0.25 + (size.height * 0.5 * scanPosition);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(30, scanY - lineHeight / 2, size.width - 60, lineHeight),
        const Radius.circular(6),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Corner widget
class _Corner extends StatelessWidget {
  const _Corner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(18),
          topLeft: Radius.circular(18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.7),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }
}