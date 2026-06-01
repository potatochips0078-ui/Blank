import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '幸运转盘',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const WheelPage(),
    );
  }
}

class WheelPage extends StatefulWidget {
  const WheelPage({super.key});

  @override
  State<WheelPage> createState() => _WheelPageState();
}

class _WheelPageState extends State<WheelPage> with TickerProviderStateMixin {
  Timer? _spinTimer;
  AnimationController? _stopController;
  Animation<double>? _stopAnimation;
  bool _isSpinning = false;
  double _currentAngle = 0;

  final List<String> _prizes = [
    '手机',
    '钞票',
    '奔驰',
    '金条',
    '金表',
    '没中',
  ];

  final List<Color> _colors = [
    const Color(0xFFFF6B6B),
    const Color(0xFF4ECDC4),
    const Color(0xFFFFE66D),
    const Color(0xFF95E1D3),
    const Color(0xFFF38181),
    const Color(0xFFAA96DA),
  ];

  @override
  void dispose() {
    _spinTimer?.cancel();
    _stopController?.dispose();
    super.dispose();
  }

  void _startSpin() {
    if (_isSpinning) return;
    
    setState(() {
      _isSpinning = true;
    });
    
    _spinTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      setState(() {
        _currentAngle += 0.15;
        if (_currentAngle >= 2 * pi) {
          _currentAngle -= 2 * pi;
        }
      });
    });
  }

  void _stopOnMiss() {
    if (!_isSpinning) return;
    
    _spinTimer?.cancel();
    
    const segmentAngle = 2 * pi / 6;
    
    // 分析：
    // 1. 扇形5是"没中"，它在转盘自身坐标系中的中间角度是: 5*segmentAngle + segmentAngle/2
    // 2. 当转盘旋转了 angle 度时，扇形5在屏幕上的位置是: (5*segmentAngle + segmentAngle/2) + angle
    // 3. 我们希望扇形5的中间正好在屏幕上方（3pi/2）
    // 4. 所以: (5*segmentAngle + segmentAngle/2) + finalAngle ≡ 3pi/2 mod 2pi
    // 5. 解得: finalAngle ≡ 3pi/2 - (5*segmentAngle + segmentAngle/2) mod 2pi
    
    final missMid = 5 * segmentAngle + segmentAngle / 2;
    var desiredAngle = (3 * pi / 2 - missMid) % (2 * pi);
    if (desiredAngle < 0) desiredAngle += 2 * pi;
    
    // 计算从当前角度到目标角度需要旋转多少
    final currentNorm = _currentAngle % (2 * pi);
    var delta = desiredAngle - currentNorm;
    if (delta < 0) delta += 2 * pi;
    
    // 加上一圈让旋转更自然
    final targetAngle = _currentAngle + delta + 2 * pi;
    
    _stopController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _stopAnimation = Tween<double>(
      begin: _currentAngle,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _stopController!,
      curve: Curves.easeOutCubic,
    ))
      ..addListener(() {
        setState(() {
          _currentAngle = _stopAnimation!.value;
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _isSpinning = false;
          });
        }
      });
    
    _stopController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('幸运转盘'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: _currentAngle,
                  child: FortuneWheel(
                    prizes: _prizes,
                    colors: _colors,
                  ),
                ),
                const Pointer(),
              ],
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isSpinning ? null : _startSpin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    textStyle: const TextStyle(fontSize: 20),
                  ),
                  child: const Text('开始'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _isSpinning ? _stopOnMiss : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    textStyle: const TextStyle(fontSize: 20),
                  ),
                  child: const Text('停'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FortuneWheel extends StatelessWidget {
  final List<String> prizes;
  final List<Color> colors;

  const FortuneWheel({
    super.key,
    required this.prizes,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 4),
      ),
      child: CustomPaint(
        painter: WheelPainter(prizes: prizes, colors: colors),
      ),
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<String> prizes;
  final List<Color> colors;

  WheelPainter({required this.prizes, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / prizes.length;

    for (int i = 0; i < prizes.length; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * segmentAngle,
        segmentAngle,
        true,
        paint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: prizes[i],
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final angle = i * segmentAngle + segmentAngle / 2;
      final textRadius = radius * 0.6;
      final textOffset = Offset(
        center.dx + textRadius * cos(angle) - textPainter.width / 2,
        center.dy + textRadius * sin(angle) - textPainter.height / 2,
      );

      canvas.save();
      canvas.translate(textOffset.dx + textPainter.width / 2, textOffset.dy + textPainter.height / 2);
      canvas.rotate(angle + pi / 2);
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < prizes.length; i++) {
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * cos(i * segmentAngle),
          center.dy + radius * sin(i * segmentAngle),
        ),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Pointer extends StatelessWidget {
  const Pointer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 3),
      ),
      child: CustomPaint(
        painter: PointerPainter(),
      ),
    );
  }
}

class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width / 2 + 10, 15)
      ..lineTo(size.width / 2 - 10, 15)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
