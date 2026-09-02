import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const PixelPomodoroApp());

class PixelPomodoroApp extends StatelessWidget {
  const PixelPomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pomodoro',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFBCC3),
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
  int configuredWorkMinutes = 25;
  int configuredBreakMinutes = 5;
  bool isRunning = false;
  bool soundEnabled = true;
  bool musicEnabled = true;
  String currentState = 'idle'; // 'idle', 'working', 'onBreak'
  Timer? timer;
  final AudioPlayer clickPlayer = AudioPlayer();
  final AudioPlayer loopPlayer = AudioPlayer();

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

  @override
  void initState() {
    super.initState();
    _startLoopMusic();
  }

  Future<void> _startLoopMusic() async {
    await loopPlayer.setReleaseMode(ReleaseMode.loop);
    await loopPlayer.setVolume(0.18);
    await loopPlayer.setSource(AssetSource('sounds/loop.mp3'));
    if (musicEnabled) {
      await loopPlayer.resume();
    }
  }

  Future<void> _playClick() async {
    if (soundEnabled) {
      await clickPlayer.play(AssetSource('sounds/button-click.mp3'));
    }
  }

  Future<void> _toggleMusic(StateSetter? setDialogState) async {
    await _playClick();
    final newValue = !musicEnabled;
    setState(() => musicEnabled = newValue);
    setDialogState?.call(() {});
    if (newValue) {
      await _startLoopMusic();
    } else {
      await loopPlayer.stop();
    }
  }

  void startTimer() {
    _playClick();
    setState(() {
      isRunning = true;
      if (currentState == 'idle') {
        currentState = 'working';
        timeLeft = configuredWorkMinutes * 60;
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
            timeLeft = configuredBreakMinutes * 60;
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
    _playClick();
    setState(() => isRunning = false);
    timer?.cancel();
  }

  void resetTimer() {
    _playClick();
    stopTimer();
    setState(() {
      currentState = 'idle';
      timeLeft = configuredWorkMinutes * 60;
    });
  }

  void openSettings() {
    _playClick();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFBCC3),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset('assets/asset-sheet_slices/settings.jpg',
                width: 56, height: 56),
            const Text('AYARLAR', style: TextStyle(fontSize: 16)),
            _AssetButton(
                asset: 'assets/asset-sheet_slices/ret.png',
                onTap: () => Navigator.pop(context)),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SettingRow(
                label: 'POMODORO',
                value: configuredWorkMinutes,
                onMinus: () => setDialogState(() {
                  if (configuredWorkMinutes > 1) {
                    configuredWorkMinutes--;
                  }
                  if (!isRunning && currentState == 'idle') {
                    timeLeft = configuredWorkMinutes * 60;
                  }
                }),
                onPlus: () => setDialogState(() {
                  configuredWorkMinutes++;
                  if (!isRunning && currentState == 'idle') {
                    timeLeft = configuredWorkMinutes * 60;
                  }
                }),
              ),
              _SettingRow(
                label: 'MOLA',
                value: configuredBreakMinutes,
                onMinus: () => setDialogState(() {
                  if (configuredBreakMinutes > 1) {
                    configuredBreakMinutes--;
                  }
                }),
                onPlus: () => setDialogState(() => configuredBreakMinutes++),
              ),
              const SizedBox(height: 10),
              _AssetButton(
                asset: soundEnabled
                    ? 'assets/asset-sheet_slices/ses-ac.png'
                    : 'assets/asset-sheet_slices/ses-kapa.png',
                label: soundEnabled ? 'SES ACIK' : 'SES KAPALI',
                onTap: () {
                  setState(() => soundEnabled = !soundEnabled);
                  setDialogState(() {});
                },
              ),
              const SizedBox(height: 10),
              _AssetButton(
                asset: musicEnabled
                    ? 'assets/asset-sheet_slices/muzik-ac.png'
                    : 'assets/asset-sheet_slices/muzik-kapa.png',
                label: musicEnabled ? 'MUZIK ACIK' : 'MUZIK KAPALI',
                onTap: () async {
                  await _toggleMusic(setDialogState);
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/asset-sheet_slices/onay.png',
                      width: 32, height: 32),
                  const SizedBox(width: 8),
                  Image.asset('assets/asset-sheet_slices/uyari.png',
                      width: 32, height: 32),
                ],
              ),
              const SizedBox(height: 10),
              _AssetButton(
                  asset: 'assets/asset-sheet_slices/ret.png',
                  label: 'CIKIS',
                  onTap: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    clickPlayer.dispose();
    loopPlayer.dispose();
    super.dispose();
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
      body: CustomPaint(
        painter: _CrystalPainter(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Dynamic hero image: changes based on timer state
                  Hero(
                    tag: 'app-hero',
                    child: Image.asset(
                      currentAsset,
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const SizedBox.shrink(),
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
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC0CB), // Pink
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0xFFFF69B4), width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFFFF69B4),
                          offset: Offset(4, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/asset-sheet_slices/time.jpg',
                            width: 34, height: 34),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              timerText,
                              style: const TextStyle(
                                  fontSize: 48,
                                  color: Colors.white,
                                  letterSpacing: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _PixelButton(
                          text: isRunning ? 'DURDUR' : 'BAŞLA',
                          onPressed: isRunning ? stopTimer : startTimer,
                          color: const Color(0xFFFF69B4),
                          asset: 'assets/asset-sheet_slices/pomodoro-start.jpg',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PixelButton(
                          text: 'SIFIRLA',
                          onPressed: resetTimer,
                          color: const Color(0xFFFF6B6B),
                          asset: 'assets/asset-sheet_slices/pomodoro-end.jpg',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Temporary button for testing break mode
                  SizedBox(
                    width: double.infinity,
                    child: _PixelButton(
                      text: 'MOLA TEST',
                      onPressed: () {
                        stopTimer();
                        setState(() {
                          currentState = 'onBreak';
                          timeLeft = breakDuration;
                        });
                      },
                      color: const Color(0xFF87CEEB), // Sky Blue
                      asset: 'assets/asset-sheet_slices/mola.jpg',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AssetButton(
                    asset: 'assets/asset-sheet_slices/settings.jpg',
                    label: 'AYARLAR',
                    onTap: openSettings,
                  ),
                ],
              ),
            ),
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
  final String? asset;

  const _PixelButton({
    required this.text,
    required this.onPressed,
    required this.color,
    this.asset,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (asset != null)
              Image.asset(asset!, width: 26, height: 26, fit: BoxFit.contain),
            if (asset != null) const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetButton extends StatelessWidget {
  final String asset;
  final VoidCallback onTap;
  final String? label;

  const _AssetButton({required this.asset, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, width: 42, height: 42, fit: BoxFit.contain),
          if (label != null) Text(label!, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _SettingRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        _AssetButton(
            asset: 'assets/asset-sheet_slices/azalt.png', onTap: onMinus),
        Text('$value dk', style: const TextStyle(fontSize: 11)),
        _AssetButton(
            asset: 'assets/asset-sheet_slices/arttir.png', onTap: onPlus),
      ],
    );
  }
}

class _CrystalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFE6EA);
    const crystalSize = 4.0;
    const points = [
      Offset(28, 90),
      Offset(92, 180),
      Offset(220, 70),
      Offset(330, 150),
      Offset(470, 100),
      Offset(560, 220),
      Offset(42, 420),
      Offset(500, 480),
      Offset(150, 620),
    ];
    for (final point in points) {
      canvas.drawRect(
        Rect.fromCenter(center: point, width: crystalSize, height: 20),
        paint,
      );
      canvas.drawRect(
        Rect.fromCenter(center: point, width: 20, height: crystalSize),
        paint,
      );
      canvas.drawRect(
        Rect.fromCenter(center: point, width: 8, height: 8),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
