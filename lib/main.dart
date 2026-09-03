import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
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
  List<_FocusSession> focusSessions = [];

  // Blink state
  bool _blinkVisible = true;
  Timer? _blinkTimer;
  bool _isBlinking = false;

  final AudioPlayer clickPlayer = AudioPlayer();
  final AudioPlayer loopPlayer = AudioPlayer();
  final AudioPlayer alertPlayer = AudioPlayer();

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

  String get statusText {
    if (currentState == 'working') return 'ODAKLANMA VAKTİ';
    if (currentState == 'onBreak') return 'MOLA VAKTİ';
    return 'BAŞLAMAYA HAZIR';
  }

  // Blink label shown during timer transitions or warnings
  String? get blinkLabel {
    if (currentState == 'working' && timeLeft == 0)
      return 'BİRAZ DİNLENME VAKTİ!';
    if (currentState == 'onBreak' && timeLeft == 0) return 'ODAKLANMA VAKTİ!';
    if (currentState == 'onBreak' && timeLeft <= 30 && timeLeft > 0)
      return 'MOLA BİTİYOR!';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadFocusSessions();
    _startLoopMusic();
  }

  Future<void> _loadFocusSessions() async {
    final preferences = await SharedPreferences.getInstance();
    final savedSessions = preferences.getStringList('focus_sessions') ?? [];
    if (!mounted) return;
    setState(() {
      focusSessions = savedSessions
          .map((value) => _FocusSession.fromJson(jsonDecode(value)))
          .toList();
    });
  }

  Future<void> _recordFocusSession() async {
    final session = _FocusSession(
      completedAt: DateTime.now(),
      durationMinutes: configuredWorkMinutes,
    );
    final updatedSessions = [...focusSessions, session];
    setState(() => focusSessions = updatedSessions);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'focus_sessions',
      updatedSessions.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> _startLoopMusic() async {
    if (!musicEnabled) return;
    await loopPlayer.setReleaseMode(ReleaseMode.loop);
    await loopPlayer.setVolume(0.18);
    if (!mounted || !musicEnabled) return;
    await loopPlayer.play(AssetSource('sounds/loop.mp3'));
  }

  Future<void> _playClick() async {
    if (soundEnabled) {
      await clickPlayer.play(AssetSource('sounds/button-click.mp3'));
    }
  }

  Future<void> _startAlertLoop() async {
    if (!soundEnabled) return;
    await alertPlayer.setReleaseMode(ReleaseMode.loop);
    await alertPlayer.play(AssetSource('sounds/alert-warn.mp3'));
  }

  Future<void> _playAlert() async {
    await _startAlertLoop();
  }

  Future<void> _stopAlert() async {
    await alertPlayer.stop();
    await alertPlayer.setReleaseMode(ReleaseMode.release);
  }

  void _startBlink() {
    if (_isBlinking) return;
    _isBlinking = true;
    _blinkVisible = true;
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _blinkVisible = !_blinkVisible);
    });
  }

  void _stopBlink() {
    _isBlinking = false;
    _blinkTimer?.cancel();
    _blinkTimer = null;
    _stopAlert();
    if (mounted) setState(() => _blinkVisible = true);
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
    _stopBlink();
    setState(() {
      isRunning = true;
      if (currentState == 'idle') {
        currentState = 'working';
        timeLeft = configuredWorkMinutes * 60;
      }
    });
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft > 0) {
        setState(() => timeLeft--);
        // Last 30 seconds of break warning
        if (currentState == 'onBreak' && timeLeft == 30) {
          _playAlert();
          _startBlink();
        }
        if (currentState == 'onBreak' && timeLeft > 30 && _isBlinking) {
          _stopBlink();
        }
      } else {
        // Timer ended: switch between work and break
        if (currentState == 'working') {
          _playAlert();
          _startBlink();
          _recordFocusSession();
          setState(() {
            currentState = 'onBreak';
            timeLeft = configuredBreakMinutes * 60;
          });
        } else if (currentState == 'onBreak') {
          _playAlert();
          _stopBlink();
          t.cancel();
          setState(() {
            isRunning = false;
            currentState = 'idle';
            timeLeft = configuredWorkMinutes * 60;
          });
          // Show "focus time" blink briefly
          _startBlink();
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) _stopBlink();
          });
        }
      }
    });
  }

  void stopTimer() {
    _playClick();
    _stopBlink();
    setState(() => isRunning = false);
    timer?.cancel();
  }

  void resetTimer() {
    _playClick();
    _stopBlink();
    timer?.cancel();
    setState(() {
      isRunning = false;
      currentState = 'idle';
      timeLeft = configuredWorkMinutes * 60;
    });
  }

  void skipPhase() {
    _playClick();
    if (currentState == 'idle') return;
    timer?.cancel();
    _stopBlink();
    setState(() {
      if (currentState == 'working') {
        currentState = 'onBreak';
        timeLeft = configuredBreakMinutes * 60;
        isRunning = true;
      } else {
        currentState = 'idle';
        timeLeft = configuredWorkMinutes * 60;
        isRunning = false;
      }
    });
    if (isRunning) {
      startTimer();
    }
  }

  void fastForward() {
    _playClick();
    if (currentState == 'idle') return;
    if (timeLeft > 60) {
      setState(() => timeLeft -= 60);
      return;
    }
    skipPhase();
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
                    setState(() => configuredWorkMinutes--);
                  }
                  if (!isRunning && currentState == 'idle') {
                    setState(() => timeLeft = configuredWorkMinutes * 60);
                  }
                }),
                onPlus: () => setDialogState(() {
                  setState(() => configuredWorkMinutes++);
                  if (!isRunning && currentState == 'idle') {
                    setState(() => timeLeft = configuredWorkMinutes * 60);
                  }
                }),
              ),
              _SettingRow(
                label: 'MOLA',
                value: configuredBreakMinutes,
                onMinus: () {
                  if (configuredBreakMinutes > 1) {
                    setState(() => configuredBreakMinutes--);
                    if (!isRunning && currentState == 'onBreak') {
                      setState(() => timeLeft = configuredBreakMinutes * 60);
                    }
                    setDialogState(() {});
                  }
                },
                onPlus: () {
                  setState(() => configuredBreakMinutes++);
                  if (!isRunning && currentState == 'onBreak') {
                    setState(() => timeLeft = configuredBreakMinutes * 60);
                  }
                  setDialogState(() {});
                },
              ),
              const SizedBox(height: 10),
              _AssetButton(
                asset: soundEnabled
                    ? 'assets/asset-sheet_slices/ses-ac.png'
                    : 'assets/asset-sheet_slices/ses-kapa.png',
                label: soundEnabled ? 'SES ACIK' : 'SES KAPALI',
                onTap: () async {
                  final newValue = !soundEnabled;
                  setState(() => soundEnabled = newValue);
                  if (newValue && _isBlinking) {
                    await _startAlertLoop();
                  } else if (!newValue) {
                    await _stopAlert();
                  }
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
                ],
              ),
              const SizedBox(height: 10),
              _AssetButton(
                asset: 'assets/asset-sheet_slices/ret.png',
                label: 'UYGULAMADAN ÇIK',
                onTap: () {
                  Navigator.pop(context);
                  _showExitConfirmation();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openReport() {
    _playClick();
    showDialog<void>(
      context: context,
      builder: (context) => _ReportDialog(sessions: focusSessions),
    );
  }

  void _showExitConfirmation() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFBCC3),
        title: Row(
          children: [
            Image.asset('assets/asset-sheet_slices/pomodoro-end.jpg',
                width: 32, height: 32),
            const SizedBox(width: 8),
            const Text('ÇIKIŞ', style: TextStyle(fontSize: 14)),
          ],
        ),
        content: const Text(
          'Uygulamadan çıkmak istediğine emin misin?',
          style: TextStyle(fontSize: 10),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/asset-sheet_slices/ret.png',
                        width: 32, height: 32),
                    const SizedBox(width: 4),
                    const Text('HAYIR', style: TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  SystemNavigator.pop();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/asset-sheet_slices/onay.png',
                        width: 32, height: 32),
                    const SizedBox(width: 4),
                    const Text('EVET', style: TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _blinkTimer?.cancel();
    clickPlayer.dispose();
    loopPlayer.dispose();
    alertPlayer.dispose();
    super.dispose();
  }

  String get timerText {
    int minutes = timeLeft ~/ 60;
    int seconds = timeLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final label = blinkLabel;
    return Scaffold(
      body: SafeArea(
        child: CustomPaint(
          painter: _CrystalPainter(),
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AssetButton(
                      asset: 'assets/asset-sheet_slices/istatistik.jpg',
                      onTap: openReport,
                      semanticsLabel: 'Rapor',
                      size: 34,
                    ),
                    const SizedBox(width: 8),
                    _AssetButton(
                      asset: 'assets/asset-sheet_slices/settings.jpg',
                      onTap: openSettings,
                      semanticsLabel: 'Ayarlar',
                      size: 34,
                    ),
                  ],
                ),
              ),
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'app-hero',
                          child: Image.asset(
                            currentAsset,
                            width: 220,
                            height: 220,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Blink label OR normal status text
                        if (label != null)
                          AnimatedOpacity(
                            opacity: _blinkVisible ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 100),
                            child: Text(
                              label,
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          Text(
                            statusText,
                            style: const TextStyle(
                                fontSize: 24, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC0CB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFFF69B4), width: 4),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFFFF69B4),
                                offset: Offset(4, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Image.asset('assets/asset-sheet_slices/saat.jpg',
                                  width: 30, height: 30),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    timerText,
                                    style: const TextStyle(
                                        fontSize: 42,
                                        color: Colors.white,
                                        letterSpacing: 3),
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
                              flex: 2,
                              child: _PixelButton(
                                text: isRunning ? 'DURDUR' : 'BAŞLA',
                                onPressed: isRunning ? stopTimer : startTimer,
                                color: const Color(0xFFFF69B4),
                                asset:
                                    'assets/asset-sheet_slices/pomodoro-start.jpg',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PixelButton(
                                text: null,
                                semanticsLabel: 'Atla',
                                onPressed: skipPhase,
                                color: const Color(0xFFB98AD9),
                                asset: 'assets/asset-sheet_slices/atla.jpg',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PixelButton(
                                text: null,
                                semanticsLabel: 'İleri sar',
                                onPressed: fastForward,
                                color: const Color(0xFF8EBCD1),
                                asset:
                                    'assets/asset-sheet_slices/ileri-sar.jpg',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _PixelButton(
                                text: 'SIFIRLA',
                                onPressed: resetTimer,
                                color: const Color(0xFFFF6B6B),
                                asset:
                                    'assets/asset-sheet_slices/pomodoro-end.jpg',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PixelButton(
                                text: 'MOLA TEST',
                                onPressed: () {
                                  stopTimer();
                                  setState(() {
                                    currentState = 'onBreak';
                                    timeLeft = configuredBreakMinutes * 60;
                                  });
                                },
                                color: const Color(0xFF87CEEB),
                                asset: 'assets/asset-sheet_slices/mola.jpg',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusSession {
  final DateTime completedAt;
  final int durationMinutes;

  const _FocusSession({
    required this.completedAt,
    required this.durationMinutes,
  });

  factory _FocusSession.fromJson(dynamic json) {
    final data = json as Map<String, dynamic>;
    final durationSeconds = data['durationSeconds'];
    return _FocusSession(
      completedAt: DateTime.parse(data['completedAt'] as String),
      durationMinutes: durationSeconds is int
          ? durationSeconds ~/ 60
          : data['durationMinutes'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'completedAt': completedAt.toIso8601String(),
        'durationSeconds': durationMinutes * 60,
      };
}

class _ReportDialog extends StatelessWidget {
  final List<_FocusSession> sessions;

  const _ReportDialog({required this.sessions});

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  int _streak() {
    final days =
        sessions.map((session) => _dateKey(session.completedAt)).toSet();
    var day = DateTime.now();
    var count = 0;
    while (days.contains(_dateKey(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = sessions.fold<int>(
        0, (total, session) => total + session.durationMinutes);
    final days =
        sessions.map((session) => _dateKey(session.completedAt)).toSet();
    final sortedSessions = [...sessions]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    return DefaultTabController(
      length: 2,
      child: AlertDialog(
        backgroundColor: const Color(0xFFFFE6EA),
        titlePadding: const EdgeInsets.fromLTRB(18, 12, 10, 0),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('RAPOR', style: TextStyle(fontSize: 16)),
            _AssetButton(
              asset: 'assets/asset-sheet_slices/ret.png',
              onTap: () => Navigator.pop(context),
              semanticsLabel: 'Kapat',
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 440,
          child: Column(
            children: [
              TabBar(
                labelColor: Color(0xFFE56B77),
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(
                      icon: Image.asset(
                          'assets/asset-sheet_slices/istatistik.jpg',
                          width: 30,
                          height: 30),
                      text: 'Özet'),
                  Tab(
                      icon: Image.asset('assets/asset-sheet_slices/list.jpg',
                          width: 30, height: 30),
                      text: 'Detay'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _SummaryView(
                      totalMinutes: totalMinutes,
                      dayCount: days.length,
                      streak: _streak(),
                    ),
                    _DetailView(sessions: sortedSessions),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryView extends StatelessWidget {
  final int totalMinutes;
  final int dayCount;
  final int streak;

  const _SummaryView({
    required this.totalMinutes,
    required this.dayCount,
    required this.streak,
  });

  String _formatDuration(int totalMinutes) {
    final totalSeconds = totalMinutes * 60;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aktivite Özeti', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          const Text('Tamamlanan odak oturumların burada görünür.',
              style: TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 18),
          Row(
            children: [
              _ReportStat(
                  icon: 'saat.jpg',
                  value: _formatDuration(totalMinutes),
                  label: 'odak süresi'),
              _ReportStat(
                  icon: 'tarih.jpg',
                  value: '$dayCount',
                  label: 'gün çalışıldı'),
              _ReportStat(
                  icon: 'seri.jpg', value: '$streak', label: 'günlük seri'),
            ],
          ),
          const SizedBox(height: 28),
          const Text('Odak Saatleri', style: TextStyle(fontSize: 13)),
          const Divider(height: 24),
          Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE7E7E7)),
            ),
            child: Center(
              child: Text(
                totalMinutes == 0
                    ? 'Henüz tamamlanan oturum yok'
                    : 'Toplam ${_formatDuration(totalMinutes)} odaklandın',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _ReportStat(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        color: const Color(0xFFFFE9EB),
        child: Column(
          children: [
            Image.asset('assets/asset-sheet_slices/$icon',
                width: 25, height: 25),
            const SizedBox(height: 5),
            Text(value,
                style: const TextStyle(fontSize: 14, color: Color(0xFFE56B77))),
            Text(label,
                style: const TextStyle(fontSize: 8, color: Color(0xFFE56B77))),
          ],
        ),
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  final List<_FocusSession> sessions;

  const _DetailView({required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const Center(
        child:
            Text('Henüz tamamlanan oturum yok', style: TextStyle(fontSize: 10)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 16),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final date =
            '${session.completedAt.day.toString().padLeft(2, '0')}.${session.completedAt.month.toString().padLeft(2, '0')}.${session.completedAt.year}';
        final time =
            '${session.completedAt.hour.toString().padLeft(2, '0')}:${session.completedAt.minute.toString().padLeft(2, '0')}';
        return ListTile(
          dense: true,
          leading: Image.asset('assets/asset-sheet_slices/list.jpg',
              width: 25, height: 25),
          title: Text(date, style: const TextStyle(fontSize: 10)),
          subtitle: Text(time,
              style: const TextStyle(fontSize: 8, color: Colors.grey)),
          trailing: Text('${session.durationMinutes} dk',
              style: const TextStyle(fontSize: 10)),
        );
      },
    );
  }
}

class _PixelButton extends StatelessWidget {
  final String? text;
  final VoidCallback onPressed;
  final Color color;
  final String? asset;
  final String? semanticsLabel;

  const _PixelButton({
    required this.text,
    required this.onPressed,
    required this.color,
    this.asset,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? text ?? 'Buton',
      button: true,
      child: GestureDetector(
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
              if (asset != null && text != null) const SizedBox(width: 6),
              if (text != null)
                Flexible(
                  child: Text(
                    text!,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetButton extends StatelessWidget {
  final String asset;
  final VoidCallback onTap;
  final String? label;
  final String? semanticsLabel;
  final double size;

  const _AssetButton({
    required this.asset,
    required this.onTap,
    this.label,
    this.semanticsLabel,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel ?? label ?? 'Buton',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(asset, width: size, height: size, fit: BoxFit.contain),
            if (label != null)
              Text(label!, style: const TextStyle(fontSize: 10)),
          ],
        ),
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
