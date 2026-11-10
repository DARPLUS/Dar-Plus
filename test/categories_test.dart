import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dar_plus/services/firebase_service.dart';
import 'package:dar_plus/screens/admin_requests_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Categories Service & CRUD tests', () {
    test('Categories stream yields default categories and handles mutations', () async {
      final service = FirebaseService();
      final stream = service.streamCategories();
      final initialCategories = await stream.first;

      // 1. Initial categories validation
      expect(initialCategories.isNotEmpty, isTrue);
      expect(initialCategories.any((c) => c['name'] == 'Plomberie'), isTrue);
      expect(initialCategories.any((c) => c['name'] == 'Électricité'), isTrue);

      final initialCount = initialCategories.length;

      // 2. Add a new category
      final addSuccess = await service.addCategory(
        name: 'Menuiserie Test',
        pros: 15,
        isActive: true,
      );
      expect(addSuccess, isTrue);

      final updatedAfterAdd = await service.streamCategories().first;
      expect(updatedAfterAdd.length, equals(initialCount + 1));
      final addedCat = updatedAfterAdd.firstWhere((c) => c['name'] == 'Menuiserie Test');
      expect(addedCat['pros'], equals(15));
      expect(addedCat['isActive'], isTrue);

      // 3. Update category name and pros
      final updateSuccess = await service.updateCategory(
        addedCat['id'] as String,
        name: 'Menuiserie Bois',
        pros: 20,
      );
      expect(updateSuccess, isTrue);

      final updatedAfterEdit = await service.streamCategories().first;
      final editedCat = updatedAfterEdit.firstWhere((c) => c['id'] == addedCat['id']);
      expect(editedCat['name'], equals('Menuiserie Bois'));
      expect(editedCat['pros'], equals(20));

      // 4. Toggle category status (deactivate)
      final toggleSuccess = await service.toggleCategoryStatus(addedCat['id'] as String, false);
      expect(toggleSuccess, isTrue);

      final updatedAfterToggle = await service.streamCategories().first;
      final toggledCat = updatedAfterToggle.firstWhere((c) => c['id'] == addedCat['id']);
      expect(toggledCat['isActive'], isFalse);

      // 5. Delete category
      final deleteSuccess = await service.deleteCategory(addedCat['id'] as String);
      expect(deleteSuccess, isTrue);

      final finalCategories = await service.streamCategories().first;
      expect(finalCategories.any((c) => c['id'] == addedCat['id']), isFalse);
    });
  });

  group('Admin Categories UI Widget tests', () {
    testWidgets('Admin screen displays Categories tab with add, edit, and switch controls', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(
        home: AdminRequestsScreen(
          adminName: 'Super Admin',
          adminEmail: 'admin@darplus.tn',
          adminRole: 'super_admin',
        ),
      ));

      await tester.pumpAndSettle();

      // 1. Navigate to Categories tab (Item 3 in bottom nav)
      expect(find.text('Catégories'), findsWidgets);
      await tester.tap(find.byIcon(Icons.category_outlined));
      await tester.pumpAndSettle();

      // 2. Header and counter checks
      expect(find.text('Catégories'), findsWidgets);
      expect(find.textContaining('catégories'), findsWidgets);

      // 3. Category cards rendering
      expect(find.text('Plomberie'), findsOneWidget);
      expect(find.text('Électricité'), findsOneWidget);

      // 4. Floating action button "+ Nouvelle catégorie"
      expect(find.text('Nouvelle catégorie'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsWidgets);

      // 5. Tap "+ Nouvelle catégorie" opens dialog
      await tester.tap(find.text('Nouvelle catégorie'));
      await tester.pumpAndSettle();

      expect(find.text('Nom de la catégorie (ex: Menuiserie)'), findsOneWidget);
      expect(find.text('Nombre initial de professionnels'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Ajouter'), findsOneWidget);

      // Close the dialog
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
    });
  });
}
