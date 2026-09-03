// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pomodoro_app/main.dart';

void main() {
  testWidgets('Pomodoro screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PixelPomodoroApp());
    expect(find.text('BAŞLAMAYA HAZIR'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.bySemanticsLabel('Atla'), findsOneWidget);
    expect(find.bySemanticsLabel('İleri sar'), findsOneWidget);
    expect(find.bySemanticsLabel('Rapor'), findsOneWidget);
    expect(find.bySemanticsLabel('Ayarlar'), findsOneWidget);
    expect(find.text('ATLA'), findsNothing);
    expect(find.text('İLERİ SAR'), findsNothing);
    expect(find.text('AYARLAR'), findsNothing);
    expect(find.text('SIFIRLA'), findsOneWidget);
  });

  testWidgets('Report opens with summary and detail tabs',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PixelPomodoroApp());
    await tester.ensureVisible(find.bySemanticsLabel('Rapor'));
    await tester.tap(find.bySemanticsLabel('Rapor'));
    await tester.pumpAndSettle();

    expect(find.text('RAPOR'), findsOneWidget);
    expect(find.text('Özet'), findsOneWidget);
    expect(find.text('Detay'), findsOneWidget);
  });

  testWidgets('Report recovers completed sets from local storage',
      (WidgetTester tester) async {
    final today = DateTime.now().toIso8601String();
    SharedPreferences.setMockInitialValues({
      'activity_dates': [today],
      'completed_sets': [today, today],
      'focus_sessions': <String>[],
    });

    await tester.pumpWidget(const PixelPomodoroApp());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Rapor'));
    await tester.pumpAndSettle();

    expect(find.text('00:50:00'), findsOneWidget);
    expect(find.text('Bugünün setleri: #1 #2'), findsOneWidget);
  });

  testWidgets('Skipping work and break records a session and set',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PixelPomodoroApp());

    await tester.tap(find.text('BAŞLA'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Atla'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Atla'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Rapor'));
    await tester.pumpAndSettle();

    expect(find.text('00:25:00'), findsOneWidget);
    expect(find.text('Bugünün setleri: #1'), findsOneWidget);
    await tester.tap(find.text('Detay'));
    await tester.pumpAndSettle();
    expect(find.text('00:25:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('Report keeps an unfinished session duration',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'active_work_seconds': 458});
    await tester.pumpWidget(const PixelPomodoroApp());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Rapor'));
    await tester.pumpAndSettle();

    expect(find.text('00:07:38'), findsOneWidget);
    await tester.tap(find.text('Detay'));
    await tester.pumpAndSettle();
    expect(find.text('00:07:38'), findsOneWidget);
  });
}
