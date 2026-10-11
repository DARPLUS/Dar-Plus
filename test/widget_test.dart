import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dar_plus/main.dart';
import 'package:dar_plus/screens/login_screen.dart';

void main() {
  testWidgets('Full flow: Splash -> Onboarding -> Home',
      (WidgetTester tester) async {
    await tester.pumpWidget(const DarPlusApp());

    // 1. Splash Screen
    expect(find.text('DAR PLUS'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    // 2. Onboarding
    expect(find.text('Des pros à votre service'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);

    // Tap Passer -> Home Screen
    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();
    expect(find.text('Bienvenue sur DAR PLUS'), findsOneWidget);
  });

  testWidgets('Unified Login Screen renders Client, Pro, and Admin options',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: LoginScreen(),
    ));

    // Verify header and title
    expect(find.text('Connexion'), findsWidgets);
    expect(find.text('Vos services à domicile'), findsOneWidget);

    // Verify role toggles
    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Professionnel'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);

    // Verify fields and social buttons
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Mot de passe oublié?'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('S\'inscrire'), findsOneWidget);
  });
}
