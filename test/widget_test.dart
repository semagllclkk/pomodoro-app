// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:pomodoro_app/main.dart';

void main() {
  testWidgets('Pomodoro screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PixelPomodoroApp());
    expect(find.text('BAŞLAMAYA HAZIR'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('ATLA'), findsOneWidget);
    expect(find.text('İLERİ SAR'), findsOneWidget);
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
}
