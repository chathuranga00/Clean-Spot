import 'package:cleanspot/src/app.dart';
import 'package:cleanspot/src/core/widgets/app_empty_state.dart';
import 'package:cleanspot/src/core/widgets/app_error_state.dart';
import 'package:cleanspot/src/core/widgets/app_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CleanSpotApp initial route renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CleanSpotApp(),
      ),
    );

    // Initial frame
    await tester.pumpAndSettle();

    // Verify CleanSpot branding on splash screen
    expect(find.text('CleanSpot'), findsOneWidget);
    expect(find.text('Dengue Breeding Site Reporter'), findsOneWidget);
    expect(find.text('Enter App'), findsOneWidget);
  });

  testWidgets('AppLoadingIndicator renders message and indicator', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLoadingIndicator(message: 'Loading hazards...'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading hazards...'), findsOneWidget);
  });

  testWidgets('AppEmptyState renders title, message and action', (WidgetTester tester) async {
    bool actionClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            title: 'No Reports Found',
            message: 'Your neighborhood looks clean!',
            actionLabel: 'Report Spot',
            onAction: () {
              actionClicked = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('No Reports Found'), findsOneWidget);
    expect(find.text('Your neighborhood looks clean!'), findsOneWidget);
    expect(find.text('Report Spot'), findsOneWidget);

    await tester.tap(find.text('Report Spot'));
    await tester.pump();

    expect(actionClicked, isTrue);
  });

  testWidgets('AppErrorState renders error details and retry button', (WidgetTester tester) async {
    bool retryClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppErrorState(
            title: 'Connection Error',
            message: 'Failed to fetch reports',
            onRetry: () {
              retryClicked = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Connection Error'), findsOneWidget);
    expect(find.text('Failed to fetch reports'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retryClicked, isTrue);
  });
}
