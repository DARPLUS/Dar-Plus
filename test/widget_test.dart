import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dar_plus/main.dart';
import 'package:dar_plus/screens/login_screen.dart';
import 'package:dar_plus/screens/pro_home_screen.dart';

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
    expect(find.text('Ahmed 👋'), findsOneWidget);
    expect(find.text('Catégories'), findsOneWidget);
  });

  testWidgets('Clean Login Screen without role buttons and with forgot password',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: LoginScreen(),
    ));

    // Verify header and title
    expect(find.text('Connexion'), findsWidgets);
    expect(find.text('Vos services à domicile'), findsOneWidget);

    // Verify role buttons are removed from login
    expect(find.byType(Radio), findsNothing);

    // Verify fields and actions
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Mot de passe oublié?'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Facebook'), findsOneWidget);
    expect(find.text('S\'inscrire'), findsOneWidget);
  });

  testWidgets('Pro Dashboard matches mockups (Stats, Requests, Interventions, Performance)',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProHomeScreen(proName: 'Mohamed'),
    ));
    await tester.pumpAndSettle();

    // 1. Top dark header
    expect(find.text('Bonjour,'), findsOneWidget);
    expect(find.text('Mohamed'), findsOneWidget);
    expect(find.text('Vous êtes disponible'), findsOneWidget);
    expect(find.text('1690 TND'), findsOneWidget);
    expect(find.text('Ce mois'), findsOneWidget);
    expect(find.text('3'), findsNWidgets(2));
    expect(find.text('Aujourd\'hui'), findsOneWidget);
    expect(find.text('4.9/5'), findsWidgets);

    // 2. Quick action cards
    expect(find.text('Demandes'), findsWidgets);
    expect(find.text('Dispo.'), findsOneWidget);
    expect(find.text('Messages'), findsWidgets);
    expect(find.text('Revenus'), findsWidgets);

    // 3. Notification banner
    expect(find.text('2 nouvelles demandes!'), findsOneWidget);

    // 4. Interventions
    expect(find.text('Interventions d\'aujourd\'hui'), findsOneWidget);
    expect(find.text('Ahmed Ben Salah'), findsOneWidget);
    expect(find.text('Sonia Mansouri'), findsOneWidget);
    expect(find.text('Karim Belhaj'), findsOneWidget);
    expect(find.text('Confirmé'), findsOneWidget);
    expect(find.text('En route'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);

    // 5. Performance cette semaine
    expect(find.text('Performance cette semaine'), findsOneWidget);
    expect(find.text('Taux d\'acceptation'), findsOneWidget);
    expect(find.text('94%'), findsOneWidget);
    expect(find.text('Ponctualité'), findsOneWidget);
    expect(find.text('98%'), findsOneWidget);

    // 6. Bottom Navigation
    expect(find.text('Tableau'), findsOneWidget);
    expect(find.text('Compte'), findsOneWidget);
  });
}
