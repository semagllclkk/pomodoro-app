import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const PixelPomodoroApp());

class PixelPomodoroApp extends StatelessWidget {
  const PixelPomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pink Pixel Pomodoro',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFF0F5), // Lavender Blush
        textTheme: GoogleFonts.pressStart2pTextTheme(),
      ),
      home: const PomodoroScreen(),
    );
  }
}

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  static const int workDuration = 25 * 60;
  static const int breakDuration = 5 * 60;
  
  int timeLeft = workDuration;
  bool isRunning = false;
  String currentState = 'idle'; // 'idle', 'working', 'onBreak'
  Timer? timer;

  String get currentAsset {
    if (currentState == 'idle') {
      return 'assets/asset-sheet_slices/uygulama-girisi.jpg';
    } else if (currentState == 'working') {
      return 'assets/asset-sheet_slices/odaklanma.jpg';
    } else if (currentState == 'onBreak') {
      return 'assets/asset-sheet_slices/mola.jpg';
    }
    return 'assets/asset-sheet_slices/uygulama-girisi.jpg';
  }

  void startTimer() {
    setState(() {
      isRunning = true;
      if (currentState == 'idle') {
        currentState = 'working';
        timeLeft = workDuration;
      }
    });
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft > 0) {
        setState(() => timeLeft--);
      } else {
        // Timer ended: switch between work and break
        if (currentState == 'working') {
          setState(() {
            currentState = 'onBreak';
            timeLeft = breakDuration;
          });
        } else if (currentState == 'onBreak') {
          stopTimer();
          setState(() {
            currentState = 'idle';
            timeLeft = workDuration;
          });
        }
      }
    });
  }

  void stopTimer() {
    setState(() => isRunning = false);
    timer?.cancel();
  }

  void resetTimer() {
    stopTimer();
    setState(() {
      currentState = 'idle';
      timeLeft = workDuration;
    });
  }

  String get timerText {
    int minutes = timeLeft ~/ 60;
    int seconds = timeLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Tablet optimizasyonu için max genişlik sınırı
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Dynamic hero image: changes based on timer state
              Hero(
                tag: 'app-hero',
                child: Image.asset(
                  currentAsset,
                  width: 160,
                  height: 160,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Text(
                    '>-<',
                    style: TextStyle(fontSize: 48, color: Color(0xFFFF69B4)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                currentState == 'working'
                    ? 'ODAKLANMA VAKTİ'
                    : currentState == 'onBreak'
                        ? 'MOLA VAKTİ'
                        : 'BAŞLAMAYA HAZIR',
                style: const TextStyle(
                    fontSize: 24, color: Color(0xFFFFB6C1)), // Light Pink
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC0CB), // Pink
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF69B4), width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFFF69B4),
                      offset: Offset(4, 4),
                    )
                  ],
                ),
                child: Text(
                  timerText,
                  style: const TextStyle(
                    fontSize: 72,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PixelButton(
                    text: isRunning ? 'DURDUR' : 'BAŞLA',
                    onPressed: isRunning ? stopTimer : startTimer,
                    color: const Color(0xFFFF69B4),
                  ),
                  const SizedBox(width: 20),
                  _PixelButton(
                    text: 'SIFIRLA',
                    onPressed: resetTimer,
                    color: const Color(0xFFFFA07A), // Light Salmon
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PixelButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;

  const _PixelButton({
    required this.text,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
            )
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}
