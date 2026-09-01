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
  int timeLeft = workDuration;
  bool isRunning = false;
  Timer? timer;

  void startTimer() {
    setState(() => isRunning = true);
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft > 0) {
        setState(() => timeLeft--);
      } else {
        stopTimer();
      }
    });
  }

  void stopTimer() {
    setState(() => isRunning = false);
    timer?.cancel();
  }

  void resetTimer() {
    stopTimer();
    setState(() => timeLeft = workDuration);
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
              const Text(
                '(>‿<)',
                style: TextStyle(fontSize: 48, color: Color(0xFFFF69B4)), // Hot Pink
              ),
              const SizedBox(height: 20),
              const Text(
                'ÇALIŞMA VAKTİ',
                style: TextStyle(fontSize: 24, color: Color(0xFFFFB6C1)), // Light Pink
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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