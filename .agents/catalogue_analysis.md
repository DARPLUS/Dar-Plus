# Analyse Catalogue Dar-Plus — Rapport Complet

## Section 1 — État actuel

### Ce qui EXISTE déjà (fonctionnel)

**Écrans existants :**
- `lib/screens/catalog_search_screen.dart` ✅ EXISTE & COMPLET
  - Barre de recherche avec filtrage temps réel
  - Filtres par catégorie (pills horizontaux : Tous, Plomberie, Électricité, Climatisation, Peinture, Menuiserie, Nettoyage, Jardinage)
  - Tri par note / prix asc / prix desc
  - Switch "Disponible uniquement"
  - Liste de pros avec cartes (avatar Hero, note, prix, disponibilité)
  - Navigation vers ServiceDetailScreen
  - Support thème clair/sombre complet

- `lib/screens/service_detail_screen.dart` ✅ EXISTE & COMPLET
  - SliverAppBar avec Hero image animée
  - Fiche pro : rating, prix, nombre d'avis, localisation, badges
  - Biographie et spécialités
  - Avis clients (hardcodés)
  - Bouton Appeler + bottom sheet Réservation
  - Bottom sheet réservation avec formulaire (adresse, description, date)
  - Appel réel à `FirebaseService().createBooking()`

- `lib/screens/home_screen.dart` ✅ EXISTE & COMPLET
  - Grille catégories 4 colonnes (9 tuiles)
  - Liste horizontale "Top Professionnels" via `streamPros(sortBy: 'rating')`
  - Barre de recherche renvoyant vers CatalogSearchScreen
  - Navigation vers CatalogSearchScreen depuis les catégories

**Services Firestore existants :**
- `FirebaseService().streamPros({category, searchQuery, onlyAvailable, sortBy})` ✅
  - Filtre Firestore sur `role == 'pro'` et `isActive == true`
  - Fallback local avec 5 pros de démo
  - Tri côté client : rating, price_asc, price_desc

- `FirebaseService().streamCategories()` ✅
  - Stream Firestore collection `categories`
  - Comptage réel des pros par serviceType
  - Auto-seed 8 catégories si collection vide

- `FirebaseService().createBooking(...)` ✅
  - Crée un document dans collection `bookings`
  - Récupère les infos client depuis Firestore

- `FirebaseService().streamClientBookings({statusFilter})` ✅

**Modèles de données :**
- `ProApplication` : modèle complet dans firebase_service.dart
- Pros : représentés comme `Map<String, dynamic>` (pas de classe dédiée)
- Catégories : `Map<String, dynamic>` avec id, name, pros (count), isActive, icon, bgColor, iconColor

**Routing :**
- `AppRoutes.catalog = '/catalog'` ✅ enregistré
- `AppRoutes.serviceDetail = '/service-detail'` ✅ enregistré
- Navigation par `Navigator.push` avec `MaterialPageRoute`

### Ce qui MANQUE ou est INCOMPLET

1. **Pagination Firestore** — `streamPros()` charge TOUS les pros en mémoire. Pour une grande base (>100 pros), il faut ajouter `limit()` + `startAfterDocument()` pour une pagination.

2. **Photos pros réelles** — `avatarAsset` pointe sur un asset local (`slide_1_photo.png`). Les pros Firestore n'ont pas de `photoUrl` exploité. Pas de `cached_network_image` pour les URLs réseau.

3. **Avis clients dynamiques** — Les reviews dans `service_detail_screen.dart` sont hardcodées (Inès Ben Amor, Tarek Chaabane). Pas de collection `reviews` dans Firestore.

4. **Filtre de prix par plage** — Le filtre bottom sheet n'a que tri prix asc/desc. Pas de slider de plage prix (ex: 20–80 TND).

5. **Écran liste catégories enrichi** — La grille catégories de `home_screen.dart` affiche les catégories de Firestore mais le compteur de pros sur chaque tuile n'est pas visible (les données `pros` existent dans Firestore mais ne sont pas affichées sur les tuiles de la grille).

6. **Profil pro dédié** — ServiceDetailScreen reçoit un `Map<String, dynamic>` ; si un client navigue depuis une URL externe (deep link), il n'y a pas de chargement de profil par ID.

7. **Favoris** — `home_screen.dart` a un placeholder `_buildFavoritesScreenPlaceholder()`. Pas d'écran favoris implémenté.

8. **Distance réelle** — Le champ `distance` est hardcodé ou issu de Firestore (données seedées statiquement). Pas de géolocalisation réelle.

---

## Section 2 — Architecture recommandée

### Fichiers à CRÉER

```
lib/
  models/
    pro_model.dart              # Classe Pro avec fromMap() et toMap()
    review_model.dart           # Classe Review avec fromMap()
    booking_model.dart          # Classe Booking avec fromMap()
  widgets/
    pro_card_widget.dart        # Carte pro réutilisable (extraite de catalog_search_screen)
    category_tile_widget.dart   # Tuile catégorie réutilisable (extraite de home_screen)
    rating_stars_widget.dart    # Étoiles de notation réutilisables
    review_card_widget.dart     # Carte avis client réutilisable
    filter_bottom_sheet.dart    # Bottom sheet filtres (extraite de catalog_search_screen)
  screens/
    pro_profile_screen.dart     # Écran profil pro avec chargement par ID (variante de ServiceDetailScreen)
    reviews_screen.dart         # Écran liste complète des avis d'un pro
    favorites_screen.dart       # Écran favoris client
  services/
    catalog_service.dart        # Service dédié catalogue (pagination, favoris, avis)
```

### Fichiers à MODIFIER

| Fichier | Modifications requises |
|---------|------------------------|
| `lib/services/firebase_service.dart` | Ajouter pagination dans `streamPros()` avec curseur Firestore ; corriger `role == 'professionnel'` (actuellement query sur `'pro'` mais inscription crée `'professionnel'`) ; ajouter `streamReviews(proId)` |
| `lib/screens/catalog_search_screen.dart` | Ajouter pagination scroll ; charger catégories depuis Firestore au lieu de la liste statique `_categories` ; afficher compteur de pros sur les pills |
| `lib/screens/service_detail_screen.dart` | Remplacer avis hardcodés par `StreamBuilder<List<Review>>` depuis Firestore ; ajouter chargement pro par ID |
| `lib/screens/home_screen.dart` | Afficher le compteur `pros` sur les tuiles catégories |
| `pubspec.yaml` | Ajouter `cached_network_image: ^3.3.1` pour les photos réseau |

### IMPORTANT — Bug de rôle à corriger

Dans `firebase_service.dart`, `streamPros()` utilise :
```dart
.where('role', isEqualTo: 'pro')
```
Mais `submitProApplication()` enregistre le rôle comme `'professionnel'`. Les pros approuvés ne seront donc PAS retournés par `streamPros()` en production Firestore.

**Correction nécessaire :**
```dart
// Requête Firestore avec les DEUX valeurs de rôle :
.where('role', whereIn: ['pro', 'professionnel'])
.where('isApproved', isEqualTo: true)
```

---

## Section 3 — Collections Firestore

### Collections existantes

**Collection `users`**
```json
{
  "uid": "string",
  "fullName": "string",
  "email": "string",
  "phone": "string",
  "role": "client | admin | super_admin | professionnel | pro",
  "isApproved": "boolean",
  "isActive": "boolean",
  "status": "en_attente | valide | refuse",
  "serviceType": "string (pros uniquement)",
  "createdAt": "Timestamp",
  "photoBase64": "string (optionnel)",
  "photoUrl": "string (optionnel)",
  "mustChangePassword": "boolean",
  "tempPassword": "string",
  "rating": "number (pros uniquement, si renseigné)",
  "reviewsCount": "number (pros uniquement)",
  "price": "string (ex: 35 TND/h)",
  "priceValue": "number",
  "location": "string",
  "distance": "string",
  "available": "boolean",
  "bio": "string",
  "specialties": "List<string>"
}
```

**Collection `categories`**
```json
{
  "id": "string (ex: cat_1)",
  "name": "string (ex: Plomberie)",
  "pros": "number (compteur de pros)",
  "isActive": "boolean",
  "iconCode": "int (codePoint Flutter IconData)",
  "bgColorHex": "int (ex: 0xFFE8F0FE)",
  "iconColorHex": "int",
  "createdAt": "Timestamp"
}
```

**Collection `pro_applications`**
```json
{
  "id": "string",
  "fullName": "string",
  "phone": "string",
  "email": "string",
  "cin": "string (optionnel)",
  "serviceType": "string",
  "status": "en_attente | valide | refuse",
  "createdAt": "Timestamp",
  "notes": "string",
  "rejectionReason": "string",
  "role": "professionnel"
}
```

**Collection `bookings`**
```json
{
  "clientId": "string",
  "clientName": "string",
  "clientEmail": "string",
  "clientPhone": "string",
  "proId": "string",
  "proName": "string",
  "proPhone": "string",
  "serviceType": "string",
  "price": "string",
  "address": "string",
  "description": "string",
  "scheduledDate": "string",
  "status": "en_attente | confirmee | terminee | annulee",
  "createdAt": "Timestamp"
}
```

**Collection `security_logs`** — journaux admin

**Collection `settings/global`** — paramètres plateforme

### Collections à CRÉER

**Collection `reviews`**
```json
{
  "id": "string (auto-généré)",
  "proId": "string (ref vers users)",
  "clientId": "string",
  "clientName": "string",
  "rating": "number (1.0 - 5.0)",
  "comment": "string",
  "serviceType": "string",
  "createdAt": "Timestamp",
  "bookingId": "string (optionnel, ref vers bookings)"
}
```

**Collection `favorites`** (ou sous-collection `users/{uid}/favorites`)
```json
{
  "proId": "string",
  "proName": "string",
  "serviceType": "string",
  "addedAt": "Timestamp"
}
```

### Requêtes Firestore à implémenter

```dart
// 1. Liste pros avec pagination
FirebaseFirestore.instance
  .collection('users')
  .where('role', whereIn: ['pro', 'professionnel'])
  .where('isApproved', isEqualTo: true)
  .where('isActive', isEqualTo: true)
  .orderBy('rating', descending: true)
  .limit(20)
  .startAfterDocument(lastDoc) // pagination

// 2. Filtre par catégorie
  .where('serviceType', isEqualTo: category)

// 3. Stream avis d'un pro
FirebaseFirestore.instance
  .collection('reviews')
  .where('proId', isEqualTo: proId)
  .orderBy('createdAt', descending: true)
  .limit(10)

// 4. Favoris d'un client
FirebaseFirestore.instance
  .collection('users').doc(clientId)
  .collection('favorites')
  .orderBy('addedAt', descending: true)
```

---

## Section 4 — Composants UI à créer

### 1. `ProCardWidget`
- Extrait de `_buildProCard()` dans catalog_search_screen.dart
- Props : `Map<String, dynamic> pro`, `VoidCallback onTap`
- Contenu : avatar avec Hero tag, nom, serviceType, rating, prix, disponibilité, localisation
- Réutilisable dans : CatalogSearchScreen, HomeScreen, FavoritesScreen

### 2. `CategoryTileWidget`
- Extrait de la grille de home_screen.dart
- Props : `String name`, `IconData icon`, `Color bgColor`, `Color iconColor`, `int proCount`, `VoidCallback onTap`
- Affiche le compteur de pros si `proCount > 0`
- Réutilisable dans : HomeScreen, CatalogSearchScreen (header)

### 3. `RatingStarsWidget`
- Props : `double rating`, `int maxStars = 5`, `double size = 16`
- Affiche des étoiles plein/demi/vide selon la note

### 4. `ReviewCardWidget`
- Extrait de `_buildReviewCard()` dans service_detail_screen.dart
- Props : `String author`, `String date`, `double rating`, `String comment`, `bool isDark`

### 5. `FilterBottomSheet`
- Extrait de `_showFilterDialog()` dans catalog_search_screen.dart
- Props callback : `onSortChanged(String sort)`, `onAvailableChanged(bool val)`, `onPriceRangeChanged(RangeValues range)`
- Ajouter slider de plage prix

### Navigation entre les écrans

```
HomeScreen
  ├── Tap catégorie → CatalogSearchScreen(initialCategory: name)
  ├── Tap recherche → CatalogSearchScreen(initialSearch: query)
  ├── Tap "Voir tout" → CatalogSearchScreen()
  └── Tap pro → ServiceDetailScreen(proData: pro)

CatalogSearchScreen
  └── Tap carte pro → ServiceDetailScreen(proData: pro)

ServiceDetailScreen
  ├── Tap "Réserver" → BottomSheet réservation (déjà implémenté)
  ├── Tap "Voir tous les avis" → ReviewsScreen(proId: id)
  └── Tap Retour → Pop
```

---

## Section 5 — Couleurs et thème à utiliser

### Couleurs primaires brand
```dart
// Teal principal (boutons, actif, AppBar header)
const Color tealPrimary = Color(0xFF0D544E);

// Orange (prix, call-to-action secondaire, badges)
const Color orangePrimary = Color(0xFFDE6D1B);

// Fond light
const Color background = Color(0xFFFAF7F4);

// Vert disponibilité
const Color available = Color(0xFF10B981);

// Étoiles de notation
const Color starColor = Color(0xFFF39C12);
```

### Comment accéder au thème dans les nouveaux écrans
```dart
// Pattern établi dans le projet — à reproduire exactement :
final isDark = Theme.of(context).brightness == Brightness.dark;
final titleColor = isDark ? Colors.white : AppTheme.titleColor;
final subColor = isDark ? const Color(0xFF94A3B8) : AppTheme.subtitleColor;
final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
final borderColor = isDark ? Colors.transparent : const Color(0xFFEDE8E1);

// OU via les helpers de AppTheme :
final titleColor = AppTheme.titleColorOf(context);
final cardColor = AppTheme.cardColorOf(context);

// OU via les extensions de contexte :
context.themeCardBg
context.themeTextPrimary
context.themeTextSecondary
context.themeBorder
```

### Thème dark — couleurs spécifiques
```dart
static const Color darkBackground = Color(0xFF0F172A); // Slate 900
static const Color darkSurface = Color(0xFF1E293B);    // Slate 800
static const Color darkCard = Color(0xFF1E293B);       // Slate 800
static const Color darkTitle = Color(0xFFF8FAFC);      // Slate 50
static const Color darkSubtitle = Color(0xFF94A3B8);   // Slate 400
static const Color darkDivider = Color(0xFF334155);    // Slate 700
```

---

## Section 6 — Risques et points d'attention

### 🔴 CRITIQUE — Bug de rôle pro
`streamPros()` filtre `role == 'pro'` mais les pros créés via `submitProApplication()` ont `role == 'professionnel'`. En production, aucun pro approuvé ne serait visible dans le catalogue.

**Correction dans `firebase_service.dart` :**
```dart
.where('role', whereIn: ['pro', 'professionnel'])
.where('isApproved', isEqualTo: true)
```

### 🟠 IMPORTANT — Photos pros réseau
Actuellement les cartes pros utilisent `Image.asset(avatarAsset)` qui ne peut afficher que des assets locaux. Les pros Firestore ont potentiellement un `photoUrl` ou `photoBase64`. Il faut :
1. Ajouter `cached_network_image: ^3.3.1` dans pubspec.yaml
2. Modifier les cartes pros pour utiliser `CachedNetworkImage` si `photoUrl != null`, sinon fallback asset

**Ajout pubspec.yaml :**
```yaml
dependencies:
  cached_network_image: ^3.3.1
```

### 🟠 IMPORTANT — Avis clients hardcodés
Les 2 avis dans ServiceDetailScreen (`Inès Ben Amor`, `Tarek Chaabane`) sont hardcodés. Pour la production, créer la collection `reviews` et un `StreamBuilder`.

### 🟡 ATTENTION — Pagination absente
`streamPros()` charge tous les pros d'un coup. À grande échelle (>50 pros), implémenter la pagination avec `limit(20)` + `startAfterDocument()`.

### 🟡 ATTENTION — Recherche textuelle Firestore limitée
Firestore ne supporte pas la recherche full-text native. La recherche actuelle est côté client (`list.where()`). Pour la production, envisager Algolia ou une recherche par préfixe avec `>= query` et `<= query + '\uf8ff'`.

### 🟡 ATTENTION — Compteur de pros sur les catégories
Le champ `pros` dans Firestore est mis à jour lors du `streamCategories()` mais pas en temps réel à chaque validation de pro. Un compteur dénormalisé doit être incrémenté lors de `approveProApplication()`.

### 🟢 OK — Thème dark/light
Les deux écrans (CatalogSearchScreen, ServiceDetailScreen) gèrent déjà parfaitement le thème sombre.

### 🟢 OK — Localisation
Les deux écrans utilisent `AppLocalizations.of(context).translate('key')` — compatibilité easy_localization confirmée. Les clés de traduction catalogue (`catalog_title`, `cat_all`, `no_pros_found`, etc.) sont déjà référencées.

### 🟢 OK — Architecture
Les nouveaux écrans doivent suivre le même pattern que les écrans existants :
- StatefulWidget avec `setState()`
- Provider pour thème et locale via `context.watch<ThemeProvider>()`
- FirebaseService() comme singleton pour Firestore
- Pas de BLoC ou Riverpod : uniquement Provider + setState

### Dépendances à ajouter
```yaml
cached_network_image: ^3.3.1  # Photos pros réseau
```
Aucune autre dépendance externe n'est nécessaire — le projet a déjà provider, firebase, image_picker, lottie, easy_localization, intl.
