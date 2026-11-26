import '../widgets/admin_dashboard_charts.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/email_service.dart';
import '../services/commission_service.dart';
import '../models/payment_model.dart';
import '../core/routing/app_routes.dart';
import 'login_screen.dart';

class AdminRequestsScreen extends StatefulWidget {
  final String? highlightAppId;
  final String adminName;
  final String? adminEmail;
  final String? adminPhone;
  final String adminRole;
  final bool mustChangePassword;
  const AdminRequestsScreen({
    super.key,
    this.highlightAppId,
    this.adminName = 'Administrateur',
    this.adminEmail,
    this.adminPhone,
    this.adminRole = 'admin',
    this.mustChangePassword = false,
  });
  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  // 0: Tableau, 1: Utilisateurs, 2: Validations, 3: Catégories, 4: Profil, 5: Supervision
  int _currentBottomNavIndex =
      0; // Redirige directement vers le Tableau de bord (Dashboard)
  int _supervisionSubTab = 0; // 0: Signalements, 1: Rapports, 2: Journaux
  int _selectedValidationTab = 0; // 0: À valider, 1: Validés, 2: Rejetés
  String _dashboardRange = '7 derniers jours';
  String _reportRange = '30 derniers jours';
  int _settingsTabIndex = 0;
  late final TextEditingController _settingsNameController;
  late final TextEditingController _settingsEmailController;
  late final TextEditingController _settingsPhoneController;
  final TextEditingController _settingsCurrentPasswordController =
      TextEditingController();
  final TextEditingController _settingsNewPasswordController =
      TextEditingController();
  final TextEditingController _settingsConfirmPasswordController =
      TextEditingController();
  bool _settingsSaving = false;
  String _settingsLanguage = 'fr';
  ThemeMode _settingsThemeMode = ThemeMode.system;
  // User management tab filters
  String _userRoleFilter = 'tous';
  final TextEditingController _userSearchController = TextEditingController();
  late String _currentAdminName;
  late String _currentAdminRole;
  String _currentAdminEmail = 'admin@darplus.tn';
  String _currentAdminPhone = '+216 71 000 000';
  String? _adminPhotoBase64;
  bool _forceDialogShown = false;
  bool _adminCanManageCategories = false;
  StreamSubscription<List<Map<String, dynamic>>>? _categoriesSub;
  StreamSubscription<Map<String, dynamic>>? _globalSettingsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _reportsSubscription;
  final Set<String> _knownReportIds = {};
  bool _reportsInitialized = false;
  int _openReportCount = 0;
  String _reportSearch = '';
  String _reportStatusFilter = 'Tous les statuts';
  String _promoSearch = '';
  String _promoStatusFilter = 'Tous les statuts';
  String _categorySearch = '';

  bool get isSuperAdmin =>
      _currentAdminRole.toLowerCase() == 'super_admin' ||
      _currentAdminEmail.trim().toLowerCase() == 'admin@darplus.tn' ||
      widget.adminEmail?.trim().toLowerCase() == 'admin@darplus.tn' ||
      widget.adminRole.toLowerCase() == 'super_admin';

  bool get canManageCategories => isSuperAdmin || _adminCanManageCategories;

  // Client and Pro table state variables
  String _clientSearchQuery = '';
  String _clientFilterStatus = 'tous';
  final TextEditingController _clientTableSearchController =
      TextEditingController();

  String _proSearchQuery = '';
  int _proCurrentPage = 1;
  String _proServiceFilter = 'Tous les métiers';
  bool _proNewestFirst = true;
  String _bookingSearch = '';
  String _bookingStatusFilter = 'Tous les statuts';
  String _bookingPeriodFilter = '30 derniers jours';
  String _paymentStatusFilter = 'Tous les statuts';
  String _paymentSearch = '';
  String _reviewSearch = '';
  String _reviewRatingFilter = 'Toutes les notes';
  final TextEditingController _proTableSearchController =
      TextEditingController();
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _borderColor =>
      _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  // Categories list (8 catégories · 7 actives)
  List<Map<String, dynamic>> _dashboardUsers = const [];
  StreamSubscription<List<Map<String, dynamic>>>? _usersCountSub;

  final List<Map<String, dynamic>> _adminCategories = [
    {
      'id': 'cat_1',
      'name': 'Plomberie',
      'pros': 48,
      'isActive': true,
      'icon': Icons.build_rounded,
      'bgColor': const Color(0xFFE8F0FE),
      'iconColor': const Color(0xFF1E40AF),
    },
    {
      'id': 'cat_2',
      'name': 'Électricité',
      'pros': 41,
      'isActive': true,
      'icon': Icons.bolt_rounded,
      'bgColor': const Color(0xFFFEF3C7),
      'iconColor': const Color(0xFFD97706),
    },
    {
      'id': 'cat_3',
      'name': 'Nettoyage',
      'pros': 63,
      'isActive': true,
      'icon': Icons.auto_awesome_rounded,
      'bgColor': const Color(0xFFD7F3EA),
      'iconColor': const Color(0xFF0D544E),
    },
    {
      'id': 'cat_4',
      'name': 'Climatisation',
      'pros': 22,
      'isActive': true,
      'icon': Icons.ac_unit_rounded,
      'bgColor': const Color(0xFFE0EAFA),
      'iconColor': const Color(0xFF2563EB),
    },
    {
      'id': 'cat_5',
      'name': 'Peinture',
      'pros': 17,
      'isActive': true,
      'icon': Icons.format_paint_rounded,
      'bgColor': const Color(0xFFFCE7F3),
      'iconColor': const Color(0xFFBE185D),
    },
    {
      'id': 'cat_6',
      'name': 'Serrurerie',
      'pros': 12,
      'isActive': false,
      'icon': Icons.key_rounded,
      'bgColor': const Color(0xFFF1F5F9),
      'iconColor': const Color(0xFF64748B),
    },
    {
      'id': 'cat_7',
      'name': 'Bricolage',
      'pros': 35,
      'isActive': true,
      'icon': Icons.handyman_rounded,
      'bgColor': const Color(0xFFFEF3C7),
      'iconColor': const Color(0xFFB45309),
    },
    {
      'id': 'cat_8',
      'name': 'Jardinage',
      'pros': 19,
      'isActive': true,
      'icon': Icons.yard_rounded,
      'bgColor': const Color(0xFFDCFCE7),
      'iconColor': const Color(0xFF15803D),
    },
  ];
  @override
  void initState() {
    super.initState();
    _currentAdminName = widget.adminName;
    _settingsNameController = TextEditingController(text: widget.adminName);
    _settingsEmailController = TextEditingController(
      text: widget.adminEmail ?? _currentAdminEmail,
    );
    _settingsPhoneController = TextEditingController(
      text: widget.adminPhone ?? _currentAdminPhone,
    );
    _settingsLanguage =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _currentAdminRole = widget.adminRole;
    if (widget.adminEmail != null && widget.adminEmail!.isNotEmpty) {
      _currentAdminEmail = widget.adminEmail!;
    }
    if (widget.adminPhone != null && widget.adminPhone!.isNotEmpty) {
      _currentAdminPhone = widget.adminPhone!;
    }
    if (!kIsWeb) return;
    NotificationService().markAllAsRead();
    _reportsSubscription = FirebaseFirestore.instance
        .collection('reports')
        .snapshots()
        .listen(_handleReportSnapshot);
    _loadRealAdminProfile();
    _categoriesSub = FirebaseService().streamCategories().listen((list) {
      if (mounted && list.isNotEmpty) {
        setState(() {
          _adminCategories.clear();
          _adminCategories.addAll(list);
        });
      }
    });
    _usersCountSub = FirebaseService().streamUsers().listen((list) {
      if (mounted) {
        setState(() {
          _dashboardUsers = list;
        });
      }
    });
    _globalSettingsSub = FirebaseService().streamGlobalSettings().listen((
      settings,
    ) {
      if (mounted) {
        setState(() {
          _adminCanManageCategories =
              settings['adminCanManageCategories'] == true;
        });
      }
    });
    if (widget.mustChangePassword) {
      _forceDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showForceChangePasswordDialog();
      });
    }
  }

  Future<void> _loadRealAdminProfile() async {
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      await authUser?.reload();
      final data = await FirebaseService().getCurrentUserData();
      if (data != null && mounted) {
        final verifiedAuthEmail = FirebaseAuth.instance.currentUser?.email;
        if (verifiedAuthEmail != null &&
            verifiedAuthEmail.toLowerCase() !=
                (data['email'] ?? '').toString().toLowerCase()) {
          await FirebaseService().updateCurrentUserData(
            email: verifiedAuthEmail,
          );
          data['email'] = verifiedAuthEmail;
        }
        setState(() {
          if (data['fullName'] != null &&
              data['fullName'].toString().trim().isNotEmpty) {
            _currentAdminName = data['fullName'].toString().trim();
            _settingsNameController.text = _currentAdminName;
          }
          if (data['email'] != null &&
              data['email'].toString().trim().isNotEmpty) {
            _currentAdminEmail = data['email'].toString().trim();
            _settingsEmailController.text = _currentAdminEmail;
          }
          if (data['phone'] != null &&
              data['phone'].toString().trim().isNotEmpty) {
            _currentAdminPhone = data['phone'].toString().trim();
            _settingsPhoneController.text = _currentAdminPhone;
          }
          if (data['photoBase64'] != null &&
              data['photoBase64'].toString().trim().isNotEmpty) {
            _adminPhotoBase64 = data['photoBase64'].toString().trim();
          }
          if (data['role'] != null &&
              (data['role'] == 'super_admin' || data['role'] == 'admin')) {
            _currentAdminRole = data['role'].toString();
          }
        });
        if (data['mustChangePassword'] == true && !_forceDialogShown) {
          _forceDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showForceChangePasswordDialog();
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _globalSettingsSub?.cancel();
    _reportsSubscription?.cancel();
    _usersCountSub?.cancel();
    _userSearchController.dispose();
    _settingsNameController.dispose();
    _settingsEmailController.dispose();
    _settingsPhoneController.dispose();
    _settingsCurrentPasswordController.dispose();
    _settingsNewPasswordController.dispose();
    _settingsConfirmPasswordController.dispose();
    super.dispose();
  }

  void _handleReportSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) return;
    final newReports = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in snapshot.docs) {
      if (_reportsInitialized && !_knownReportIds.contains(doc.id)) {
        newReports.add(doc);
      }
      _knownReportIds.add(doc.id);
    }
    final openCount = snapshot.docs.where((doc) {
      final status = (doc.data()['status'] ?? 'Ouvert')
          .toString()
          .toLowerCase();
      return status != 'résolu' && status != 'resolved';
    }).length;
    setState(() {
      _openReportCount = openCount;
      _reportsInitialized = true;
    });
    if (newReports.isNotEmpty) {
      final report = newReports.first.data();
      final category = (report['category'] ?? 'Nouveau signalement').toString();
      final reporter = (report['reporterName'] ?? 'Un utilisateur').toString();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('$reporter a envoyé un signalement : $category'),
            action: SnackBarAction(label: 'Voir', onPressed: _openSignalements),
          ),
        );
    }
  }

  void _openSignalements() {
    if (!mounted) return;
    setState(() {
      _currentBottomNavIndex = 5;
      _supervisionSubTab = 0;
    });
  }

  Widget _buildReportNotificationButton({bool compact = false}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Signalements en attente',
          icon: Icon(Icons.flag_outlined, size: compact ? 20 : 22),
          color: _textPrimary,
          onPressed: _openSignalements,
        ),
        if (_openReportCount > 0)
          Positioned(
            right: compact ? 5 : 7,
            top: compact ? 4 : 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _openReportCount > 99 ? '99+' : '$_openReportCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showForceChangePasswordDialog() {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isChanging = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.lock_reset_rounded,
                  color: Color(0xFFD97706),
                  size: 28,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'admin_force_change_password_title'.tr(),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pour des raisons de securite, vous devez changer votre mot de passe temporaire avant de continuer.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'admin_new_password'.tr(),
                      prefixIcon: const Icon(Icons.lock_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.length < 6)
                        return 'Minimum 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'admin_confirm_password'.tr(),
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (val) {
                      if (val != newPassCtrl.text)
                        return 'Les mots de passe ne correspondent pas';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: isChanging
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isChanging = true);
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await user.updatePassword(newPassCtrl.text.trim());
                            await FirebaseService().updateUserField(
                              user.uid,
                              'mustChangePassword',
                              false,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Mot de passe mis a jour avec succes !',
                                ),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isChanging = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D544E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isChanging
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('admin_change_password'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    if (!canManageCategories) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Seul le Super Admin (ou admin autorisé via paramètres globaux) peut ajouter des catégories.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.add_circle_rounded,
                color: Color(0xFFF5A623),
                size: 26,
              ),
              SizedBox(width: 10),
              Text(
                'admin_new_category_title'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'admin_category_name_hint'.tr(),
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'admin_name_required'.tr()
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final name = nameCtrl.text.trim();
                      if (_categoryNameExists(name)) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Une catégorie porte déjà ce nom.'),
                          ),
                        );
                        return;
                      }
                      final ok = await FirebaseService().addCategory(
                        name: name,
                        isActive: true,
                        icon: Icons.handyman_rounded,
                        bgColor: const Color(0xFFE8F0FE),
                        iconColor: const Color(0xFF1E40AF),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Catégorie "$name" enregistrée avec succès !'
                                  : 'Erreur lors de l\'ajout de la catégorie',
                            ),
                            backgroundColor: ok
                                ? const Color(0xFF0D544E)
                                : Colors.redAccent,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5A623),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Text(
                      'Ajouter',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(Map<String, dynamic> cat) {
    if (!canManageCategories) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action réservée au Super Admin ou admin autorisé.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final nameCtrl = TextEditingController(text: cat['name']);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.edit_note_rounded,
                color: Color(0xFF0D544E),
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Modifier ${cat['name']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nom du métier',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'admin_name_required'.tr()
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final updatedName = nameCtrl.text.trim();
                      if (_categoryNameExists(
                        updatedName,
                        exceptId: cat['id']?.toString(),
                      )) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Une catégorie porte déjà ce nom.'),
                          ),
                        );
                        return;
                      }
                      final ok = await FirebaseService().updateCategory(
                        cat['id'] as String,
                        name: updatedName,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Catégorie modifiée avec succès.'
                                  : 'Erreur lors de la modification.',
                            ),
                            backgroundColor: ok
                                ? const Color(0xFF0D544E)
                                : Colors.redAccent,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAdminImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (picked != null) {
        final Uint8List bytes = await picked.readAsBytes();
        final base64Str = base64Encode(bytes);
        setState(() {
          _adminPhotoBase64 = base64Str;
        });
        await FirebaseService().updateCurrentUserData(
          fullName: _currentAdminName,
          phone: _currentAdminPhone,
          email: _currentAdminEmail,
          photoBase64: base64Str,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('admin_photo_updated'.tr()),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAdminPhotoPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0xFF334155)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'admin_profile_photo'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isDark
                        ? const Color(0xFF0284C7).withValues(alpha: 0.2)
                        : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Color(0xFF0284C7),
                  ),
                ),
                title: Text(
                  'admin_choose_gallery'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                subtitle: Text(
                  'admin_import_photo'.tr(),
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAdminImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isDark
                        ? const Color(0xFF0D544E).withValues(alpha: 0.25)
                        : const Color(0xFFD7F3EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Color(0xFF0D544E),
                  ),
                ),
                title: Text(
                  'admin_take_photo'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                subtitle: Text(
                  'admin_use_camera'.tr(),
                  style: TextStyle(fontSize: 12, color: _textSecondary),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAdminImage(ImageSource.camera);
                },
              ),
              if (_adminPhotoBase64 != null &&
                  _adminPhotoBase64!.isNotEmpty) ...[
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  title: Text(
                    'admin_delete_photo'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      _adminPhotoBase64 = null;
                    });
                    await FirebaseService().updateCurrentUserData(
                      fullName: _currentAdminName,
                      phone: _currentAdminPhone,
                      email: _currentAdminEmail,
                      photoBase64: '',
                    );
                  },
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? errorMessage;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text(
                'admin_change_password'.tr(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPassCtrl,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'admin_current_password'.tr(),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setDialogState(
                          () => obscureCurrent = !obscureCurrent,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Mot de passe actuel requis'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'admin_new_password'.tr(),
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Nouveau mot de passe requis';
                      if (v.trim().length < 6) return 'Minimum 6 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'admin_confirm_password'.tr(),
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setDialogState(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) {
                      if (v != newPassCtrl.text)
                        return 'Les mots de passe ne correspondent pas';
                      return null;
                    },
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFDC2626),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: Text(
                'cancel'.tr(),
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });

                      final messenger = ScaffoldMessenger.of(context);
                      final result = await FirebaseService().changePassword(
                        currentPassword: currentPassCtrl.text.trim(),
                        newPassword: newPassCtrl.text.trim(),
                      );

                      if (result['success'] == true) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Mot de passe mis à jour avec succès !',
                            ),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      } else {
                        setDialogState(() {
                          isSaving = false;
                          errorMessage = result['message'] as String?;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Mettre à jour'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAdminProfileDialog() {
    final nameCtrl = TextEditingController(text: _currentAdminName);
    final emailCtrl = TextEditingController(text: _currentAdminEmail);
    final phoneCtrl = TextEditingController(text: _currentAdminPhone);
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dlgDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: dlgDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.manage_accounts_rounded,
                  color: Color(0xFF0D544E),
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  'admin_edit_my_profile'.tr(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: dlgDark ? Colors.white : AppTheme.titleColor,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'admin_edit_info_desc'.tr(),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'admin_full_name'.tr(),
                        prefixIcon: const Icon(Icons.person_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'admin_name_required'.tr()
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'admin_email_address'.tr(),
                        prefixIcon: const Icon(
                          Icons.alternate_email_rounded,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) => v == null || !v.contains('@')
                          ? 'admin_invalid_email'.tr()
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'admin_phone_number'.tr(),
                        prefixIcon: const Icon(
                          Icons.phone_iphone_rounded,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'admin_phone_required'.tr()
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'cancel'.tr(),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        final newName = nameCtrl.text.trim();
                        final newEmail = emailCtrl.text.trim();
                        final newPhone = phoneCtrl.text.trim();
                        setState(() {
                          _currentAdminName = newName;
                          _currentAdminEmail = newEmail;
                          _currentAdminPhone = newPhone;
                        });
                        await FirebaseService().updateCurrentUserData(
                          fullName: newName,
                          phone: newPhone,
                          email: newEmail,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Profil Administrateur mis à jour avec succès !',
                              ),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D544E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Text('admin_logout_title'.tr()),
          ],
        ),
        content: Text('admin_logout_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              'cancel'.tr(),
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {}
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('admin_logout'.tr()),
          ),
        ],
      ),
    );
  }

  String _generateSecurePassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
    final random = Random.secure();
    return List.generate(
      10,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  void _showGlobalSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<Map<String, dynamic>>(
        stream: FirebaseService().streamGlobalSettings(),
        builder: (context, snapshot) {
          final settings =
              snapshot.data ??
              {
                'maintenanceMode': false,
                'adminCanManageCategories': false,
                'serviceFeePercent': 10.0,
                'maxUploadSizeBytes': 5242880,
              };
          bool maintenance = settings['maintenanceMode'] == true;
          bool canCategories = settings['adminCanManageCategories'] == true;
          double fee =
              (settings['serviceFeePercent'] as num?)?.toDouble() ?? 10.0;
          return StatefulBuilder(
            builder: (ctx, setDlgState) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Row(
                children: [
                  Icon(Icons.tune_rounded, color: Color(0xFFD97706), size: 26),
                  SizedBox(width: 10),
                  Text(
                    'Paramètres globaux',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(
                      'admin_maintenance_mode'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text('admin_maintenance_desc'.tr()),
                    value: maintenance,
                    activeThumbColor: const Color(0xFFD97706),
                    onChanged: (val) async {
                      setDlgState(() => maintenance = val);
                      await FirebaseService().updateGlobalSettings({
                        'maintenanceMode': val,
                      }, actorEmail: _currentAdminEmail);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text(
                      'admin_can_manage_cats'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text('admin_can_manage_cats_desc'.tr()),
                    value: canCategories,
                    activeThumbColor: const Color(0xFF0D544E),
                    onChanged: (val) async {
                      setDlgState(() => canCategories = val);
                      await FirebaseService().updateGlobalSettings({
                        'adminCanManageCategories': val,
                      }, actorEmail: _currentAdminEmail);
                    },
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'admin_service_fee'.tr(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${fee.toStringAsFixed(0)} %',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D544E),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: fee,
                          min: 0,
                          max: 30,
                          divisions: 30,
                          activeColor: const Color(0xFF0D544E),
                          label: '${fee.toStringAsFixed(0)} %',
                          onChanged: (val) {
                            setDlgState(() => fee = val);
                          },
                          onChangeEnd: (val) async {
                            await FirebaseService().updateGlobalSettings({
                              'serviceFeePercent': val,
                            }, actorEmail: _currentAdminEmail);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D544E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('close'.tr()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showNewAdminDialog() {
    if (!isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('admin_only_super_admin_categories'.tr()),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dlgIsDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: dlgIsDark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF0D544E),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'admin_create_account_title'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: dlgIsDark ? Colors.white : AppTheme.titleColor,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'admin_create_account_desc'.tr(),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: dlgIsDark
                              ? const Color(0xFF94A3B8)
                              : AppTheme.subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        style: TextStyle(
                          color: dlgIsDark ? Colors.white : AppTheme.titleColor,
                        ),
                        decoration: InputDecoration(
                          labelText: 'admin_full_name'.tr(),
                          prefixIcon: const Icon(
                            Icons.person_rounded,
                            size: 20,
                            color: Color(0xFF0D544E),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: dlgIsDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFDDE3EA),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF0D544E),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'admin_name_required'.tr()
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(
                          color: dlgIsDark ? Colors.white : AppTheme.titleColor,
                        ),
                        decoration: InputDecoration(
                          labelText: 'admin_phone_number'.tr(),
                          prefixIcon: const Icon(
                            Icons.phone_rounded,
                            size: 20,
                            color: Color(0xFF0D544E),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: dlgIsDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFDDE3EA),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF0D544E),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'admin_phone_required'.tr()
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: dlgIsDark ? Colors.white : AppTheme.titleColor,
                        ),
                        decoration: InputDecoration(
                          labelText: 'admin_institutional_email'.tr(),
                          prefixIcon: const Icon(
                            Icons.alternate_email_rounded,
                            size: 20,
                            color: Color(0xFF0D544E),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: dlgIsDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFDDE3EA),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF0D544E),
                              width: 1.5,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'admin_invalid_email'.tr()
                            : null,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: dlgIsDark
                              ? const Color(0xFF0D544E).withValues(alpha: 0.22)
                              : const Color(0xFFE8F3F1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: dlgIsDark
                                ? const Color(0xFF2A746C).withValues(alpha: 0.5)
                                : const Color(0xFFC6DFDA),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.mark_email_read_rounded,
                              color: Color(0xFF0D544E),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'admin_password_auto_generated'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: dlgIsDark
                                      ? const Color(0xFFA7D2CA)
                                      : const Color(0xFF0D544E),
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'cancel'.tr(),
                    style: TextStyle(
                      color: dlgIsDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          final newAdminName = nameController.text.trim();
                          final newAdminEmail = emailController.text.trim();
                          final newAdminPhone = phoneController.text.trim();
                          final autoPassword = _generateSecurePassword();
                          final messenger = ScaffoldMessenger.of(context);
                          final res = await FirebaseService().registerAdmin(
                            fullName: newAdminName,
                            phone: newAdminPhone,
                            email: newAdminEmail,
                            password: autoPassword,
                          );
                          EmailSendResult? emailResult;
                          if (res['success'] == true) {
                            emailResult =
                                await EmailService.sendNewAdminCredentials(
                                  toEmail: newAdminEmail,
                                  adminName: newAdminName,
                                  generatedPassword: autoPassword,
                                );
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            if (res['success'] == true) {
                              _showAdminCreatedDialog(
                                newAdminName,
                                newAdminEmail,
                                emailSent: emailResult?.sent == true,
                                emailError: emailResult?.error,
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] as String),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                            setState(() {});
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D544E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text('admin_create_and_send'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAdminCreatedDialog(
    String name,
    String email, {
    required bool emailSent,
    String? emailError,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              emailSent ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: emailSent ? const Color(0xFF10B981) : Colors.deepOrange,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Compte administrateur créé',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Le compte de $name a été activé.',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emailSent
                          ? 'Email d’accès envoyé à :'
                          : 'Email non envoyé à :',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                emailSent
                    ? 'Le mot de passe temporaire a été transmis uniquement dans cet email.'
                    : 'Le compte est créé, mais le mot de passe temporaire n’a pas pu être envoyé par email.',
                style: TextStyle(
                  fontSize: 12,
                  color: emailSent
                      ? const Color(0xFF64748B)
                      : Colors.deepOrange,
                ),
              ),
              if (!emailSent && emailError != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  emailError,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D544E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _showApproveProDialog(ProApplication app) {
    bool isApproving = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 26),
              SizedBox(width: 10),
              Text(
                'admin_validate_candidacy'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF334155),
                  ),
                  children: [
                    const TextSpan(
                      text: 'Voulez-vous valider la candidature de ',
                    ),
                    TextSpan(
                      text: app.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' ('),
                    TextSpan(
                      text: app.serviceType,
                      style: const TextStyle(
                        color: Color(0xFF0D544E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ') ?'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.mark_email_read_rounded,
                      color: Color(0xFF059669),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Un email d\'acceptation sera automatiquement envoyé à ${app.email}.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isApproving ? null : () => Navigator.pop(ctx),
              child: Text(
                'cancel'.tr(),
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ),
            ElevatedButton(
              onPressed: isApproving
                  ? null
                  : () async {
                      setDialogState(() => isApproving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final success = await FirebaseService()
                            .approveProApplication(
                              app.id,
                              proApp: app,
                              actorEmail: _currentAdminEmail,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (success) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Candidature de ${app.fullName} approuvée.',
                              ),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                          setState(() {});
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Erreur lors de la validation. Réessayez.',
                              ),
                              backgroundColor: Color(0xFFDC2626),
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Erreur : $e'),
                            backgroundColor: const Color(0xFFDC2626),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isApproving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('admin_confirm_validation_btn'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectProDialog(ProApplication app) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isRejecting = false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('admin_reject_application'.tr()),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Professionnel : ${app.fullName}'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motif du refus',
                    hintText: 'Expliquez la raison du refus...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Le motif est obligatoire.'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isRejecting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: isRejecting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isRejecting = true);
                      final success = await FirebaseService()
                          .rejectProApplication(
                            app.id,
                            reason: reasonController.text.trim(),
                            proApp: app,
                            actorEmail: _currentAdminEmail,
                          );
                      if (!mounted || !dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Candidature de ${app.fullName} refusée.'
                                : 'Le refus a échoué. La candidature est peut-être déjà traitée ou le compte est introuvable.',
                          ),
                          backgroundColor: success
                              ? const Color(0xFF10B981)
                              : const Color(0xFFDC2626),
                        ),
                      );
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: isRejecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirmer le refus'),
            ),
          ],
        ),
      ),
    ).whenComplete(reasonController.dispose);
  }

  void _showUserDetailsDialog(Map<String, dynamic> user) {
    final role = (user['role'] as String? ?? 'client').toLowerCase();
    final isActive = user['isActive'] ?? true;
    final fullName = user['fullName'] ?? 'Utilisateur';
    final email = user['email'] ?? '';
    final phone = user['phone'] ?? 'Non renseigné';
    final serviceType = user['serviceType'] ?? 'Non spécifié';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Builder(
              builder: (context) {
                final userPhoto = user['photoBase64'] as String?;
                if (userPhoto != null && userPhoto.isNotEmpty) {
                  try {
                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF0D544E)
                          .withValues(alpha: 0.12),
                      backgroundImage: MemoryImage(base64Decode(userPhoto)),
                    );
                  } catch (_) {}
                }
                final userPhotoUrl = user['photoUrl']?.toString().trim() ?? '';
                if (userPhotoUrl.isNotEmpty) {
                  return CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF0D544E)
                        .withValues(alpha: 0.12),
                    backgroundImage: NetworkImage(userPhotoUrl),
                  );
                }
                return CircleAvatar(
                  backgroundColor: const Color(0xFF0D544E)
                      .withValues(alpha: 0.12),
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Color(0xFF0D544E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fullName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.alternate_email_rounded, 'Email', email),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.phone_rounded, 'Téléphone', phone),
            const SizedBox(height: 10),
            _buildDetailRow(
              Icons.location_on_outlined,
              'Ville / région',
              (user['governorate'] ?? user['city'] ?? 'Non renseignée')
                  .toString(),
            ),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.badge_rounded, 'Rôle', role.toUpperCase()),
            if (role == 'professionnel') ...[
              const SizedBox(height: 10),
              _buildDetailRow(
                Icons.handyman_rounded,
                'Spécialité',
                serviceType,
              ),
            ],
            const SizedBox(height: 10),
            _buildDetailRow(
              Icons.check_circle_outline_rounded,
              'Statut du compte',
              isActive ? 'Actif' : 'Suspendu / Inactif',
            ),
            const SizedBox(height: 10),
            _buildDetailRow(
              Icons.calendar_today_outlined,
              'Inscription',
              _formatManagedClientDate(user['createdAt']),
            ),
          ],
        ),
        actions: [
          if (isSuperAdmin && role == 'client')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showEditClientDialog(user);
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Modifier les informations'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          if (isSuperAdmin && (user['email'] ?? '') != 'admin@darplus.tn')
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showEditUserRoleDialog(user);
              },
              icon: const Icon(Icons.manage_accounts_rounded, size: 16),
              label: const Text('Modifier le rôle'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  void _showEditClientDialog(Map<String, dynamic> user) {
    if (!isSuperAdmin) return;
    final uid = (user['id'] ?? user['uid'] ?? '').toString();
    if (uid.isEmpty) return;
    final nameController = TextEditingController(
      text: (user['fullName'] ?? '').toString(),
    );
    final phoneController = TextEditingController(
      text: (user['phone'] ?? '').toString(),
    );
    final locationController = TextEditingController(
      text: (user['governorate'] ?? user['city'] ?? '').toString(),
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('admin_edit_client_profile'.tr()),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nom complet'),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Le nom est obligatoire.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: (user['email'] ?? '').toString(),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      helperText:
                          'L’adresse email est gérée par Firebase Auth.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Ville / région',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final success = await FirebaseService()
                          .updateManagedClientProfile(
                            uid: uid,
                            fullName: nameController.text,
                            phone: phoneController.text,
                            governorate: locationController.text,
                            actorEmail: _currentAdminEmail,
                          );
                      if (!mounted || !dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success ? 'Profil client mis à jour.' : 'La modification a échoué. Vérifiez les droits et la connexion.',
                          ),
                          backgroundColor: success
                              ? const Color(0xFF10B981)
                              : Colors.redAccent,
                        ),
                      );
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
      locationController.dispose();
    });
  }

  Future<void> _setManagedClientStatus(
    Map<String, dynamic> client, {
    required bool isActive,
  }) async {
    if (!isSuperAdmin && !isActive) return;
    final uid = (client['id'] ?? client['uid'] ?? '').toString();
    if (uid.isEmpty) return;
    final name = (client['fullName'] ?? 'ce client').toString();
    final nextStatus = !isActive;
    if (nextStatus && !isSuperAdmin) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          nextStatus ? 'Réactiver le compte ?' : 'Désactiver le compte ?',
        ),
        content: Text(
          nextStatus
              ? 'Le compte de $name pourra de nouveau utiliser la plateforme.'
              : 'Le compte de $name sera désactivé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(nextStatus ? 'Réactiver' : 'Désactiver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await FirebaseService().toggleUserStatus(
      uid,
      (client['email'] ?? '').toString(),
      isActive,
      _currentAdminEmail,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (nextStatus
                    ? 'Compte client réactivé.'
                    : 'Compte client désactivé.')
              : 'Impossible de modifier le statut du compte.',
        ),
        backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
      ),
    );
  }

  String _formatManagedClientDate(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (value is String) date = DateTime.tryParse(value);
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showEditUserRoleDialog(Map<String, dynamic> user) {
    final docId = user['id'] ?? user['uid'] ?? '';
    final fullName = user['fullName'] ?? 'Utilisateur';
    final email = user['email'] ?? '';
    String selectedRole = (user['role'] as String? ?? 'client').toLowerCase();
    bool isSaving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.shield_rounded,
                color: Color(0xFF7C3AED),
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Modifier le rôle : $fullName',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Email : $email',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Text(
                'admin_select_new_role'.tr(),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 10),
              _buildRoleOption(
                'client',
                'admin_role_client_desc'.tr(),
                selectedRole,
                (val) => setDialogState(() => selectedRole = val),
              ),
              _buildRoleOption(
                'professionnel',
                'admin_role_pro_desc'.tr(),
                selectedRole,
                (val) => setDialogState(() => selectedRole = val),
              ),
              _buildRoleOption(
                'admin',
                'admin_role_admin_desc'.tr(),
                selectedRole,
                (val) => setDialogState(() => selectedRole = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final success = await FirebaseService().updateUserRole(
                        uid: docId,
                        email: email,
                        newRole: selectedRole,
                        actorEmail: _currentAdminEmail,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {});
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Rôle de $fullName mis à jour en $selectedRole'
                                  : 'Impossible de modifier le rôle.',
                            ),
                            backgroundColor: success
                                ? const Color(0xFF10B981)
                                : Colors.redAccent,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleOption(
    String roleKey,
    String label,
    String currentRole,
    ValueChanged<String> onSelect,
  ) {
    final bool isSelected = currentRole == roleKey;
    return InkWell(
      onTap: () => onSelect(roleKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF7C3AED)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0D544E)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: _textSecondary),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();
    if (!kIsWeb) return const AdminWebOnlyScreen();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF7F9F9);
    final navBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return StreamBuilder<List<ProApplication>>(
      stream: FirebaseService().streamProApplications(),
      builder: (context, snapshot) {
        final allList = snapshot.data ?? [];
        final pendingList = allList
            .where((a) => a.status == 'en_attente')
            .toList();
        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            final bodyContent = IndexedStack(
              index: _currentBottomNavIndex,
              children: [
                _buildDashboardTab(pendingList),
                _buildUsersTab(),
                _buildValidationsTab(allList),
                _buildCategoriesTab(),
                _buildAdminProfileTab(),
                _buildSupervisionTab(),
                _buildInterventionsAdminTab(),
                _buildPaymentsAdminTab(),
                _buildReviewsAdminTab(),
                _buildPromotionsAdminTab(),
              ],
            );

            if (isDesktop) {
              return Scaffold(
                backgroundColor: scaffoldBg,
                body: Row(
                  children: [
                    _buildAdminSidebar(pendingList.length),
                    Expanded(
                      child: Column(
                        children: [
                          _buildAdminTopHeader(),
                          Expanded(child: bodyContent),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Mobile / Tablet layout
            return Scaffold(
              backgroundColor: scaffoldBg,
              drawer: Drawer(child: _buildAdminSidebar(pendingList.length)),
              appBar: AppBar(
                backgroundColor: _cardBg,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: Builder(
                  builder: (ctx) => IconButton(
                    icon: Icon(Icons.menu_rounded, color: _textPrimary),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                title: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D544E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'D+',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _webTabTitle(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
                actions: [
                  _buildReportNotificationButton(compact: true),
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: CommissionService()
                        .streamAdminPaymentNotifications(),
                    builder: (context, snapshot) {
                      final unread = (snapshot.data ?? [])
                          .where((n) => n['isRead'] != true)
                          .length;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none_rounded),
                            color: _textPrimary,
                            onPressed: () =>
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.paymentTransactions),
                          ),
                          if (unread > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDE6D1B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _currentBottomNavIndex = 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage:
                            _adminPhotoBase64 != null &&
                                _adminPhotoBase64!.isNotEmpty
                            ? MemoryImage(base64Decode(_adminPhotoBase64!))
                            : null,
                        child:
                            _adminPhotoBase64 == null ||
                                _adminPhotoBase64!.isEmpty
                            ? Text(
                                _getInitials(_currentAdminName),
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              body: SafeArea(bottom: false, child: bodyContent),
              bottomNavigationBar: Container(
                decoration: BoxDecoration(
                  color: navBg,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? const Color(0xFF334155)
                          : Colors.grey.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentBottomNavIndex > 4
                      ? 4
                      : _currentBottomNavIndex,
                  onTap: (index) =>
                      setState(() => _currentBottomNavIndex = index),
                  type: BottomNavigationBarType.fixed,
                  backgroundColor: navBg,
                  selectedItemColor: isDark
                      ? const Color(0xFF10B981)
                      : const Color(0xFF0D544E),
                  unselectedItemColor: isDark
                      ? const Color(0xFF94A3B8)
                      : Colors.grey,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 11),
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.dashboard_outlined),
                      activeIcon: const Icon(Icons.dashboard_rounded),
                      label: 'admin_tab_dashboard'.tr(),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.people_outline_rounded),
                      activeIcon: const Icon(Icons.people_rounded),
                      label: 'admin_tab_users'.tr(),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.verified_user_outlined),
                      activeIcon: const Icon(Icons.verified_user_rounded),
                      label: 'admin_tab_requests'.tr(),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.category_outlined),
                      activeIcon: const Icon(Icons.category_rounded),
                      label: 'admin_tab_categories'.tr(),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.person_outline_rounded),
                      activeIcon: const Icon(Icons.person_rounded),
                      label: 'admin_tab_profile'.tr(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ────────── SIDEBAR EXACT MATCH TO MOCKUP ──────────
  Widget _buildAdminSidebar(int pendingCount) {
    return Container(
      width: 248,
      color: const Color(0xFF0B132B),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Logo Badge
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D544E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'D+',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'DAR PLUS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'ADMINISTRATION',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                          fontSize: 8.5,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 8),
              child: Text(
                'ESPACE DE GESTION',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildSidebarItem(
                      index: 0,
                      icon: Icons.grid_view_rounded,
                      label: "Vue d'ensemble",
                    ),
                    _buildSidebarItem(
                      index: 1,
                      icon: Icons.people_outline_rounded,
                      label: 'Clients',
                      onTapOverride: () {
                        setState(() {
                          _userRoleFilter = 'client';
                          _currentBottomNavIndex = 1;
                        });
                      },
                    ),
                    _buildSidebarItem(
                      index: 2,
                      icon: Icons.badge_outlined,
                      label: 'Professionnels',
                      badgeText: pendingCount > 0 ? '$pendingCount' : null,
                      onTapOverride: () {
                        setState(() => _currentBottomNavIndex = 2);
                      },
                    ),
                    _buildSidebarItem(
                      index: 6,
                      icon: Icons.calendar_today_outlined,
                      label: 'Interventions',
                    ),
                    _buildSidebarItem(
                      index: 7,
                      icon: Icons.credit_card_outlined,
                      label: 'Paiements',
                    ),
                    _buildSidebarItem(
                      index: 8,
                      icon: Icons.star_outline_rounded,
                      label: 'Avis',
                    ),
                    _buildSidebarItem(
                      index: -1,
                      icon: Icons.flag_outlined,
                      label: 'Signalements',
                      selectedOverride:
                          _currentBottomNavIndex == 5 &&
                          _supervisionSubTab == 0,
                      badgeText: _openReportCount > 0
                          ? '$_openReportCount'
                          : null,
                      onTapOverride: () {
                        setState(() {
                          _currentBottomNavIndex = 5;
                          _supervisionSubTab = 0;
                        });
                      },
                    ),
                    _buildSidebarItem(
                      index: 9,
                      icon: Icons.local_offer_outlined,
                      label: 'Promotions',
                    ),
                    _buildSidebarItem(
                      index: 3,
                      icon: Icons.category_outlined,
                      label: 'Catégories',
                      onTapOverride: () {
                        setState(() => _currentBottomNavIndex = 3);
                      },
                    ),
                    _buildSidebarItem(
                      index: 5,
                      icon: Icons.show_chart_rounded,
                      label: 'Rapports',
                      selectedOverride:
                          _currentBottomNavIndex == 5 &&
                          _supervisionSubTab == 1,
                      onTapOverride: () {
                        setState(() {
                          _currentBottomNavIndex = 5;
                          _supervisionSubTab = 1;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(
              color: Color(0xFF1E293B),
              indent: 18,
              endIndent: 18,
              height: 1,
            ),
            const SizedBox(height: 8),
            _buildSidebarItem(
              index: 4,
              icon: Icons.settings_outlined,
              label: 'Paramètres',
              onTapOverride: () => setState(() => _currentBottomNavIndex = 4),
            ),
            // Admin Profile Footer Card
            Container(
              margin: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF131F37),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFFE2E8F0),
                    backgroundImage:
                        _adminPhotoBase64 != null &&
                            _adminPhotoBase64!.isNotEmpty
                        ? MemoryImage(base64Decode(_adminPhotoBase64!))
                        : null,
                    child:
                        _adminPhotoBase64 == null || _adminPhotoBase64!.isEmpty
                        ? Text(
                            _getInitials(_currentAdminName),
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentAdminName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSuperAdmin
                              ? 'Super administratrice'
                              : 'Administrateur',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    color: const Color(0xFF1E293B),
                    onSelected: (val) async {
                      if (val == 'profile') {
                        setState(() => _currentBottomNavIndex = 4);
                      } else if (val == 'logout') {
                        await FirebaseService().signOut();
                        if (mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.login,
                            (_) => false,
                          );
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'profile',
                        child: Text(
                          'Profil & Paramètres',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Text(
                          'Se déconnecter',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _adminSidebarLabel(String label) => switch (label) {
    "Vue d'ensemble" => 'admin_dashboard'.tr(),
    'Clients' => 'admin_clients'.tr(),
    'Professionnels' => 'admin_professionals'.tr(),
    'Interventions' => 'admin_interventions'.tr(),
    'Paiements' => 'admin_payments'.tr(),
    'Avis' => 'admin_customer_reviews'.tr(),
    'Signalements' => 'admin_reports'.tr(),
    'Promotions' => 'admin_promotions'.tr(),
    'Catégories' => 'admin_categories'.tr(),
    'Rapports' => 'admin_analytics'.tr(),
    'Paramètres' => 'admin_settings'.tr(),
    _ => label,
  };

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String label,
    String? badgeText,
    bool? selectedOverride,
    VoidCallback? onTapOverride,
  }) {
    final selected = selectedOverride ?? (_currentBottomNavIndex == index);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: InkWell(
        onTap:
            onTapOverride ??
            () => setState(() => _currentBottomNavIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0D544E) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF94A3B8),
                size: 19,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _adminSidebarLabel(label),
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFCBD5E1),
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDE6D1B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────── TOP HEADER (SEARCH + NOTIFS + AVATAR) ──────────
  Widget _buildAdminTopHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Row(
        children: [
          // Search box
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              height: 40,
              decoration: BoxDecoration(
                color: _isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 18, color: _textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _userSearchController,
                      onChanged: (val) {
                        setState(() {
                          _clientSearchQuery = val;
                          _proSearchQuery = val;
                          _proCurrentPage = 1;
                          if (val.trim().isNotEmpty &&
                              _currentBottomNavIndex == 0) {
                            _currentBottomNavIndex = 1;
                          }
                        });
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText:
                            'Rechercher un client, un pro, une intervention...',
                        hintStyle: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      style: TextStyle(color: _textPrimary, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Text(
                      '⌘K',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Notification bell
          _buildReportNotificationButton(),
          const SizedBox(width: 4),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: CommissionService().streamAdminPaymentNotifications(),
            builder: (context, snapshot) {
              final unread = (snapshot.data ?? [])
                  .where((n) => n['isRead'] != true)
                  .length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(color: _borderColor),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        size: 20,
                      ),
                      color: _textPrimary,
                      onPressed: () =>
                          Navigator.of(context)
                              .pushNamed(AppRoutes.paymentTransactions),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 1,
                      top: 1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDE6D1B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => setState(() => _currentBottomNavIndex = 4),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFEADBD2),
                    backgroundImage:
                        _adminPhotoBase64 != null &&
                            _adminPhotoBase64!.isNotEmpty
                        ? MemoryImage(base64Decode(_adminPhotoBase64!))
                        : null,
                    child:
                        _adminPhotoBase64 == null || _adminPhotoBase64!.isEmpty
                        ? Text(
                            _getInitials(_currentAdminName),
                            style: const TextStyle(
                              color: Color(0xFF8A4D38),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 9),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 145),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentAdminName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          isSuperAdmin ? 'Super admin' : 'Admin',
                          style: TextStyle(color: _textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: _textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _webTabTitle() {
    switch (_currentBottomNavIndex) {
      case 0:
        return 'admin_dashboard'.tr();
      case 1:
        return _userRoleFilter == 'client' ? 'admin_clients'.tr() : 'admin_users'.tr();
      case 2:
        return 'admin_professionals'.tr();
      case 3:
        return 'admin_categories'.tr();
      case 4:
        return 'admin_settings'.tr();
      case 5:
        return switch (_supervisionSubTab) {
          0 => 'admin_reports_center'.tr(),
          1 => 'admin_reports_analytics'.tr(),
          _ => 'admin_security_logs'.tr(),
        };
      case 6:
        return 'admin_interventions'.tr();
      case 7:
        return 'admin_payments'.tr();
      case 8:
        return 'admin_customer_reviews'.tr();
      case 9:
        return 'admin_promotions'.tr();
      default:
        return 'admin_title'.tr();
    }
  }

  // ────────── TAB 0: DASHBOARD REDESIGN ──────────
  Widget _buildDashboardTab(List<ProApplication> pendingList) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1050;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 18,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Welcome Header (Greeting + Export + New action)
              _buildDashboardWelcomeHeader(),
              const SizedBox(height: 24),

              // 2. KPI cards
              _buildKpiCardsRow(pendingList),
              const SizedBox(height: 16),

              // 3. Middle Row: Platform Activity + Services Donut
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 64, child: _buildPlatformActivityCard()),
                    const SizedBox(width: 20),
                    Expanded(flex: 36, child: _buildServicesDistributionCard()),
                  ],
                )
              else ...[
                _buildPlatformActivityCard(),
                const SizedBox(height: 20),
                _buildServicesDistributionCard(),
              ],
              const SizedBox(height: 24),

              // 4. Bottom row: recent activity and interventions
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 40, child: _buildRecentActivityLiveCard()),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 60,
                      child: _buildRecentInterventionsLiveCard(),
                    ),
                  ],
                )
              else ...[
                _buildRecentActivityLiveCard(),
                const SizedBox(height: 20),
                _buildRecentInterventionsLiveCard(),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardWelcomeHeader() {
    final firstName = _currentAdminName.trim().split(' ').first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DAR PLUS • CONSOLE ADMIN',
                style: TextStyle(
                  color: Color(0xFF0D544E),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bonjour, $firstName',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Voici ce qui se passe sur DAR PLUS aujourd'hui.",
                style: TextStyle(fontSize: 13.5, color: _textSecondary),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _showExportDialog,
              icon: const Icon(Icons.download_rounded, size: 17),
              label: const Text('Exporter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textPrimary,
                side: BorderSide(color: _borderColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _showQuickActionDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('admin_new_action'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKpiCardsRow(List<ProApplication> pendingList) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
      builder: (context, bookingsSnapshot) {
        final bookings = bookingsSnapshot.data?.docs ?? const [];
        final clients = _dashboardUsers
            .where((user) => user['role'] == 'client')
            .length;
        final professionals = _dashboardUsers
            .where(
              (user) =>
                  user['role'] == 'professionnel' && user['isApproved'] == true,
            )
            .length;
        final now = DateTime.now();
        final thisMonthBookings = bookings.where((doc) {
          final createdAt = doc.data()['createdAt'];
          return createdAt is Timestamp &&
              createdAt.toDate().year == now.year &&
              createdAt.toDate().month == now.month;
        }).length;
        final paidBookings = bookings.where((doc) {
          final data = doc.data();
          final createdAt = data['createdAt'];
          final paymentStatus = (data['paymentStatus'] ?? '')
              .toString()
              .toLowerCase();
          return data['status'] == 'terminee' &&
              createdAt is Timestamp &&
              createdAt.toDate().year == now.year &&
              createdAt.toDate().month == now.month &&
              (data['paidAmount'] != null ||
                  [
                    'succes',
                    'success',
                    'paid',
                    'paye',
                  ].contains(paymentStatus));
        });
        final revenue = paidBookings.fold<double>(0, (sum, doc) {
          final data = doc.data();
          final amount = data['paidAmount'] ?? data['totalAmount'];
          if (amount is num) return sum + amount.toDouble();
          if (amount is String) {
            final parsed = double.tryParse(
              amount.replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.'),
            );
            return sum + (parsed ?? 0);
          }
          return sum;
        });
        return LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 1100
                ? 5
                : (constraints.maxWidth >= 850
                      ? 3
                      : (constraints.maxWidth >= 520 ? 2 : 1));

            final cards = [
              _buildKpiCard(
                title: 'Clients',
                value: clients.toString(),
                trend: '',
                subtitle: 'comptes clients',
                icon: Icons.people_outline_rounded,
                iconBg: const Color(0xFFEEF2FF),
                iconColor: const Color(0xFF6366F1),
                onTap: () {
                  setState(() {
                    _userRoleFilter = 'client';
                    _currentBottomNavIndex = 1;
                  });
                },
              ),
              _buildKpiCard(
                title: 'Professionnels',
                value: professionals.toString(),
                trend: '',
                subtitle: 'comptes approuvés',
                icon: Icons.work_outline_rounded,
                iconBg: const Color(0xFFE6F4F1),
                iconColor: const Color(0xFF0D544E),
                onTap: () => setState(() => _currentBottomNavIndex = 2),
              ),
              _buildKpiCard(
                title: 'Demandes en attente',
                value: pendingList.length.toString(),
                trend: pendingList.isNotEmpty ? 'À traiter' : '',
                subtitle: 'profils à examiner',
                subtitleColor: pendingList.isNotEmpty
                    ? const Color(0xFFDE6D1B)
                    : null,
                icon: Icons.schedule_rounded,
                iconBg: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFEA580C),
                onTap: () => setState(() => _currentBottomNavIndex = 2),
              ),
              _buildKpiCard(
                title: 'Interventions',
                value: thisMonthBookings.toString(),
                trend: '',
                subtitle: 'ce mois-ci',
                icon: Icons.calendar_today_outlined,
                iconBg: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFEA580C),
                onTap: _showInterventionsOverviewDialog,
              ),
              _buildKpiCard(
                title: "Chiffre d'affaires",
                value: '${revenue.toStringAsFixed(0)} TND',
                trend: '',
                subtitle: 'ce mois-ci',
                icon: Icons.account_balance_wallet_outlined,
                iconBg: const Color(0xFFFEF9C3),
                iconColor: const Color(0xFFD97706),
                onTap: () =>
                    Navigator.of(context)
                        .pushNamed(AppRoutes.paymentTransactions),
              ),
            ];

            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: cols >= 4 ? 1.12 : (cols == 3 ? 1.3 : 1.55),
              children: cards,
            );
          },
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String trend,
    required String subtitle,
    Color? subtitleColor,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                if (trend.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trend,
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: subtitleColor ?? _textSecondary,
                fontWeight: subtitleColor != null
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformActivityCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activité de la plateforme',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Interventions et revenus générés',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 36),
                onSelected: (val) {
                  setState(() => _dashboardRange = val);
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: '7 derniers jours',
                    child: Text('7 derniers jours'),
                  ),
                  PopupMenuItem(
                    value: '30 derniers jours',
                    child: Text('30 derniers jours'),
                  ),
                  PopupMenuItem(
                    value: '3 derniers mois',
                    child: Text('3 derniers mois'),
                  ),
                  PopupMenuItem(
                    value: 'Cette année',
                    child: Text('Cette année'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dashboardRange,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: _textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SizedBox(
                  height: 190,
                  child: Center(
                    child: Text(
                      'Impossible de charger les statistiques.',
                      style: TextStyle(color: _textSecondary),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 190,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final days = switch (_dashboardRange) {
                '30 derniers jours' => 30,
                '3 derniers mois' => 90,
                'Cette année' => 365,
                _ => 7,
              };
              final now = DateTime.now();
              final start = now.subtract(Duration(days: days - 1));
              final revenues = List<double>.filled(7, 0);
              final interventions = List<double>.filled(7, 0);
              for (final doc in snapshot.data!.docs) {
                final data = doc.data();
                if (data['status'] != 'terminee') continue;
                final rawDate = data['completedAt'] ?? data['createdAt'];
                if (rawDate is! Timestamp) continue;
                final date = rawDate.toDate();
                if (date.isBefore(start) || date.isAfter(now)) continue;
                final bucket = (date.difference(start).inDays * 7 ~/ days)
                    .clamp(0, 6);
                interventions[bucket] += 1;
                final paymentStatus = (data['paymentStatus'] ?? '')
                    .toString()
                    .toLowerCase();
                final amount =
                    data['paidAmount'] ??
                    ([
                          'succes',
                          'success',
                          'paid',
                          'paye',
                        ].contains(paymentStatus)
                        ? data['totalAmount']
                        : null);
                if (amount is num) revenues[bucket] += amount.toDouble() / 1000;
              }
              final labels = List.generate(7, (i) {
                final date = start.add(Duration(days: (days * i ~/ 7)));
                return '${date.day}/${date.month}';
              });
              return PlatformActivityChart(
                height: 190,
                isDark: _isDark,
                revenues: revenues,
                interventions: interventions,
                xLabels: labels,
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(const Color(0xFF0D544E), 'Montants payés'),
              const SizedBox(width: 24),
              _legendDot(const Color(0xFFDE6D1B), 'Interventions'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServicesDistributionCard() {
    final approvedPros = _dashboardUsers
        .where(
          (user) =>
              user['role'] == 'professionnel' && user['isApproved'] == true,
        )
        .toList();
    final categoryData =
        _adminCategories
            .map((category) {
              final name = (category['name'] ?? '').toString();
              final count = approvedPros
                  .where(
                    (pro) => (pro['serviceType'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains(name.toLowerCase()),
                  )
                  .length;
              final color = category['iconColor'] is Color
                  ? category['iconColor'] as Color
                  : const Color(0xFF0D544E);
              return (name: name, count: count, color: color);
            })
            .where((entry) => entry.count > 0)
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    final shownCategories = categoryData.take(4).toList();
    final shownCount = shownCategories.fold<int>(
      0,
      (sum, item) => sum + item.count,
    );
    final otherCount = (approvedPros.length - shownCount).clamp(
      0,
      approvedPros.length,
    );
    final slices = <ServiceSlice>[
      for (final item in shownCategories)
        ServiceSlice(
          label: item.name,
          percentage: approvedPros.isEmpty
              ? 0
              : item.count * 100 / approvedPros.length,
          color: item.color,
        ),
      if (otherCount > 0)
        ServiceSlice(
          label: 'Autres',
          percentage: approvedPros.isEmpty
              ? 0
              : otherCount * 100 / approvedPros.length,
          color: const Color(0xFF94A3B8),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Répartition des services',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Sur les 30 derniers jours',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: _textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val == 'details') {
                    _showInterventionsOverviewDialog();
                  } else if (val == 'export') {
                    _showExportDialog();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'details',
                    child: Text('Voir les détails'),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Text('admin_export_data'.tr()),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ServicesDonutChart(
                slices: slices,
                totalCount: approvedPros.length.toString(),
                totalLabel: 'pros',
                isDark: _isDark,
                size: 135,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: slices.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '${s.percentage.toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() {
                _currentBottomNavIndex = 5;
                _supervisionSubTab = 1;
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D544E),
                side: const BorderSide(color: Color(0xFF0D544E)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text(
                'Voir le rapport détaillé',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final activities = [
      {
        'initials': 'MB',
        'color': const Color(0xFF0D544E),
        'title': 'Mohamed Ben Ali a terminé une intervention',
        'subtitle': 'Plomberie · La Marsa',
        'time': 'Il y a 8 min',
      },
      {
        'initials': 'SA',
        'color': const Color(0xFF4338CA),
        'title': 'Sarra Ayadi a créé un nouveau compte',
        'subtitle': 'Nouvelle cliente',
        'time': 'Il y a 24 min',
      },
      {
        'initials': 'MK',
        'color': const Color(0xFFDE6D1B),
        'title': 'Mehdi Khelifi attend votre validation',
        'subtitle': 'Électricien · Tunis',
        'time': 'Il y a 45 min',
        'onTap': () => setState(() => _currentBottomNavIndex = 2),
      },
      {
        'initials': 'LB',
        'color': const Color(0xFFD97706),
        'title': 'Leïla Ben Amor a publié un avis 5 étoiles',
        'subtitle': 'Nettoyage à domicile',
        'time': 'Il y a 1 h',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activité récente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Derniers événements',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => setState(() => _currentBottomNavIndex = 5),
                child: const Text(
                  'Tout voir',
                  style: TextStyle(
                    color: Color(0xFF0D544E),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...activities.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Column(
              children: [
                InkWell(
                  onTap: item['onTap'] as VoidCallback?,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: item['color'] as Color,
                          child: Text(
                            item['initials'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['subtitle'] as String,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          item['time'] as String,
                          style: TextStyle(fontSize: 11, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                if (idx < activities.length - 1)
                  Divider(height: 1, color: _borderColor),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentInterventionsCard() {
    final rows = [
      {
        'id': '#DP-2841',
        'service': 'Plomberie',
        'client': 'Rim G.',
        'pro': 'Mohamed B.',
        'amount': '128 TND',
        'status': 'En cours',
        'statusBg': const Color(0xFFFEF3C7),
        'statusColor': const Color(0xFFD97706),
        'statusDot': const Color(0xFFD97706),
      },
      {
        'id': '#DP-2840',
        'service': 'Nettoyage',
        'client': 'Karim H.',
        'pro': 'Leïla B.',
        'amount': '85 TND',
        'status': 'Terminée',
        'statusBg': const Color(0xFFECFDF5),
        'statusColor': const Color(0xFF10B981),
        'statusDot': const Color(0xFF10B981),
      },
      {
        'id': '#DP-2839',
        'service': 'Électricité',
        'client': 'Sarra A.',
        'pro': 'Hichem K.',
        'amount': '210 TND',
        'status': 'Planifiée',
        'statusBg': const Color(0xFFEDE9FE),
        'statusColor': const Color(0xFF7C3AED),
        'statusDot': const Color(0xFF7C3AED),
      },
      {
        'id': '#DP-2838',
        'service': 'Climatisation',
        'client': 'Nadia M.',
        'pro': 'Nabil S.',
        'amount': '165 TND',
        'status': 'Terminée',
        'statusBg': const Color(0xFFECFDF5),
        'statusColor': const Color(0xFF10B981),
        'statusDot': const Color(0xFF10B981),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dernières interventions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Suivi en temps réel',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _showInterventionsOverviewDialog,
                child: const Text(
                  'Voir tout →',
                  style: TextStyle(
                    color: Color(0xFF0D544E),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: const [
                SizedBox(
                  width: 80,
                  child: Text(
                    'ID',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'SERVICE',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'CLIENT / PRO',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'MONTANT',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 95,
                  child: Text(
                    'STATUT',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 24),
              ],
            ),
          ),
          Divider(height: 1, color: _borderColor),
          ...rows.map((row) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          row['id'] as String,
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          row['service'] as String,
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row['client'] as String,
                              style: TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                            Text(
                              row['pro'] as String,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          row['amount'] as String,
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 95,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: row['statusBg'] as Color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: row['statusDot'] as Color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                row['status'] as String,
                                style: TextStyle(
                                  color: row['statusColor'] as Color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (val) {
                          if (val == 'view') {
                            _showInterventionsOverviewDialog();
                          } else if (val == 'details') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Détails intervention ${row['id']}: ${row['service']} · ${row['client']} · ${row['amount']}',
                                ),
                              ),
                            );
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Text('Voir toutes les interventions'),
                          ),
                          const PopupMenuItem(
                            value: 'details',
                            child: Text('Détails de l\'intervention'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _borderColor),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentActivityLiveCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activité récente',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Demandes reçues récemment',
                    style: TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
              TextButton(
                onPressed: _showInterventionsOverviewDialog,
                child: const Text('Tout voir'),
              ),
            ],
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .orderBy('createdAt', descending: true)
                .limit(4)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Impossible de charger l’activité.',
                    style: TextStyle(color: _textSecondary),
                  ),
                );
              }
              if (!snapshot.hasData)
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              final docs = snapshot.data!.docs;
              if (docs.isEmpty)
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Aucune activité récente.',
                    style: TextStyle(color: _textSecondary),
                  ),
                );
              return Column(
                children: docs.map((doc) {
                  final booking = doc.data();
                  final service = (booking['serviceType'] ?? 'Service')
                      .toString();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE6F4F1),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFF0D544E),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      'admin_new_request'.tr(args: [service]),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${booking['clientName'] ?? 'Client'} · ${booking['proName'] ?? 'Professionnel'}',
                      style: TextStyle(fontSize: 11.5, color: _textSecondary),
                    ),
                    onTap: () => _showBookingOverviewDetails(doc.id, booking),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentInterventionsLiveCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dernières interventions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              TextButton(
                onPressed: _showInterventionsOverviewDialog,
                child: const Text('Tout voir'),
              ),
            ],
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Impossible de charger les interventions.',
                    style: TextStyle(color: _textSecondary),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Aucune intervention enregistrée pour le moment.',
                    style: TextStyle(color: _textSecondary),
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final booking = doc.data();
                  final service =
                      (booking['serviceType'] ??
                              booking['serviceTitle'] ??
                              'Service')
                          .toString();
                  final client = (booking['clientName'] ?? 'Client').toString();
                  final pro = (booking['proName'] ?? 'Professionnel')
                      .toString();
                  final status = (booking['status'] ?? 'en_attente').toString();
                  final amount =
                      booking['paidAmount'] ??
                      booking['baseAmount'] ??
                      booking['price'] ??
                      '—';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE6F4F1),
                      child: Icon(
                        Icons.handyman_rounded,
                        color: Color(0xFF0D544E),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      service,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '$client · $pro · $status',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    trailing: Text(
                      '$amount${amount is num ? ' TND' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => _showBookingOverviewDetails(doc.id, booking),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showBookingOverviewDetails(
    String bookingId,
    Map<String, dynamic> booking,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'admin_intervention_details'.tr(),
          style: TextStyle(color: _textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.tag_rounded, 'Référence', bookingId),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.handyman_rounded,
              'Service',
              (booking['serviceType'] ?? 'Service').toString(),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.people_rounded,
              'Client / Pro',
              '${booking['clientName'] ?? 'Client'} / ${booking['proName'] ?? 'Professionnel'}',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.location_on_rounded,
              'Adresse',
              (booking['address'] ?? 'Non renseignée').toString(),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.info_outline_rounded,
              'Statut',
              (booking['status'] ?? 'en_attente').toString(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // ────────── MODALS & DIALOGS ──────────
  void _showQuickActionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nouvelle action rapide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE6F4F1),
                child: Icon(Icons.person_add_rounded, color: Color(0xFF0D544E)),
              ),
              title: Text('admin_validate_professional'.tr()),
              subtitle: Text('admin_review_pending_applications'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _currentBottomNavIndex = 2);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF7ED),
                child: Icon(
                  Icons.local_offer_rounded,
                  color: Color(0xFFDE6D1B),
                ),
              ),
              title: Text('admin_create_promotion'.tr()),
              subtitle: Text('admin_add_promo_help'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _showPromotionsDialog();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFEF9C3),
                child: Icon(Icons.tune_rounded, color: Color(0xFFD97706)),
              ),
              title: Text('admin_manage_commissions'.tr()),
              subtitle: Text('admin_manage_commissions_help'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushNamed(AppRoutes.commissionManagement);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(Icons.category_rounded, color: Color(0xFF4338CA)),
              ),
              title: Text('admin_new_category'.tr()),
              subtitle: Text('admin_add_service_category_help'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _showAddCategoryDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'admin_export_data'.tr(),
          style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.table_chart_rounded,
                color: Color(0xFF0D544E),
              ),
              title: Text('admin_interventions_csv'.tr()),
              subtitle: Text(
                'admin_copy_bookings_help'.tr(),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final snap = await FirebaseFirestore.instance
                      .collection('bookings')
                      .orderBy('createdAt', descending: true)
                      .limit(100)
                      .get();
                  final rows = <List<Object?>>[
                    [
                      'id',
                      'client',
                      'professionnel',
                      'service',
                      'statut',
                      'montant',
                    ],
                    for (final doc in snap.docs)
                      [
                        doc.id,
                        doc.data()['clientName'],
                        doc.data()['proName'],
                        doc.data()['serviceType'],
                        doc.data()['status'],
                        doc.data()['paidAmount'] ??
                            doc.data()['baseAmount'] ??
                            doc.data()['price'],
                      ],
                  ];
                  final csv = rows
                      .map((row) => row.map(_csvCell).join(','))
                      .join('\n');
                  await Clipboard.setData(ClipboardData(text: csv));
                  final count = snap.docs.length;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '$count interventions copiées au format CSV.',
                      ),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.people_alt_rounded,
                color: Color(0xFF4338CA),
              ),
              title: Text('admin_users_csv'.tr()),
              subtitle: Text(
                'admin_copy_users_help'.tr(),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final snap = await FirebaseFirestore.instance
                      .collection('users')
                      .get();
                  final rows = <List<Object?>>[
                    ['id', 'nom', 'email', 'téléphone', 'rôle', 'approuvé'],
                    for (final doc in snap.docs)
                      [
                        doc.id,
                        doc.data()['fullName'],
                        doc.data()['email'],
                        doc.data()['phone'],
                        doc.data()['role'],
                        doc.data()['isApproved'],
                      ],
                  ];
                  await Clipboard.setData(
                    ClipboardData(
                      text: rows
                          .map((row) => row.map(_csvCell).join(','))
                          .join('\n'),
                    ),
                  );
                  final count = snap.docs.length;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '$count utilisateurs copiés au format CSV.',
                      ),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.badge_outlined,
                color: Color(0xFF0D544E),
              ),
              title: Text('admin_applications_csv'.tr()),
              subtitle: Text(
                'admin_copy_applications_help'.tr(),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final applications = await FirebaseService()
                      .streamProApplications()
                      .first;
                  final rows = <List<Object?>>[
                    [
                      'id',
                      'nom',
                      'métier',
                      'email',
                      'téléphone',
                      'cin',
                      'statut',
                      'date_demande',
                      'notes',
                    ],
                    for (final app in applications)
                      [
                        app.id,
                        app.fullName,
                        app.serviceType,
                        app.email,
                        app.phone,
                        app.cin,
                        app.status,
                        app.createdAt.toIso8601String(),
                        app.notes,
                      ],
                  ];
                  await Clipboard.setData(
                    ClipboardData(
                      text: rows
                          .map((row) => row.map(_csvCell).join(','))
                          .join('\n'),
                    ),
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        '${applications.length} candidatures copiées au format CSV.',
                      ),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } catch (error) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Erreur d’export : $error')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Color(0xFFDC2626),
              ),
              title: Text('admin_monthly_financial_summary'.tr()),
              subtitle: Text(
                'admin_completed_jobs_total_help'.tr(),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showMonthlyFinancialSummary();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _csvCell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^[=+\-@]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  void _showMonthlyFinancialSummary() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('admin_financial_summary'.tr(), style: TextStyle(color: _textPrimary)),
        content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              );
            final now = DateTime.now();
            final monthDocs = snapshot.data!.docs.where((doc) {
              final data = doc.data();
              final stamp = data['createdAt'];
              return data['status'] == 'terminee' &&
                  stamp is Timestamp &&
                  stamp.toDate().year == now.year &&
                  stamp.toDate().month == now.month;
            });
            final total = monthDocs.fold<double>(0, (sum, doc) {
              final amount =
                  doc.data()['paidAmount'] ?? doc.data()['baseAmount'] ?? 0;
              return sum + (amount is num ? amount.toDouble() : 0);
            });
            return Text(
              '${monthDocs.length} interventions terminées\n\nChiffre d’affaires enregistré : ${total.toStringAsFixed(2)} TND',
              style: TextStyle(color: _textPrimary, height: 1.5),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _adminPageHeading({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onExport,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final heading = Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F4F2),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: const Color(0xFF0D756F)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DAR PLUS · CONSOLE ADMIN',
                      style: TextStyle(
                        color: Color(0xFF0D756F),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: compact ? 22 : 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                OutlinedButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download_rounded, size: 17),
                  label: const Text('Exporter'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () => _showNewAdminActionDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('admin_new_action'.tr()),
                ),
              ],
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (compact)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onExport,
                        icon: const Icon(Icons.download_rounded, size: 17),
                        label: const Text('Exporter'),
                      ),
                      FilledButton.icon(
                        onPressed: _showNewAdminActionDialog,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('admin_new_action'.tr()),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInterventionsAdminTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        final cutoff = _bookingPeriodFilter == '7 derniers jours'
            ? now.subtract(const Duration(days: 7))
            : _bookingPeriodFilter == '90 derniers jours'
            ? now.subtract(const Duration(days: 90))
            : now.subtract(const Duration(days: 30));
        var rows =
            docs.where((doc) {
              final data = doc.data();
              final status = (data['status'] ?? 'en_attente').toString();
              final search = _bookingSearch.toLowerCase();
              final haystack =
                  '${doc.id} ${data['clientName'] ?? ''} ${data['proName'] ?? ''} ${data['serviceTitle'] ?? data['category'] ?? ''}'
                      .toLowerCase();
              final rawDate =
                  data['scheduledAt'] ??
                  data['bookingDate'] ??
                  data['createdAt'];
              final date = rawDate is Timestamp
                  ? rawDate.toDate()
                  : rawDate is DateTime
                  ? rawDate
                  : null;
              return (_bookingStatusFilter == 'Tous les statuts' ||
                      status == _bookingStatusFilter) &&
                  (search.isEmpty || haystack.contains(search)) &&
                  (_bookingPeriodFilter == 'Toutes les dates' ||
                      date == null ||
                      !date.isBefore(cutoff));
            }).toList()..sort(
              (a, b) =>
                  (_bookingDate(b.data()) ??
                          DateTime.fromMillisecondsSinceEpoch(0))
                      .compareTo(
                        _bookingDate(a.data()) ??
                            DateTime.fromMillisecondsSinceEpoch(0),
                      ),
            );
        final count = rows.length;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _adminPageHeading(
                title: 'Interventions',
                subtitle:
                    'Suivez les réservations et leurs statuts en temps réel.',
                icon: Icons.calendar_month_outlined,
                onExport: _exportAdminBookings,
              ),
              Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  border: Border.all(color: _borderColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 340,
                            child: TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search_rounded),
                                hintText: 'Rechercher dans cette liste...',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) =>
                                  setState(() => _bookingSearch = v),
                            ),
                          ),
                          _filterDropdown(
                            _bookingStatusFilter,
                            [
                              'Tous les statuts',
                              'en_attente',
                              'acceptee',
                              'confirmee',
                              'terminee',
                              'annulee',
                            ],
                            (v) => setState(() => _bookingStatusFilter = v!),
                            labels: {
                              'en_attente': 'En attente',
                              'acceptee': 'Acceptée',
                              'confirmee': 'Confirmée',
                              'terminee': 'Terminée',
                              'annulee': 'Annulée',
                            },
                          ),
                          _filterDropdown(_bookingPeriodFilter, [
                            '7 derniers jours',
                            '30 derniers jours',
                            '90 derniers jours',
                            'Toutes les dates',
                          ], (v) => setState(() => _bookingPeriodFilter = v!)),
                        ],
                      ),
                    ),
                    if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Chargement des interventions impossible : ${snapshot.error}',
                        ),
                      )
                    else if (snapshot.connectionState ==
                        ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(),
                      )
                    else if (count == 0)
                      Padding(
                        padding: const EdgeInsets.all(36),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_busy_outlined,
                              size: 36,
                              color: _textSecondary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Aucune intervention trouvée.',
                              style: TextStyle(color: _textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('RÉFÉRENCE')),
                            DataColumn(label: Text('CLIENT')),
                            DataColumn(label: Text('PROFESSIONNEL')),
                            DataColumn(label: Text('SERVICE')),
                            DataColumn(label: Text('DATE')),
                            DataColumn(label: Text('MONTANT')),
                            DataColumn(label: Text('STATUT')),
                          ],
                          rows: rows.map((doc) {
                            final b = doc.data();
                            final date = _bookingDate(b);
                            final amount =
                                b['totalPrice'] ??
                                b['totalAmount'] ??
                                b['price'] ??
                                0;
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    'DP-${doc.id.substring(0, min(8, doc.id.length)).toUpperCase()}',
                                    style: const TextStyle(
                                      color: Color(0xFF0D756F),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onTap: () => _showBookingDetails(doc.id, b),
                                ),
                                DataCell(
                                  Text(
                                    (b['clientName'] ?? 'Client').toString(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    (b['proName'] ??
                                            b['professionalName'] ??
                                            'Non assigné')
                                        .toString(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    (b['serviceTitle'] ??
                                            b['category'] ??
                                            'Service')
                                        .toString(),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    date == null
                                        ? '—'
                                        : DateFormat(
                                            'dd MMM, HH:mm',
                                            'fr',
                                          ).format(date),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${amount is num ? amount.toStringAsFixed(0) : amount} TND',
                                  ),
                                ),
                                DataCell(
                                  _bookingStatusChip(
                                    (b['status'] ?? 'en_attente').toString(),
                                  ),
                                  onTap: () => _showBookingDetails(doc.id, b),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    if (snapshot.hasData)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$count résultat${count > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DateTime? _bookingDate(Map<String, dynamic> data) {
    final raw = data['scheduledAt'] ?? data['bookingDate'] ?? data['createdAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Widget _filterDropdown(
    String value,
    List<String> values,
    ValueChanged<String?> onChanged, {
    Map<String, String> labels = const {},
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      border: Border.all(color: _borderColor),
      borderRadius: BorderRadius.circular(10),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: values.contains(value) ? value : values.first,
        items: values
            .map((v) => DropdownMenuItem(value: v, child: Text(labels[v] ?? v)))
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );

  Widget _bookingStatusChip(String status) {
    final color = status == 'terminee'
        ? const Color(0xFF16805D)
        : status == 'annulee'
        ? const Color(0xFFCC3D4A)
        : status == 'acceptee' || status == 'confirmee'
        ? const Color(0xFF5967D9)
        : const Color(0xFFBA681B);
    final label =
        {
          'en_attente': 'En attente',
          'acceptee': 'Acceptée',
          'confirmee': 'Confirmée',
          'terminee': 'Terminée',
          'annulee': 'Annulée',
        }[status] ??
        status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _showBookingDetails(
    String id,
    Map<String, dynamic> b,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Wrap(
          runSpacing: 12,
          children: [
            Text(
              'Intervention DP-${id.substring(0, min(8, id.length)).toUpperCase()}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            for (final item in <String, dynamic>{
              'Client': b['clientName'] ?? 'Client',
              'Professionnel':
                  b['proName'] ?? b['professionalName'] ?? 'Non assigné',
              'Service': b['serviceTitle'] ?? b['category'] ?? 'Service',
              'Adresse': b['address'] ?? b['location'] ?? '—',
              'Date': _bookingDate(b) == null
                  ? '—'
                  : DateFormat('dd/MM/yyyy HH:mm').format(_bookingDate(b)!),
              'Statut': b['status'] ?? 'en_attente',
              'Montant':
                  '${b['totalPrice'] ?? b['totalAmount'] ?? b['price'] ?? 0} TND',
            }.entries)
              ListTile(
                title: Text(item.key),
                subtitle: Text(item.value.toString()),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _exportAdminBookings() async {
    try {
      final docs =
          (await FirebaseFirestore.instance.collection('bookings').get()).docs;
      final rows = <List<String>>[
        [
          'Référence',
          'Client',
          'Professionnel',
          'Service',
          'Date',
          'Montant',
          'Statut',
        ],
        ...docs.map((d) {
          final b = d.data();
          return [
            d.id,
            b['clientName']?.toString() ?? '',
            b['proName']?.toString() ?? '',
            b['serviceTitle']?.toString() ?? b['category']?.toString() ?? '',
            _bookingDate(b)?.toIso8601String() ?? '',
            (b['totalPrice'] ?? b['totalAmount'] ?? b['price'] ?? '')
                .toString(),
            b['status']?.toString() ?? '',
          ];
        }),
      ];
      await Clipboard.setData(
        ClipboardData(
          text: rows.map((r) => r.map(_csvCell).join(',')).join('\n'),
        ),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${docs.length} interventions copiées au format CSV.',
            ),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export impossible : $e')));
    }
  }

  Widget _buildPaymentsAdminTab() {
    return StreamBuilder<List<PaymentModel>>(
      stream: CommissionService().streamPayments(professionalOnly: false),
      builder: (context, snapshot) {
        final payments = (snapshot.data ?? const <PaymentModel>[])
            .where(
              (p) =>
                  (_paymentStatusFilter == 'Tous les statuts' ||
                      p.status.code == _paymentStatusFilter) &&
                  (_paymentSearch.isEmpty ||
                      '${p.id} ${p.clientName} ${p.proName} ${p.serviceType} ${p.transactionRef ?? ''}'
                          .toLowerCase()
                          .contains(_paymentSearch.toLowerCase())),
            )
            .toList();
        final successful = (snapshot.data ?? const <PaymentModel>[])
            .where((p) => p.isSuccess)
            .toList();
        final total = successful.fold<double>(0, (s, p) => s + p.totalAmount);
        final commission = successful.fold<double>(
          0,
          (s, p) => s + p.commissionAmount,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _adminPageHeading(
                title: 'Paiements & transactions',
                subtitle:
                    'Contrôlez les encaissements, commissions et versements.',
                icon: Icons.credit_card_outlined,
                onExport: _exportAdminPayments,
              ),
              if (snapshot.hasError)
                Text('Chargement des paiements impossible : ${snapshot.error}')
              else if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else ...[
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth < 650
                        ? c.maxWidth
                        : (c.maxWidth - 24) / 3;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _paymentStat(
                          'Paiements confirmés',
                          '${successful.length}',
                          'Données enregistrées',
                          w,
                        ),
                        _paymentStat(
                          'Montants payés',
                          '${total.toStringAsFixed(1)} TND',
                          'Paiements confirmés',
                          w,
                        ),
                        _paymentStat(
                          'Commissions comptabilisées',
                          '${commission.toStringAsFixed(1)} TND',
                          'Sur paiements confirmés',
                          w,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: _cardBg,
                    border: Border.all(color: _borderColor),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: 340,
                              child: TextField(
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'Rechercher une transaction...',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (v) =>
                                    setState(() => _paymentSearch = v),
                              ),
                            ),
                            _filterDropdown(
                              _paymentStatusFilter,
                              [
                                'Tous les statuts',
                                'succes',
                                'en_attente',
                                'echec',
                                'annule',
                              ],
                              (v) => setState(() => _paymentStatusFilter = v!),
                              labels: const {
                                'succes': 'Confirmé',
                                'en_attente': 'En attente',
                                'echec': 'Échoué',
                                'annule': 'Annulé',
                              },
                            ),
                          ],
                        ),
                      ),
                      if (payments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Aucune transaction trouvée.',
                            style: TextStyle(color: _textSecondary),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('RÉFÉRENCE')),
                              DataColumn(label: Text('UTILISATEUR')),
                              DataColumn(label: Text('MÉTHODE')),
                              DataColumn(label: Text('MONTANT')),
                              DataColumn(label: Text('COMMISSION')),
                              DataColumn(label: Text('DATE')),
                              DataColumn(label: Text('STATUT')),
                            ],
                            rows: payments
                                .map(
                                  (p) => DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          p.transactionRef ??
                                              (p.id.isEmpty ? '—' : p.id),
                                        ),
                                      ),
                                      DataCell(Text(p.clientName)),
                                      DataCell(Text(p.paymentMethod)),
                                      DataCell(
                                        Text(
                                          '${p.totalAmount.toStringAsFixed(1)} TND',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          p.isSuccess
                                              ? '${p.commissionAmount.toStringAsFixed(1)} TND'
                                              : '—',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          DateFormat(
                                            'dd MMM, HH:mm',
                                            'fr',
                                          ).format(p.createdAt),
                                        ),
                                      ),
                                      DataCell(_paymentStatusChip(p)),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${payments.length} transaction${payments.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _paymentStat(String title, String value, String foot, double width) =>
      SizedBox(
        width: width,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBg,
            border: Border.all(color: _borderColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(foot, style: TextStyle(color: _textSecondary, fontSize: 11)),
            ],
          ),
        ),
      );

  Widget _paymentStatusChip(PaymentModel p) {
    final c = p.isSuccess
        ? const Color(0xFF16805D)
        : p.isPending
        ? const Color(0xFFBA681B)
        : const Color(0xFFCC3D4A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        p.status.labelFr,
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Future<void> _exportAdminPayments() async {
    try {
      final ps = await CommissionService()
          .streamPayments(professionalOnly: false)
          .first;
      final rows = <List<String>>[
        [
          'Référence',
          'Client',
          'Professionnel',
          'Service',
          'Méthode',
          'Montant',
          'Commission',
          'Date',
          'Statut',
        ],
        ...ps.map(
          (p) => [
            p.transactionRef ?? p.id,
            p.clientName,
            p.proName,
            p.serviceType,
            p.paymentMethod,
            p.totalAmount.toStringAsFixed(3),
            p.commissionAmount.toStringAsFixed(3),
            p.createdAt.toIso8601String(),
            p.status.labelFr,
          ],
        ),
      ];
      await Clipboard.setData(
        ClipboardData(
          text: rows.map((r) => r.map(_csvCell).join(',')).join('\n'),
        ),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ps.length} transactions copiées au format CSV.'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export impossible : $e')));
    }
  }

  void _showNewAdminActionDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin_new_action'.tr()),
        content: const Text(
          'Choisissez la section à ouvrir pour effectuer une action administrative.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currentBottomNavIndex = 2);
            },
            child: Text('admin_validate_professional'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currentBottomNavIndex = 6);
            },
            child: const Text('Consulter les interventions'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currentBottomNavIndex = 7);
            },
            child: const Text('Consulter les paiements'),
          ),
        ],
      ),
    );
  }

  void _showInterventionsOverviewDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Toutes les interventions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('bookings')
                    .orderBy('createdAt', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucune réservation trouvée dans Firestore.',
                        style: TextStyle(color: _textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => Divider(color: _borderColor),
                    itemBuilder: (context, i) {
                      final b = docs[i].data();
                      final id = docs[i].id;
                      final s = b['serviceTitle'] ?? b['category'] ?? 'Service';
                      final status = b['status'] ?? 'en_attente';
                      final price = b['totalPrice'] ?? b['price'] ?? 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF0D544E)
                              .withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.handyman_rounded,
                            color: Color(0xFF0D544E),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          '$s (#${id.substring(0, min(6, id.length))})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Client: ${b['clientName'] ?? 'Client'} · Pro: ${b['proName'] ?? 'Pro'}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$price TND',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
                              ),
                            ),
                            Text(
                              status,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsAdminTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final all = snapshot.data?.docs ?? [];
        final reviews = all.where((doc) {
          final r = doc.data();
          final rating = (r['rating'] as num?)?.toInt() ?? 0;
          final haystack =
              '${r['reviewerName'] ?? r['clientName'] ?? ''} '
                      '${r['serviceType'] ?? ''} ${r['comment'] ?? ''} ${r['proId'] ?? ''}'
                  .toLowerCase();
          return (_reviewRatingFilter == 'Toutes les notes' ||
                  rating == int.tryParse(_reviewRatingFilter)) &&
              (_reviewSearch.isEmpty ||
                  haystack.contains(_reviewSearch.toLowerCase()));
        }).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _adminPageHeading(
                title: 'Avis clients',
                subtitle: 'Modérez les retours et protégez la qualité de la communauté.',
                icon: Icons.star_outline_rounded,
                onExport: _exportAdminReviews,
              ),
              Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  border: Border.all(color: _borderColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: 340,
                            child: TextField(
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search_rounded),
                                hintText: 'Rechercher dans cette liste...',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) =>
                                  setState(() => _reviewSearch = v),
                            ),
                          ),
                          _filterDropdown(
                            _reviewRatingFilter,
                            const ['Toutes les notes', '5', '4', '3', '2', '1'],
                            (v) => setState(() => _reviewRatingFilter = v!),
                            labels: const {
                              '5': '5 étoiles',
                              '4': '4 étoiles',
                              '3': '3 étoiles',
                              '2': '2 étoiles',
                              '1': '1 étoile',
                            },
                          ),
                        ],
                      ),
                    ),
                    if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Chargement des avis impossible : ${snapshot.error}',
                        ),
                      )
                    else if (snapshot.connectionState ==
                        ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(28),
                        child: CircularProgressIndicator(),
                      )
                    else if (reviews.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(36),
                        child: Column(
                          children: [
                            Icon(
                              Icons.rate_review_outlined,
                              size: 36,
                              color: _textSecondary,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              all.isEmpty
                                  ? 'Aucun avis enregistré.'
                                  : 'Aucun avis ne correspond aux filtres.',
                              style: TextStyle(color: _textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('AUTEUR')),
                            DataColumn(label: Text('PROFESSIONNEL')),
                            DataColumn(label: Text('NOTE')),
                            DataColumn(label: Text('COMMENTAIRE')),
                            DataColumn(label: Text('DATE')),
                            DataColumn(label: Text('ACTION')),
                          ],
                          rows: reviews.map((doc) {
                            final r = doc.data();
                            final author =
                                (r['reviewerName'] ??
                                        r['clientName'] ??
                                        'Utilisateur')
                                    .toString();
                            final rating =
                                (r['rating'] as num?)?.toDouble() ?? 0;
                            final date = r['createdAt'] is Timestamp
                                ? (r['createdAt'] as Timestamp).toDate()
                                : null;
                            final proId =
                                (r['targetRole'] == 'professionnel'
                                        ? r['targetId']
                                        : r['proId'])
                                    ?.toString() ??
                                '';
                            final proName =
                                r['professionalName'] ?? r['proName'];
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    author,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  proName != null
                                      ? Text(proName.toString())
                                      : proId.isEmpty
                                      ? const Text('—')
                                      : FutureBuilder<
                                          DocumentSnapshot<Map<String, dynamic>>
                                        >(
                                          future: FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(proId)
                                              .get(),
                                          builder: (context, userSnapshot) =>
                                              Text(
                                                userSnapshot.data
                                                        ?.data()?['fullName']
                                                        ?.toString() ??
                                                    'Professionnel',
                                              ),
                                        ),
                                ),
                                DataCell(
                                  Text(
                                    '${rating.toStringAsFixed(rating.truncateToDouble() == rating ? 0 : 1)} / 5',
                                    style: const TextStyle(
                                      color: Color(0xFFB96A00),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 300,
                                    child: Text(
                                      (r['comment'] ?? '').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    date == null
                                        ? '—'
                                        : DateFormat(
                                            'dd MMM yyyy',
                                            'fr',
                                          ).format(date),
                                  ),
                                ),
                                DataCell(
                                  OutlinedButton(
                                    onPressed: () =>
                                        _showReviewDetails(doc.id, r),
                                    child: const Text('Consulter'),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    if (snapshot.hasData)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${reviews.length} résultat${reviews.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReviewDetails(String id, Map<String, dynamic> review) {
    final author =
        (review['reviewerName'] ?? review['clientName'] ?? 'Utilisateur')
            .toString();
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final dateValue = review['createdAt'];
    final date = dateValue is Timestamp ? dateValue.toDate() : null;
    final proId =
        (review['targetRole'] == 'professionnel'
                ? review['targetId']
                : review['proId'])
            ?.toString() ??
        '';
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer le détail de l’avis',
      barrierColor: Colors.black.withValues(alpha: .3),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, _) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF7F8FA),
          child: SizedBox(
            width: min(480, MediaQuery.of(ctx).size.width),
            height: double.infinity,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Avis de $author',
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dossier d’évaluation',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _borderColor),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D544E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'APERÇU DE L’AVIS',
                              style: TextStyle(
                                color: Color(0xFF9AC8C1),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Avis de $author',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Évaluation laissée par un utilisateur de DAR PLUS.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _reviewDetailsCard([
                        ('Auteur', author),
                        (
                          'Professionnel',
                          proId.isEmpty
                              ? (review['proName']?.toString() ?? '—')
                              : proId,
                        ),
                        (
                          'Note',
                          '${rating.toStringAsFixed(rating.truncateToDouble() == rating ? 0 : 1)} / 5',
                        ),
                        (
                          'Commentaire',
                          (review['comment'] ?? 'Aucun commentaire').toString(),
                        ),
                        ('Service', (review['serviceType'] ?? '—').toString()),
                        (
                          'Date',
                          date == null
                              ? '—'
                              : DateFormat('dd MMMM yyyy', 'fr').format(date),
                        ),
                        ('Référence', id),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, animation, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    );
  }

  Widget _reviewDetailsCard(List<(String, String)> values) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: _cardBg,
      border: Border.all(color: _borderColor),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: values.indexed.map((entry) {
        final index = entry.$1;
        final item = entry.$2;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      item.$1,
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.$2,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index < values.length - 1)
              Divider(height: 1, color: _borderColor),
          ],
        );
      }).toList(),
    ),
  );

  Future<void> _exportAdminReviews() async {
    try {
      final docs =
          (await FirebaseFirestore.instance.collection('reviews').get()).docs;
      final rows = <List<String>>[
        [
          'Référence',
          'Auteur',
          'Professionnel',
          'Service',
          'Note',
          'Commentaire',
          'Date',
        ],
        ...docs.map((doc) {
          final r = doc.data();
          final date = r['createdAt'] is Timestamp
              ? (r['createdAt'] as Timestamp).toDate().toIso8601String()
              : '';
          return [
            doc.id,
            (r['reviewerName'] ?? r['clientName'] ?? '').toString(),
            (r['professionalName'] ??
                    r['proName'] ??
                    r['targetId'] ??
                    r['proId'] ??
                    '')
                .toString(),
            (r['serviceType'] ?? '').toString(),
            (r['rating'] ?? '').toString(),
            (r['comment'] ?? '').toString(),
            date,
          ];
        }),
      ];
      await Clipboard.setData(
        ClipboardData(
          text: rows.map((row) => row.map(_csvCell).join(',')).join('\n'),
        ),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${docs.length} avis copiés au format CSV.')),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export impossible : $error')));
    }
  }

  void _showReviewsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFDE6D1B)),
                    const SizedBox(width: 8),
                    Text(
                      'Avis & Évaluations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('reviews')
                    .orderBy('createdAt', descending: true)
                    .limit(30)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0D544E),
                      ),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucun avis enregistré.',
                        style: TextStyle(color: _textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => Divider(color: _borderColor),
                    itemBuilder: (context, i) {
                      final r = docs[i].data();
                      final name =
                          r['clientName'] ?? r['userName'] ?? 'Utilisateur';
                      final comment =
                          r['comment'] ?? r['review'] ?? r['text'] ?? '';
                      final rating = (r['rating'] ?? r['stars'] ?? 5.0)
                          .toDouble();
                      return _buildReviewTile(name, comment, rating);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewTile(String name, String comment, double rating) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE6F4F1),
        child: Text(
          initials,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D544E),
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        name,
        style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary),
      ),
      subtitle: Text(
        comment,
        style: TextStyle(color: _textSecondary, fontSize: 12.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(fontWeight: FontWeight.bold, color: _textPrimary),
          ),
        ],
      ),
    );
  }

  void _showPromotionsDialog() => setState(() => _currentBottomNavIndex = 9);

  Widget
  _buildPromotionsAdminTab() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('promotions').snapshots(),
    builder: (context, snapshot) {
      final docs = snapshot.data?.docs ?? [];
      final promos =
          docs.where((doc) {
            final p = doc.data();
            final code = (p['code'] ?? doc.id).toString();
            final search = '$code ${p['description'] ?? ''}'.toLowerCase();
            return (_promoSearch.isEmpty ||
                    search.contains(_promoSearch.toLowerCase())) &&
                (_promoStatusFilter == 'Tous les statuts' ||
                    _promoStatus(p) == _promoStatusFilter);
          }).toList()..sort(
            (a, b) =>
                (_promoDate(b.data(), 'createdAt') ??
                        DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                      _promoDate(a.data(), 'createdAt') ??
                          DateTime.fromMillisecondsSinceEpoch(0),
                    ),
          );
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _adminPageHeading(
              title: 'Coupons & promotions',
              subtitle: 'Créez et pilotez les offres commerciales DAR PLUS.',
              icon: Icons.local_offer_outlined,
              onExport: _exportPromotions,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton.icon(
                  onPressed: _showCreatePromoDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Créer un code promotionnel'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D544E),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _cardBg,
                border: Border.all(color: _borderColor),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 340,
                          child: TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search_rounded),
                              hintText: 'Rechercher dans cette liste...',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => setState(() => _promoSearch = v),
                          ),
                        ),
                        _filterDropdown(_promoStatusFilter, const [
                          'Tous les statuts',
                          'Actif',
                          'Planifié',
                          'Expiré',
                          'Inactif',
                        ], (v) => setState(() => _promoStatusFilter = v!)),
                      ],
                    ),
                  ),
                  if (snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Impossible de charger les promotions : ${snapshot.error}',
                      ),
                    )
                  else if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(),
                    )
                  else if (promos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(36),
                      child: Column(
                        children: [
                          Icon(
                            Icons.local_offer_outlined,
                            size: 36,
                            color: _textSecondary,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            docs.isEmpty ? 'Aucun code promotionnel créé.' : 'Aucune promotion ne correspond à ces filtres.',
                            style: TextStyle(color: _textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('CODE')),
                          DataColumn(label: Text('RÉDUCTION')),
                          DataColumn(label: Text('PÉRIODE DE VALIDITÉ')),
                          DataColumn(label: Text('UTILISATION')),
                          DataColumn(label: Text('STATUT')),
                          DataColumn(label: Text('ACTIONS')),
                        ],
                        rows: promos.map((doc) {
                          final p = doc.data();
                          final code = (p['code'] ?? doc.id).toString();
                          final discount = p['discount'];
                          final type = (p['type'] ?? 'percent').toString();
                          final status = _promoStatus(p);
                          final start =
                              _promoDate(p, 'startsAt') ??
                              _promoDate(p, 'startDate');
                          final end =
                              _promoDate(p, 'expiresAt') ??
                              _promoDate(p, 'endDate');
                          final used =
                              (p['usageCount'] ?? p['usedCount'] ?? 'Non suivi')
                                  .toString();
                          final maxUses = p['maxUses'] ?? p['usageLimit'];
                          final period = start == null && end == null
                              ? 'Sans expiration'
                              : '${start == null ? '' : DateFormat('dd/MM', 'fr').format(start)} – ${end == null ? 'Sans expiration' : DateFormat('dd/MM/yyyy', 'fr').format(end)}';
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0D756F),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '${discount ?? 0}${type == 'percent' ? ' %' : ' TND'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              DataCell(Text(period)),
                              DataCell(
                                Text(
                                  maxUses == null
                                      ? '$used utilisations'
                                      : '$used / $maxUses',
                                ),
                              ),
                              DataCell(_promoStatusChip(status)),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () =>
                                          _showEditPromoDialog(doc.id, p),
                                      child: const Text('Modifier'),
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinedButton(
                                      onPressed: () =>
                                          _confirmDeletePromo(doc.id, code),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(
                                          0xFFCC3344,
                                        ),
                                        side: const BorderSide(
                                          color: Color(0xFFF3B9C0),
                                        ),
                                      ),
                                      child: const Text('Supprimer'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  if (snapshot.hasData)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${promos.length} résultat${promos.length > 1 ? 's' : ''}',
                          style: TextStyle(color: _textSecondary, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  DateTime? _promoDate(Map<String, dynamic> promo, String field) {
    final value = promo[field];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _promoStatus(Map<String, dynamic> promo) {
    if (promo['isActive'] == false) return 'Inactif';
    final now = DateTime.now();
    final start =
        _promoDate(promo, 'startsAt') ?? _promoDate(promo, 'startDate');
    final end = _promoDate(promo, 'expiresAt') ?? _promoDate(promo, 'endDate');
    if (start != null && now.isBefore(start)) return 'Planifié';
    if (end != null && now.isAfter(end)) return 'Expiré';
    return 'Actif';
  }

  Widget _promoStatusChip(String status) {
    final color = status == 'Actif'
        ? const Color(0xFF16805D)
        : status == 'Planifié'
        ? const Color(0xFF5967D9)
        : status == 'Expiré'
        ? const Color(0xFFCC3D4A)
        : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _showEditPromoDialog(
    String id,
    Map<String, dynamic> promo,
  ) async {
    final code = TextEditingController(text: (promo['code'] ?? id).toString());
    final desc = TextEditingController(
      text: (promo['description'] ?? '').toString(),
    );
    final value = TextEditingController(
      text: (promo['discount'] ?? '').toString(),
    );
    final form = GlobalKey<FormState>();
    var type = (promo['type'] ?? 'percent').toString();
    var isActive = promo['isActive'] != false;
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text('admin_edit_promotion'.tr()),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v ?? '').trim().length < 3
                        ? 'Saisissez un code de 3 caractères minimum.'
                        : null,
                    decoration: const InputDecoration(labelText: 'Code'),
                  ),
                  TextFormField(
                    controller: desc,
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'La description est obligatoire.'
                        : null,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextFormField(
                    controller: value,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final number = double.tryParse(
                        (v ?? '').replaceAll(',', '.'),
                      );
                      return number == null ||
                              number <= 0 ||
                              !number.isFinite ||
                              (type == 'percent' && number > 100)
                          ? 'Valeur de réduction invalide.'
                          : null;
                    },
                    decoration: const InputDecoration(labelText: 'Réduction'),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'percent', label: Text('%')),
                      ButtonSegment(value: 'fixed', label: Text('TND')),
                    ],
                    selected: {type},
                    onSelectionChanged: (selected) =>
                        setDialog(() => type = selected.first),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('admin_promotion_active'.tr()),
                    value: isActive,
                    onChanged: (value) => setDialog(() => isActive = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(form.currentState?.validate() ?? false)) return;
                      final newCode = code.text.trim().toUpperCase();
                      setDialog(() => saving = true);
                      try {
                        final existing = await FirebaseFirestore.instance
                            .collection('promotions')
                            .where('code', isEqualTo: newCode)
                            .limit(1)
                            .get();
                        if (existing.docs.any((doc) => doc.id != id)) {
                          setDialog(() => saving = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ce code existe déjà.'),
                              ),
                            );
                          }
                          return;
                        }
                        await FirebaseFirestore.instance
                            .collection('promotions')
                            .doc(id)
                            .update({
                              'code': newCode,
                              'description': desc.text.trim(),
                              'discount': double.parse(
                                value.text.trim().replaceAll(',', '.'),
                              ),
                              'type': type,
                              'isActive': isActive,
                            });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Promotion modifiée.'),
                            ),
                          );
                        }
                      } catch (error) {
                        if (ctx.mounted) setDialog(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Modification impossible : $error'),
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    desc.dispose();
    value.dispose();
  }

  Future<void> _confirmDeletePromo(String id, String code) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin_delete_promotion_confirm'.tr()),
        content: Text('Le code $code ne pourra plus être utilisé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42335),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('promotions')
          .doc(id)
          .delete();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Promotion supprimée.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Suppression impossible : $e')));
    }
  }

  Future<void> _exportPromotions() async {
    try {
      final docs =
          (await FirebaseFirestore.instance.collection('promotions').get())
              .docs;
      final rows = <List<String>>[
        ['Code', 'Description', 'Reduction', 'Type', 'Utilisations', 'Statut'],
        ...docs.map((d) {
          final p = d.data();
          return [
            (p['code'] ?? d.id).toString(),
            (p['description'] ?? '').toString(),
            (p['discount'] ?? '').toString(),
            (p['type'] ?? '').toString(),
            (p['usageCount'] ?? p['usedCount'] ?? 'Non suivi').toString(),
            _promoStatus(p),
          ];
        }),
      ];
      await Clipboard.setData(
        ClipboardData(
          text: rows.map((r) => r.map(_csvCell).join(',')).join('\n'),
        ),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${docs.length} promotions copiées au format CSV.'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export impossible : $e')));
    }
  }

  void _showCreatePromoDialog() {
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController();
    final descController = TextEditingController();
    final discountController = TextEditingController();
    String promoType = 'percent';
    bool isCreating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Nouveau code promo',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeController,
                    validator: (value) => (value ?? '').trim().length < 3
                        ? 'promo_code_invalid'.tr()
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Code promo',
                      hintText: 'Ex: DARPLUS2026',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.local_offer_rounded),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'promo_description_required'.tr()
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Ex: 10% de réduction sur...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: discountController,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final discount = double.tryParse(
                              (value ?? '').trim().replaceAll(',', '.'),
                            );
                            if (discount == null ||
                                !discount.isFinite ||
                                discount <= 0) {
                              return 'promo_discount_invalid'.tr();
                            }
                            if (promoType == 'percent' && discount > 100) {
                              return 'promo_discount_percent_invalid'.tr();
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'Valeur',
                            hintText: 'Ex: 10',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.discount_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'percent', label: Text('%')),
                          ButtonSegment(value: 'fixed', label: Text('TND')),
                        ],
                        selected: {promoType},
                        onSelectionChanged: (val) =>
                            setDialogState(() => promoType = val.first),
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected))
                              return const Color(0xFF0D544E);
                            return null;
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: isCreating
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      final code = codeController.text.trim().toUpperCase();
                      final description = descController.text.trim();
                      final discount = double.tryParse(
                        discountController.text.trim().replaceAll(',', '.'),
                      );
                      if (discount == null) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final promotions = FirebaseFirestore.instance.collection(
                        'promotions',
                      );
                      setDialogState(() => isCreating = true);
                      try {
                        final existing = await promotions
                            .where('code', isEqualTo: code)
                            .limit(1)
                            .get();
                        if (!mounted || !ctx.mounted) return;
                        if (existing.docs.isNotEmpty) {
                          setDialogState(() => isCreating = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('promo_exists'.tr()),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }
                        await promotions.doc(code).set({
                          'code': code,
                          'description': description,
                          'discount': discount,
                          'type': promoType,
                          'isActive': true,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (!mounted || !ctx.mounted) return;
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('promo_created'.tr()),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      } catch (error) {
                        if (!mounted || !ctx.mounted) return;
                        setDialogState(() => isCreating = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '${'promo_create_error'.tr()} $error',
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
              ),
              child: isCreating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('promo_create_button'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignalementDetailDialog(
    String reportId,
    String title,
    String subtitle,
    String status,
    Color statusColor, [
    Map<String, dynamic>? reportData,
  ]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Détail du signalement',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_rounded, color: statusColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                  if ((reportData?['category']?.toString() ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Motif : ${reportData!['category']}',
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if ((reportData?['description']?.toString() ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      reportData!['description'].toString(),
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                  ],
                  if ((reportData?['bookingId']?.toString() ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Intervention : ${reportData!['bookingId']}',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Actions disponibles',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            if (status != 'Résolu') ...[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFECFDF5),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                title: Text('admin_mark_resolved'.tr()),
                subtitle: Text('admin_close_report'.tr()),
                onTap: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('reports')
                        .doc(reportId)
                        .update({
                          'status': 'Résolu',
                          'resolvedAt': FieldValue.serverTimestamp(),
                          'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
                        });
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Signalement marqué comme résolu.'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  } catch (error) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Impossible de résoudre le signalement : $error',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentNotifications() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: CommissionService().streamAdminPaymentNotifications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        final notifications = snapshot.data ?? const [];
        if (notifications.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFF0D544E),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nouveaux paiements en ligne',
                      style: TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context)
                            .pushNamed(AppRoutes.paymentTransactions),
                    child: const Text('Tout voir'),
                  ),
                ],
              ),
              ...notifications.take(3).map((notification) {
                final isRead = notification['isRead'] == true;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isRead
                        ? Icons.receipt_long_outlined
                        : Icons.fiber_new_rounded,
                    color: isRead ? _textSecondary : const Color(0xFF0D544E),
                  ),
                  title: Text(
                    notification['title'] as String? ??
                        'Paiement en ligne confirmé',
                    style: TextStyle(
                      color: _textPrimary,
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    notification['body'] as String? ?? '',
                    style: TextStyle(color: _textSecondary, fontSize: 11.5),
                  ),
                  onTap: isRead
                      ? null
                      : () => CommissionService().markNotificationRead(
                          notification['id'].toString(),
                        ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: _textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ================= TAB 1: GESTION DES CLIENTS (EXACT DESIGN MATCH TO MOCKUP) =================
  Widget _buildUsersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService().streamUsers(),
      builder: (context, snapshot) {
        final allUsers = snapshot.data ?? [];

        // Exclure l'administrateur connecté et ne garder que les clients
        var clients = allUsers.where((u) {
          final uEmail = (u['email'] as String? ?? '').toLowerCase().trim();
          if (uEmail == _currentAdminEmail.toLowerCase().trim()) return false;
          final role = (u['role'] as String? ?? 'client').toLowerCase();
          return role == 'client' || role.isEmpty;
        }).toList();

        // Filtre de recherche
        if (_clientSearchQuery.trim().isNotEmpty) {
          final q = _clientSearchQuery.toLowerCase();
          clients = clients.where((c) {
            final name = (c['fullName'] as String? ?? '').toLowerCase();
            final email = (c['email'] as String? ?? '').toLowerCase();
            final gov = (c['governorate'] as String? ?? '').toLowerCase();
            final id = (c['id'] as String? ?? '').toLowerCase();
            return name.contains(q) ||
                email.contains(q) ||
                gov.contains(q) ||
                id.contains(q);
          }).toList();
        }

        // Filtre de statut
        if (_clientFilterStatus == 'actif') {
          clients = clients.where((c) => c['isActive'] != false).toList();
        } else if (_clientFilterStatus == 'suspendu') {
          clients = clients.where((c) => c['isActive'] == false).toList();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1000;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 18,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Welcome Header (Gestion des clients)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DAR PLUS • CONSOLE ADMIN',
                              style: TextStyle(
                                color: Color(0xFF0D544E),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Gestion des clients',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Consultez et gérez les comptes clients de la plateforme.',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: _textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showExportDialog,
                            icon: const Icon(Icons.download_rounded, size: 17),
                            label: const Text('Exporter'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _textPrimary,
                              side: BorderSide(color: _borderColor),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _showQuickActionDialog,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text('admin_new_action'.tr()),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0D544E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 2. White Card Container containing Table
                  Container(
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: _isDark ? 0.2 : 0.02,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header: Title + Filter Search & Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Liste • Clients',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${clients.length} éléments affichés dans cette vue',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // Table search input
                                Container(
                                  width: isDesktop ? 220 : 150,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: _borderColor),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.search_rounded,
                                        size: 16,
                                        color: _textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: TextField(
                                          controller:
                                              _clientTableSearchController,
                                          onChanged: (val) => setState(
                                            () => _clientSearchQuery = val,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: _textPrimary,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                            hintText: 'Filtrer la liste...',
                                            hintStyle: TextStyle(
                                              fontSize: 12,
                                              color: _textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Filtres button
                                PopupMenuButton<String>(
                                  onSelected: (val) =>
                                      setState(() => _clientFilterStatus = val),
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'tous',
                                      child: Text('Tous les clients'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'actif',
                                      child: Text('Clients actifs'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'suspendu',
                                      child: Text('Clients suspendus'),
                                    ),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isDark
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: _borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.tune_rounded,
                                          size: 15,
                                          color: _textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Filtres',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: _textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Table View
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: isDesktop
                                  ? constraints.maxWidth - 44
                                  : 1060,
                            ),
                            child: Column(
                              children: [
                                // Headers Row
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: const [
                                      SizedBox(
                                        width: 230,
                                        child: Text(
                                          'UTILISATEUR',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          'TÉLÉPHONE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 130,
                                        child: Text(
                                          'RÔLE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 130,
                                        child: Text(
                                          'STATUT',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 140,
                                        child: Text(
                                          'INSCRIPTION',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 220,
                                        child: Text(
                                          'ACTIONS',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Data Rows
                                if (clients.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'Aucun client ne correspond à ces filtres.',
                                      style: TextStyle(
                                        color: _textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                else
                                  ...clients.map((client) {
                                    final name =
                                        (client['fullName'] as String? ??
                                                'Client')
                                            .trim();
                                    final phone = (client['phone'] ?? '—')
                                        .toString();
                                    final dateStr = _formatManagedClientDate(
                                      client['createdAt'],
                                    );
                                    final statusStr =
                                        (client['status'] ??
                                                (client['isActive'] == false
                                                    ? 'Suspendu'
                                                    : 'Active'))
                                            .toString();
                                    final isActive =
                                        client['isActive'] != false &&
                                        !statusStr.toLowerCase().contains(
                                          'suspend',
                                        );

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: _borderColor,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // 1. Profil (nom et email)
                                          SizedBox(
                                            width: 230,
                                            child: Row(
                                              children: [
                                                _buildUserInitialAvatar(
                                                  name,
                                                  client['photoUrl'] as String?,
                                                  client['photoBase64']
                                                      as String?,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: _textPrimary,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        (client['email'] ?? '—')
                                                            .toString(),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Color(
                                                            0xFF94A3B8,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // 2. Téléphone
                                          SizedBox(
                                            width: 150,
                                            child: Text(
                                              phone,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: _textSecondary,
                                              ),
                                            ),
                                          ),

                                          // 3. Rôle et modification réservée au super admin
                                          SizedBox(
                                            width: 130,
                                            child: Row(
                                              children: [
                                                const Text(
                                                  'Client',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                if (isSuperAdmin) ...[
                                                  const SizedBox(width: 6),
                                                  InkWell(
                                                    onTap: () =>
                                                        _showEditClientDialog(
                                                          client,
                                                        ),
                                                    child: const Text(
                                                      'Modifier',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Color(
                                                          0xFF0D544E,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),

                                          // 5. Statut
                                          SizedBox(
                                            width: 130,
                                            child: _buildClientStatusBadge(
                                              statusStr,
                                              isActive,
                                            ),
                                          ),

                                          // 5. Date d'inscription
                                          SizedBox(
                                            width: 140,
                                            child: Text(
                                              dateStr,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _textSecondary,
                                              ),
                                            ),
                                          ),

                                          // 6. Actions selon le rôle connecté
                                          SizedBox(
                                            width: 220,
                                            child: SizedBox(
                                              height: 36,
                                              child: Row(
                                                children: [
                                                  OutlinedButton(
                                                    onPressed: () =>
                                                        _showUserDetailsDialog(
                                                          client,
                                                        ),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor:
                                                          _textPrimary,
                                                      side: BorderSide(
                                                        color: _borderColor,
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'Consulter',
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (isActive || isSuperAdmin)
                                                    OutlinedButton(
                                                      onPressed: () =>
                                                          _setManagedClientStatus(
                                                            client,
                                                            isActive: isActive,
                                                          ),
                                                      style: OutlinedButton.styleFrom(
                                                        foregroundColor:
                                                            isActive
                                                            ? const Color(
                                                                0xFFDC2626,
                                                              )
                                                            : const Color(
                                                                0xFF0D544E,
                                                              ),
                                                        side: BorderSide(
                                                          color: isActive
                                                              ? const Color(
                                                                  0xFFFECACA,
                                                                )
                                                              : const Color(
                                                                  0xFFB6DDD6,
                                                                ),
                                                        ),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        isActive
                                                            ? 'Désactiver'
                                                            : 'Activer',
                                                      ),
                                                    ),
                                                  if (!isActive &&
                                                      !isSuperAdmin)
                                                    Text(
                                                      'Désactivé',
                                                      style: TextStyle(
                                                        color: _textSecondary,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Card Footer: résultats réellement affichés
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${clients.length} client${clients.length > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                              ),
                            ),
                            _buildPaginationButton('1', true, () {}),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ================= TAB 2: GESTION DES PROFESSIONNELS (EXACT DESIGN MATCH TO MOCKUP) =================
  Widget _buildValidationsTab(List<ProApplication> allList) {
    final pendingList = allList
        .where((app) => app.status == 'en_attente')
        .toList();
    final validatedList = allList
        .where((app) => app.status == 'valide')
        .toList();
    final rejectedList = allList
        .where((app) => app.status == 'refuse')
        .toList();
    final allServices =
        allList
            .map((app) => app.serviceType.trim())
            .where((service) => service.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final selectedServiceFilter = allServices.contains(_proServiceFilter)
        ? _proServiceFilter
        : 'Tous les métiers';

    var filtered = switch (_selectedValidationTab) {
      0 => pendingList,
      1 => validatedList,
      2 => rejectedList,
      _ => List<ProApplication>.from(allList),
    };
    if (selectedServiceFilter != 'Tous les métiers') {
      filtered = filtered
          .where((app) => app.serviceType == selectedServiceFilter)
          .toList();
    }
    final query = _proSearchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((app) {
        return app.fullName.toLowerCase().contains(query) ||
            app.serviceType.toLowerCase().contains(query) ||
            app.email.toLowerCase().contains(query) ||
            app.phone.toLowerCase().contains(query) ||
            (app.cin ?? '').toLowerCase().contains(query) ||
            app.id.toLowerCase().contains(query);
      }).toList();
    }
    filtered.sort(
      (a, b) => _proNewestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );

    const pageSize = 10;
    final resultCount = filtered.length;
    final pageCount = max(1, (resultCount + pageSize - 1) ~/ pageSize);
    final currentPage = _proCurrentPage.clamp(1, pageCount).toInt();
    final startIndex = (currentPage - 1) * pageSize;
    final pageItems = filtered.skip(startIndex).take(pageSize).toList();
    final firstResult = resultCount == 0 ? 0 : startIndex + 1;
    final lastResult = startIndex + pageItems.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 18,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DAR PLUS • CONSOLE ADMIN',
                          style: TextStyle(
                            color: Color(0xFF0D544E),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gestion des professionnels',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Validez les profils et suivez les candidatures.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: _textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDesktop)
                    OutlinedButton.icon(
                      onPressed: _showExportDialog,
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: const Text('Exporter'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSubTabFilterPill(
                            index: 0,
                            label: 'Demandes à valider (${pendingList.length})',
                            isSelected: _selectedValidationTab == 0,
                          ),
                          _buildSubTabFilterPill(
                            index: 1,
                            label: 'Approuvés (${validatedList.length})',
                            isSelected: _selectedValidationTab == 1,
                          ),
                          _buildSubTabFilterPill(
                            index: 2,
                            label: 'Refusés (${rejectedList.length})',
                            isSelected: _selectedValidationTab == 2,
                          ),
                          _buildSubTabFilterPill(
                            index: 3,
                            label: 'Tous (${allList.length})',
                            isSelected: _selectedValidationTab == 3,
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: _borderColor),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: isDesktop ? 320 : constraints.maxWidth - 68,
                            height: 40,
                            child: TextField(
                              controller: _proTableSearchController,
                              onChanged: (value) => setState(() {
                                _proSearchQuery = value;
                                _proCurrentPage = 1;
                              }),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search_rounded),
                                hintText: 'Rechercher un professionnel...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedServiceFilter,
                              items: [
                                const DropdownMenuItem(
                                  value: 'Tous les métiers',
                                  child: Text('Tous les métiers'),
                                ),
                                ...allServices.map(
                                  (service) => DropdownMenuItem(
                                    value: service,
                                    child: Text(service),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _proServiceFilter = value;
                                  _proCurrentPage = 1;
                                });
                              },
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<bool>(
                              value: _proNewestFirst,
                              items: const [
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('Plus récents'),
                                ),
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('Plus anciens'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _proNewestFirst = value;
                                  _proCurrentPage = 1;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: _borderColor),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: max(constraints.maxWidth - 36, 1140),
                        ),
                        child: Column(
                          children: [
                            Container(
                              color: _isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF8FAFC),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: const Row(
                                children: [
                                  _ProTableHeader('PROFESSIONNEL', 230),
                                  _ProTableHeader('MÉTIER', 150),
                                  _ProTableHeader('COORDONNÉES', 210),
                                  _ProTableHeader('DATE DE DEMANDE', 150),
                                  _ProTableHeader('STATUT', 140),
                                  _ProTableHeader('DÉCISION', 260),
                                ],
                              ),
                            ),
                            if (pageItems.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  allList.isEmpty
                                      ? 'Aucune candidature professionnelle enregistrée.'
                                      : 'Aucune candidature ne correspond à ces filtres.',
                                  style: TextStyle(color: _textSecondary),
                                ),
                              )
                            else
                              ...pageItems.map((app) {
                                final isPending = app.status == 'en_attente';
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: _borderColor),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 230,
                                        child: Row(
                                          children: [
                                            _buildUserInitialAvatar(
                                              app.fullName,
                                              null,
                                              null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    app.fullName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: _textPrimary,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    app.id,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: _textSecondary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          app.serviceType,
                                          style: TextStyle(
                                            color: _textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 210,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              app.phone.isEmpty
                                                  ? 'Téléphone non renseigné'
                                                  : app.phone,
                                              style: TextStyle(
                                                color: _textPrimary,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              app.email,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: _textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          _formatProApplicationDate(
                                            app.createdAt,
                                          ),
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 140,
                                        child: _buildProStatusPill(app.status),
                                      ),
                                      SizedBox(
                                        width: 260,
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            OutlinedButton(
                                              onPressed: () =>
                                                  _showExamineProApplicationSheet(
                                                    app,
                                                  ),
                                              child: const Text('Examiner'),
                                            ),
                                            if (isPending) ...[
                                              FilledButton(
                                                onPressed: () =>
                                                    _showApproveProDialog(app),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF0D544E,
                                                  ),
                                                ),
                                                child: const Text('Approuver'),
                                              ),
                                              OutlinedButton(
                                                onPressed: () =>
                                                    _showRejectProDialog(app),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(
                                                    0xFFDC2626,
                                                  ),
                                                  side: const BorderSide(
                                                    color: Color(0xFFFECACA),
                                                  ),
                                                ),
                                                child: const Text('Refuser'),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: _borderColor),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$firstResult–$lastResult sur $resultCount résultat${resultCount > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Row(
                            children: [
                              _buildPaginationButton(
                                '‹',
                                currentPage == 1,
                                currentPage > 1
                                    ? () => setState(
                                        () => _proCurrentPage = currentPage - 1,
                                      )
                                    : () {},
                              ),
                              const SizedBox(width: 6),
                              _buildPaginationButton(
                                '$currentPage/$pageCount',
                                true,
                                () {},
                              ),
                              const SizedBox(width: 6),
                              _buildPaginationButton(
                                '›',
                                currentPage == pageCount,
                                currentPage < pageCount
                                    ? () => setState(
                                        () => _proCurrentPage = currentPage + 1,
                                      )
                                    : () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatProApplicationDate(DateTime value) {
    final date = value.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€ PRO EXAMINATION MODAL WITH VALIDATION BUTTONS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showExamineProApplicationSheet(ProApplication app) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    if (isDesktop) {
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Fermer le dossier professionnel',
        barrierColor: Colors.black.withValues(alpha: 0.32),
        pageBuilder: (dialogContext, animation, secondaryAnimation) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: _cardBg,
            child: SizedBox(
              width: 500,
              height: double.infinity,
              child: _buildProfessionalDetails(app, dialogContext),
            ),
          ),
        ),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        height: MediaQuery.sizeOf(context).height * 0.9,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _buildProfessionalDetails(app, sheetContext),
      ),
    );
  }

  Widget _buildProfessionalDetails(
    ProApplication app,
    BuildContext panelContext,
  ) {
    final isPending = app.status == 'en_attente';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.fullName,
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dossier professionnel · ${app.id}',
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(panelContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0D544E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CANDIDATURE',
                    style: TextStyle(
                      color: Color(0xFFBDE5DE),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    app.serviceType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Informations enregistrées lors de la demande.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informations',
                          style: TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          Icons.person_outline,
                          'Nom',
                          app.fullName,
                        ),
                        const Divider(height: 18),
                        _buildDetailRow(
                          Icons.work_outline,
                          'Métier',
                          app.serviceType,
                        ),
                        const Divider(height: 18),
                        _buildDetailRow(
                          Icons.alternate_email,
                          'Email',
                          app.email,
                        ),
                        const Divider(height: 18),
                        _buildDetailRow(
                          Icons.phone_outlined,
                          'Téléphone',
                          app.phone.isEmpty ? 'Non renseigné' : app.phone,
                        ),
                        const Divider(height: 18),
                        _buildDetailRow(
                          Icons.badge_outlined,
                          'Numéro CIN',
                          app.cin?.isNotEmpty == true
                              ? app.cin!
                              : 'Non renseigné',
                        ),
                        const Divider(height: 18),
                        _buildDetailRow(
                          Icons.calendar_today_outlined,
                          'Date de demande',
                          _formatProApplicationDate(app.createdAt),
                        ),
                        const Divider(height: 18),
                        _buildDetailRow(
                          Icons.info_outline,
                          'Statut',
                          app.status == 'valide'
                              ? 'Approuvé'
                              : (app.status == 'refuse'
                                    ? 'Refusé'
                                    : 'À valider'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildProfessionalInfoCard(
                    title: 'Pièces justificatives',
                    icon: Icons.folder_open_outlined,
                    body: 'Aucun fichier joint à cette candidature. Le formulaire recueille le numéro CIN, mais ne demande pas de document à téléverser.',
                  ),
                  if (app.notes?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    _buildProfessionalInfoCard(
                      title: 'Notes du candidat',
                      icon: Icons.notes_rounded,
                      body: app.notes!.trim(),
                    ),
                  ],
                  if (app.rejectionReason?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    _buildProfessionalInfoCard(
                      title: 'Motif du refus',
                      icon: Icons.info_outline_rounded,
                      body: app.rejectionReason!.trim(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(panelContext);
                        _showRejectProDialog(app);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(panelContext);
                        _showApproveProDialog(app);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D544E),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Approuver'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(panelContext),
                  child: const Text('Fermer'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalInfoCard({
    required String title,
    required IconData icon,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0D544E), size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widgets for table
  Widget _buildUserInitialAvatar(
    String name,
    String? photoUrl,
    String? photoBase64, {
    double radius = 17,
  }) {
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE2E8F0),
        backgroundImage: NetworkImage(photoUrl.trim()),
      );
    }
    if (photoBase64 != null && photoBase64.trim().isNotEmpty) {
      try {
        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFFE2E8F0),
          backgroundImage: MemoryImage(base64Decode(photoBase64.trim())),
        );
      } catch (_) {}
    }

    // Deterministic color
    final colors = [
      const Color(0xFF0D544E),
      const Color(0xFFDE6D1B),
      const Color(0xFF4338CA),
      const Color(0xFF059669),
      const Color(0xFF0284C7),
      const Color(0xFFD97706),
      const Color(0xFF7C3AED),
      const Color(0xFFE11D48),
      const Color(0xFF0891B2),
      const Color(0xFF475569),
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = (hash * 31 + name.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final color = colors[name.isEmpty ? 0 : (hash % colors.length)];

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        _getInitials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.72,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildClientStatusBadge(String statusStr, bool isActive) {
    Color bg = const Color(0xFFECFDF5);
    Color dot = const Color(0xFF10B981);
    Color text = const Color(0xFF10B981);
    String label = 'Actif';

    if (statusStr.toLowerCase().contains('cours')) {
      bg = const Color(0xFFFEF3C7);
      dot = const Color(0xFFD97706);
      text = const Color(0xFFD97706);
      label = 'En cours';
    } else if (statusStr.toLowerCase().contains('traiter')) {
      bg = const Color(0xFFFFF1F2);
      dot = const Color(0xFFE11D48);
      text = const Color(0xFFE11D48);
      label = 'À traiter';
    } else if (!isActive || statusStr.toLowerCase().contains('suspend')) {
      bg = const Color(0xFFFEF2F2);
      dot = const Color(0xFFEF4444);
      text = const Color(0xFFEF4444);
      label = 'Suspendu';
    } else if (statusStr.toLowerCase().contains('valid')) {
      bg = const Color(0xFFECFDF5);
      dot = const Color(0xFF10B981);
      text = const Color(0xFF10B981);
      label = 'Validé';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProStatusPill(String status) {
    Color bg = const Color(0xFFFEF3C7);
    Color dot = const Color(0xFFD97706);
    Color text = const Color(0xFFD97706);
    String label = 'En attente';

    if (status == 'valide') {
      bg = const Color(0xFFECFDF5);
      dot = const Color(0xFF10B981);
      text = const Color(0xFF10B981);
      label = 'Validé';
    } else if (status == 'refuse') {
      bg = const Color(0xFFFEF2F2);
      dot = const Color(0xFFEF4444);
      text = const Color(0xFFEF4444);
      label = 'Refusé';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabFilterPill({
    required int index,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedValidationTab = index;
        _proCurrentPage = 1;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D544E) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : _textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationButton(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0D544E)
              : (_isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D544E) : _borderColor,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : _textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    final categories = _adminCategories
        .where(
          (category) => (category['name'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_categorySearch.toLowerCase()),
        )
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _adminPageHeading(
            title: 'Catégories de services',
            subtitle: 'Structurez le catalogue et contrôlez la disponibilité des services.',
            icon: Icons.layers_outlined,
            onExport: _exportCategories,
          ),
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 340,
                        child: TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Rechercher dans cette liste...',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) =>
                              setState(() => _categorySearch = value),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _showAddCategoryDialog,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Ajouter une catégorie'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D544E),
                        ),
                      ),
                    ],
                  ),
                ),
                if (categories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _adminCategories.isEmpty
                          ? 'Aucune catégorie enregistrée.'
                          : 'Aucune catégorie ne correspond à la recherche.',
                      style: TextStyle(color: _textSecondary),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('CATÉGORIE')),
                        DataColumn(label: Text('PROFESSIONNELS')),
                        DataColumn(label: Text('STATUT')),
                        DataColumn(label: Text('ACTIONS')),
                      ],
                      rows: categories.map((cat) {
                        final name = (cat['name'] ?? 'Catégorie').toString();
                        final active = cat['isActive'] == true;
                        final pros = _categoryProfessionalCount(name);
                        final deletable = pros == 0;
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color:
                                          (cat['bgColor'] as Color? ??
                                          const Color(0xFFE7F4F2)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getInitials(name),
                                      style: TextStyle(
                                        color:
                                            cat['iconColor'] as Color? ??
                                            const Color(0xFF0D756F),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                '$pros ${pros == 1 ? 'professionnel' : 'professionnels'}',
                              ),
                            ),
                            DataCell(_categoryStatusChip(active)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OutlinedButton(
                                    onPressed: () =>
                                        _showEditCategoryDialog(cat),
                                    child: const Text('Modifier'),
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton(
                                    onPressed: () =>
                                        _toggleAdminCategory(cat, !active),
                                    child: Text(
                                      active ? 'Désactiver' : 'Activer',
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton(
                                    onPressed: deletable
                                        ? () => _confirmDeleteCategory(cat)
                                        : null,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFCC3344),
                                      side: const BorderSide(
                                        color: Color(0xFFF3B9C0),
                                      ),
                                    ),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${categories.length} résultat${categories.length > 1 ? 's' : ''}',
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _categoryNameExists(String name, {String? exceptId}) {
    final normalized = name.trim().toLowerCase();
    return _adminCategories.any(
      (category) =>
          category['id']?.toString() != exceptId &&
          (category['name'] ?? '').toString().trim().toLowerCase() ==
              normalized,
    );
  }

  int _categoryProfessionalCount(String categoryName) {
    final category = categoryName.trim().toLowerCase();
    return _dashboardUsers.where((user) {
      if (user['role'] != 'professionnel' || user['isApproved'] != true)
        return false;
      final service = (user['serviceType'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return service == category ||
          (service.isNotEmpty &&
              (service.contains(category) || category.contains(service)));
    }).length;
  }

  Widget _categoryStatusChip(bool active) {
    final color = active ? const Color(0xFF16805D) : const Color(0xFF64748B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Actif' : 'Inactif',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _toggleAdminCategory(
    Map<String, dynamic> category,
    bool active,
  ) async {
    if (!canManageCategories) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Action non autorisée.')));
      return;
    }
    final ok = await FirebaseService().toggleCategoryStatus(
      category['id'].toString(),
      active,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de modifier le statut.')),
      );
      return;
    }
    setState(() => category['isActive'] = active);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Catégorie ${active ? 'activée' : 'désactivée'}.'),
      ),
    );
  }

  Future<void> _confirmDeleteCategory(Map<String, dynamic> category) async {
    if (!canManageCategories) return;
    final name = (category['name'] ?? 'cette catégorie').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin_delete_category_confirm'.tr()),
        content: Text('Voulez-vous vraiment supprimer « $name » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42335),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_categoryProfessionalCount(name) > 0) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cette catégorie est utilisée par des professionnels. Désactivez-la plutôt que de la supprimer.',
            ),
          ),
        );
      return;
    }
    final deleted = await FirebaseService().deleteCategory(
      category['id'].toString(),
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deleted ? 'Catégorie supprimée.' : 'Suppression impossible.',
          ),
        ),
      );
  }

  Future<void> _exportCategories() async {
    final rows = <List<String>>[
      ['Catégorie', 'Professionnels approuvés', 'Statut'],
      ..._adminCategories.map((cat) {
        final name = (cat['name'] ?? '').toString();
        return [
          name,
          _categoryProfessionalCount(name).toString(),
          cat['isActive'] == true ? 'Actif' : 'Inactif',
        ];
      }),
    ];
    await Clipboard.setData(
      ClipboardData(
        text: rows.map((row) => row.map(_csvCell).join(',')).join('\n'),
      ),
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_adminCategories.length} catégories copiées au format CSV.',
          ),
        ),
      );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'P';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  // ================= TAB 4: PROFIL ADMIN (MODIFIER PROFIL & LOGOUT) =================
  Widget _buildAdminProfileTab() {
    final tabs = <(String, IconData)>[
      ('Profil', Icons.person_outline_rounded),
      ('Préférences', Icons.tune_rounded),
      ('Sécurité', Icons.lock_outline_rounded),
      if (isSuperAdmin)
        ('Administrateurs', Icons.admin_panel_settings_outlined),
      if (isSuperAdmin) ('Paramètres globaux', Icons.settings_suggest_outlined),
    ];
    if (_settingsTabIndex >= tabs.length) _settingsTabIndex = 0;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAR PLUS • CONSOLE ADMIN',
                  style: TextStyle(
                    color: Color(0xFF0D756F),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Paramètres',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configurez votre profil, vos préférences et les accès de la plateforme.',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(tabs.length, (index) {
                      final active = _settingsTabIndex == index;
                      return InkWell(
                        onTap: () => setState(() => _settingsTabIndex = index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: active
                                    ? const Color(0xFF0D756F)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tabs[index].$2,
                                size: 16,
                                color: active
                                    ? const Color(0xFF0D756F)
                                    : _textSecondary,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                tabs[index].$1,
                                style: TextStyle(
                                  color: active
                                      ? const Color(0xFF0D756F)
                                      : _textSecondary,
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Divider(height: 1, color: _borderColor),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: switch (_settingsTabIndex) {
                    0 => _buildSettingsProfile(),
                    1 => _buildSettingsPreferences(),
                    2 => _buildSettingsSecurity(),
                    3 when isSuperAdmin => _buildSettingsAdministrators(),
                    4 when isSuperAdmin => _buildSettingsGlobal(),
                    _ => _buildSettingsProfile(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsProfile() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 700;
        final fields = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 22,
              runSpacing: 18,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFEADBD2),
                  backgroundImage: _adminPhotoBase64?.isNotEmpty == true
                      ? MemoryImage(base64Decode(_adminPhotoBase64!))
                      : null,
                  child: _adminPhotoBase64?.isNotEmpty == true
                      ? null
                      : Text(
                          _getInitials(_currentAdminName),
                          style: const TextStyle(
                            color: Color(0xFF8A4D38),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentAdminName,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isSuperAdmin ? 'Super administratrice' : 'Administrateur',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _showAdminPhotoPickerSheet,
                      icon: const Icon(Icons.photo_camera_outlined, size: 16),
                      label: const Text('Changer la photo'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: wide
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth,
                  child: _settingsTextField(
                    _settingsNameController,
                    'Nom complet',
                  ),
                ),
                SizedBox(
                  width: wide
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth,
                  child: _settingsTextField(
                    _settingsEmailController,
                    'E-mail',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                SizedBox(
                  width: wide
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth,
                  child: _settingsTextField(
                    _settingsPhoneController,
                    'Téléphone',
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [
                FilledButton(
                  onPressed: _settingsSaving ? null : _saveSettingsProfile,
                  child: _settingsSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
                OutlinedButton(
                  onPressed: _handleLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB42335),
                    side: const BorderSide(color: Color(0xFFF3B7BD)),
                  ),
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ],
        );
        return fields;
      },
    );
  }

  Widget _settingsTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscure = false,
  }) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscure,
    style: TextStyle(color: _textPrimary, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: _borderColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );

  Future<void> _saveSettingsProfile() async {
    final name = _settingsNameController.text.trim();
    final email = _settingsEmailController.text.trim();
    final phone = _settingsPhoneController.text.trim();
    if (name.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vérifiez le nom et l’adresse e-mail.')),
      );
      return;
    }
    setState(() => _settingsSaving = true);
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      final emailChanged =
          authUser?.email != null &&
          authUser!.email!.toLowerCase() != email.toLowerCase();
      if (emailChanged) {
        await authUser!.verifyBeforeUpdateEmail(email);
      }
      final saved = await FirebaseService().updateCurrentUserData(
        fullName: name,
        phone: phone,
      );
      if (!saved) throw Exception('Enregistrement du profil impossible.');
      if (mounted) {
        setState(() {
          _currentAdminName = name;
          if (!emailChanged) _currentAdminEmail = email;
          _currentAdminPhone = phone;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              emailChanged
                  ? 'Profil enregistré. Confirmez la nouvelle adresse avec le lien envoyé par e-mail.'
                  : 'Profil enregistré.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enregistrement impossible : $error')),
        );
    } finally {
      if (mounted) setState(() => _settingsSaving = false);
    }
  }

  Widget _buildSettingsPreferences() {
    final theme = context.watch<ThemeProvider>().themeMode;
    _settingsThemeMode = theme;
    _settingsLanguage = context.locale.languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 480,
          child: DropdownButtonFormField<String>(
            value: _settingsLanguage,
            decoration: InputDecoration(
              labelText: 'admin_interface_language'.tr(),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'fr', child: Text('Français')),
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ar', child: Text('العربية')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _settingsLanguage = value);
            },
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: 480,
          child: DropdownButtonFormField<ThemeMode>(
            value: _settingsThemeMode,
            decoration: InputDecoration(
              labelText: 'admin_theme'.tr(),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: ThemeMode.light, child: Text('Clair')),
              DropdownMenuItem(value: ThemeMode.dark, child: Text('Sombre')),
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('Selon l’appareil'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _settingsThemeMode = value);
            },
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () async {
            await context.read<LocaleProvider>().setLocale(
              Locale(_settingsLanguage),
              context,
            );
            await context.read<ThemeProvider>().setThemeMode(
              _settingsThemeMode,
            );
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Préférences appliquées et enregistrées.'),
                ),
              );
          },
          child: Text('admin_apply_preferences'.tr()),
        ),
      ],
    );
  }

  Widget _buildSettingsSecurity() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 580,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Modifier le mot de passe',
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            _settingsTextField(
              _settingsCurrentPasswordController,
              'Mot de passe actuel',
              obscure: true,
            ),
            const SizedBox(height: 12),
            _settingsTextField(
              _settingsNewPasswordController,
              'Nouveau mot de passe',
              obscure: true,
            ),
            const SizedBox(height: 12),
            _settingsTextField(
              _settingsConfirmPasswordController,
              'Confirmer le mot de passe',
              obscure: true,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _settingsSaving ? null : _saveSettingsPassword,
              child: _settingsSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Mettre à jour'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettingsPassword() async {
    final next = _settingsNewPasswordController.text;
    if (next.length < 6 || next != _settingsConfirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vérifiez le nouveau mot de passe et sa confirmation (6 caractères minimum).',
          ),
        ),
      );
      return;
    }
    setState(() => _settingsSaving = true);
    try {
      final result = await FirebaseService().changePassword(
        currentPassword: _settingsCurrentPasswordController.text,
        newPassword: next,
      );
      if (result['success'] != true)
        throw Exception(result['message'] ?? 'Modification impossible.');
      _settingsCurrentPasswordController.clear();
      _settingsNewPasswordController.clear();
      _settingsConfirmPasswordController.clear();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mot de passe modifié.')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Modification impossible : $error')),
        );
    } finally {
      if (mounted) setState(() => _settingsSaving = false);
    }
  }

  Widget _buildSettingsAdministrators() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comptes administrateurs',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Accès réservé au super administrateur.',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _showNewAdminDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Créer un compte'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService().streamUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Text(
              'Chargement des comptes impossible : ${snapshot.error}',
            );
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final admins =
              snapshot.data!.where((user) => user['role'] == 'admin').toList()
                ..sort(
                  (a, b) => (a['fullName'] ?? '').toString().compareTo(
                    (b['fullName'] ?? '').toString(),
                  ),
                );
          if (admins.isEmpty)
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Aucun compte administrateur.',
                  style: TextStyle(color: _textSecondary),
                ),
              ),
            );
          return Column(
            children: admins.map((user) {
              final name = (user['fullName'] ?? 'Administrateur').toString();
              final email = (user['email'] ?? '').toString();
              final active = user['isActive'] != false;
              final uid = (user['uid'] ?? user['id'] ?? '').toString();
              final statusColor = active
                  ? const Color(0xFF16805D)
                  : const Color(0xFF64748B);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: _borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE8F3F1),
                      child: Text(
                        _getInitials(name),
                        style: const TextStyle(
                          color: Color(0xFF0D756F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            email,
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        active ? 'Actif' : 'Inactif',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: uid.isEmpty
                          ? null
                          : () => _showAdminAccessDialog(
                              uid: uid,
                              name: name,
                              email: email,
                              active: active,
                            ),
                      child: const Text('Gérer'),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    ],
  );

  Future<void> _showAdminAccessDialog({
    required String uid,
    required String name,
    required String email,
    required bool active,
  }) async {
    if (!isSuperAdmin) return;
    var nextActive = active;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(name),
          content: SwitchListTile(
            value: nextActive,
            title: Text('admin_account_active'.tr()),
            onChanged: (value) => setDialogState(() => nextActive = value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (save != true || nextActive == active) return;
    final updated = await FirebaseService().toggleUserStatus(
      uid,
      email,
      active,
      _currentAdminEmail,
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated
                ? 'Statut du compte mis à jour.'
                : 'Impossible de modifier ce compte.',
          ),
        ),
      );
  }

  Widget _buildSettingsGlobal() => StreamBuilder<Map<String, dynamic>>(
    stream: FirebaseService().streamGlobalSettings(),
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return Text('Chargement des paramètres impossible : ${snapshot.error}');
      if (snapshot.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      final stored = snapshot.data ?? const <String, dynamic>{};
      var manualApproval = stored['requireProfessionalApproval'] != false;
      var maintenance = stored['maintenanceMode'] == true;
      var operationalNotifications =
          stored['operationalNotifications'] != false;
      return StatefulBuilder(
        builder: (ctx, setPanelState) {
          Widget settingSwitch(
            String title,
            String description,
            bool value,
            ValueChanged<bool?> onChanged,
          ) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CheckboxListTile(
              controlAffinity: ListTileControlAffinity.trailing,
              title: Text(
                title,
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                description,
                style: TextStyle(color: _textSecondary, fontSize: 11),
              ),
              value: value,
              activeColor: const Color(0xFF0D756F),
              onChanged: onChanged,
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configuration de la plateforme',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    settingSwitch(
                      'Validation manuelle des professionnels',
                      'Les nouveaux profils professionnels attendent une validation administrative.',
                      manualApproval,
                      (v) {
                        if (v != null) setPanelState(() => manualApproval = v);
                      },
                    ),
                    settingSwitch(
                      'Mode maintenance',
                      'Bloquez temporairement l’accès aux fonctions de la plateforme.',
                      maintenance,
                      (v) {
                        if (v != null) setPanelState(() => maintenance = v);
                      },
                    ),
                    settingSwitch(
                      'Notifications opérationnelles',
                      'Autorisez les notifications liées aux opérations de la plateforme.',
                      operationalNotifications,
                      (v) {
                        if (v != null) {
                          setPanelState(() => operationalNotifications = v);
                        }
                      },
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: _settingsSaving
                            ? null
                            : () async {
                                setState(() => _settingsSaving = true);
                                try {
                                  final ok = await FirebaseService()
                                      .updateGlobalSettings({
                                        'requireProfessionalApproval':
                                            manualApproval,
                                        'maintenanceMode': maintenance,
                                        'operationalNotifications':
                                            operationalNotifications,
                                      }, actorEmail: _currentAdminEmail);
                                  if (!ok)
                                    throw Exception('Enregistrement refusé.');
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Configuration enregistrée.',
                                        ),
                                      ),
                                    );
                                } catch (error) {
                                  if (mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Enregistrement impossible : $error',
                                        ),
                                      ),
                                    );
                                } finally {
                                  if (mounted)
                                    setState(() => _settingsSaving = false);
                                }
                              },
                        child: _settingsSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Enregistrer la configuration'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
  void _showLanguageDialog(BuildContext context) {
    final currentCode = context.locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildLangTile(BuildContext ctx, String code, String name) {
      final isSelected = currentCode == code;
      return InkWell(
        onTap: () async {
          final newLoc = Locale(code);
          await context.setLocale(newLoc);
          if (context.mounted) {
            try {
              context.read<LocaleProvider>().setLocale(newLoc);
            } catch (_) {}
          }
          if (ctx.mounted) Navigator.pop(ctx);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF0F2D2A) : const Color(0xFFE8F5F3))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF0D544E) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF0D544E),
                  size: 20,
                ),
            ],
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('choose_language'.tr().tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildLangTile(ctx, 'fr', 'Français'),
            buildLangTile(ctx, 'en', 'English'),
            buildLangTile(ctx, 'ar', 'العربية'),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildAdminThemeOption({
      required BuildContext ctx,
      required ThemeMode mode,
      required IconData icon,
      required Color iconColor,
      required String title,
      String? subtitle,
    }) {
      final isSelected = themeProvider.themeMode == mode;
      return InkWell(
        onTap: () {
          themeProvider.setThemeMode(mode);
          Navigator.pop(ctx);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF0F2D2A) : const Color(0xFFE8F5F3))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFF0D544E) : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF0D544E),
                  size: 20,
                ),
            ],
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('theme_choose'.tr().tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildAdminThemeOption(
              ctx: ctx,
              mode: ThemeMode.system,
              icon: Icons.brightness_auto_rounded,
              iconColor: const Color(0xFF64748B),
              title: 'theme_system'.tr(),
              subtitle: 'theme_subtitle_system'.tr(),
            ),
            buildAdminThemeOption(
              ctx: ctx,
              mode: ThemeMode.light,
              icon: Icons.light_mode_rounded,
              iconColor: const Color(0xFFE05D38),
              title: 'theme_light'.tr(),
            ),
            buildAdminThemeOption(
              ctx: ctx,
              mode: ThemeMode.dark,
              icon: Icons.dark_mode_rounded,
              iconColor: const Color(0xFF6366F1),
              title: 'theme_dark'.tr(),
            ),
          ],
        ),
      ),
    );
  }

  // ================= TAB 5: SUPERVISION =================
  Widget _buildSupervisionTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_supervisionSubTab == 0) ...[
            _adminPageHeading(
              title: 'Centre de signalements',
              subtitle: 'Traitez en priorité les incidents remontés par les utilisateurs.',
              icon: Icons.flag_outlined,
              onExport: _exportReports,
            ),
          ] else if (_supervisionSubTab == 1)
            _adminPageHeading(
              title: 'Rapports & analyses',
              subtitle:
                  'Analysez les interventions et les paiements enregistrés.',
              icon: Icons.show_chart_rounded,
              onExport: _exportAnalytics,
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                'Sécurité & Journaux',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSubTabButton('Signalements', 0),
                _buildSubTabButton('Rapports', 1),
                _buildSubTabButton('Journaux de sécurité', 2),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: switch (_supervisionSubTab) {
              0 => _buildReportsTable(),
              1 => _buildAnalyticsReport(),
              _ => _buildSecurityLogList(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsReport() {
    final days = switch (_reportRange) {
      '7 derniers jours' => 7,
      '90 derniers jours' => 90,
      'Cette année' => 365,
      _ => 30,
    };
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
      builder: (context, bookingSnapshot) =>
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .snapshots(),
            builder: (context, paymentSnapshot) {
              if (bookingSnapshot.hasError || paymentSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Impossible de charger les rapports : ${bookingSnapshot.error ?? paymentSnapshot.error}',
                  ),
                );
              }
              if (!bookingSnapshot.hasData || !paymentSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              DateTime? dateOf(Map<String, dynamic> data) {
                for (final key in [
                  'createdAt',
                  'scheduledAt',
                  'bookingDate',
                  'date',
                ]) {
                  final value = data[key];
                  if (value is Timestamp) return value.toDate();
                  if (value is DateTime) return value;
                  if (value is String) {
                    final parsed = DateTime.tryParse(value);
                    if (parsed != null) return parsed;
                  }
                }
                return null;
              }

              final bookings = bookingSnapshot.data!.docs.where((doc) {
                final date = dateOf(doc.data());
                return date != null &&
                    !date.isBefore(start) &&
                    !date.isAfter(now);
              }).toList();
              final payments = paymentSnapshot.data!.docs
                  .where((doc) {
                    final date = dateOf(doc.data());
                    return date != null &&
                        !date.isBefore(start) &&
                        !date.isAfter(now);
                  })
                  .map((doc) => PaymentModel.fromMap(doc.data(), doc.id))
                  .toList();
              final paid = payments
                  .where((p) => p.status == PaymentStatus.success)
                  .toList();
              final revenue = paid.fold<double>(
                0,
                (sum, p) => sum + p.totalAmount,
              );
              final commissions = paid.fold<double>(
                0,
                (sum, p) => sum + p.commissionAmount,
              );
              final completed = bookings.where((doc) {
                final status = (doc.data()['status'] ?? '')
                    .toString()
                    .toLowerCase();
                return [
                  'terminee',
                  'terminée',
                  'completed',
                  'complete',
                ].contains(status);
              }).length;
              final averageTicket = paid.isEmpty ? 0.0 : revenue / paid.length;
              final pendingPayments = payments
                  .where((p) => p.status == PaymentStatus.pending)
                  .length;
              final bucketCount = days <= 7 ? 7 : 6;
              final bucketCounts = List<int>.filled(bucketCount, 0);
              for (final booking in bookings) {
                final date = dateOf(booking.data());
                if (date == null) continue;
                final idx =
                    (date.difference(start).inDays * bucketCount ~/ days).clamp(
                      0,
                      bucketCount - 1,
                    );
                bucketCounts[idx]++;
              }
              final maxCount = bucketCounts.fold<int>(
                0,
                (largest, value) => value > largest ? value : largest,
              );
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _filterDropdown(_reportRange, const [
                          '7 derniers jours',
                          '30 derniers jours',
                          '90 derniers jours',
                          'Cette année',
                        ], (value) => setState(() => _reportRange = value!)),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _exportAnalytics,
                          icon: const Icon(Icons.download_outlined, size: 17),
                          label: const Text('Exporter CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 900
                            ? 3
                            : (constraints.maxWidth >= 560 ? 2 : 1);
                        final width =
                            (constraints.maxWidth - (columns - 1) * 12) /
                            columns;
                        final metrics = [
                          (
                            'Interventions',
                            '${bookings.length}',
                            'Sur la période sélectionnée',
                            Icons.calendar_month_outlined,
                          ),
                          (
                            'Taux de réalisation',
                            '${bookings.isEmpty ? 0 : (completed * 100 / bookings.length).round()} %',
                            '$completed interventions terminées',
                            Icons.task_alt_rounded,
                          ),
                          (
                            'Panier moyen',
                            '${averageTicket.toStringAsFixed(2)} TND',
                            '${paid.length} paiements confirmés',
                            Icons.payments_outlined,
                          ),
                          (
                            'Montant encaissé',
                            '${revenue.toStringAsFixed(2)} TND',
                            'Paiements confirmés',
                            Icons.account_balance_wallet_outlined,
                          ),
                          (
                            'Commissions',
                            '${commissions.toStringAsFixed(2)} TND',
                            'Commissions des paiements confirmés',
                            Icons.account_balance_outlined,
                          ),
                          (
                            'Paiements en attente',
                            '$pendingPayments',
                            'Sur la période sélectionnée',
                            Icons.hourglass_bottom_rounded,
                          ),
                        ];
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: metrics
                              .map(
                                (m) => SizedBox(
                                  width: width,
                                  child: _reportMetric(m.$1, m.$2, m.$3, m.$4),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Volume des interventions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Répartition par période',
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 180,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: bucketCounts.indexed.map((entry) {
                                final value = entry.$2;
                                final ratio = maxCount == 0
                                    ? 0.0
                                    : value / maxCount;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$value',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Container(
                                          height:
                                              130 * ratio +
                                              (value == 0 ? 2 : 0),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16877F)
                                                .withValues(alpha: .75),
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(5),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${entry.$1 + 1}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _reportMetric(
    String title,
    String value,
    String detail,
    IconData icon,
  ) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _cardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF0D756F), size: 20),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(color: _textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(detail, style: TextStyle(color: _textSecondary, fontSize: 10)),
      ],
    ),
  );

  Future<void> _exportAnalytics() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('bookings').get(),
        FirebaseFirestore.instance.collection('payments').get(),
      ]);
      final rows = <List<String>>[
        ['Type', 'Référence', 'Utilisateur', 'Statut', 'Montant', 'Date'],
        ...results[0].docs.map((doc) {
          final d = doc.data();
          return [
            'Intervention',
            doc.id,
            (d['clientName'] ?? '').toString(),
            (d['status'] ?? '').toString(),
            (d['totalPrice'] ?? d['totalAmount'] ?? d['paidAmount'] ?? '')
                .toString(),
            _reportDate(d)?.toIso8601String() ?? '',
          ];
        }),
        ...results[1].docs.map((doc) {
          final p = PaymentModel.fromMap(doc.data(), doc.id);
          return [
            'Paiement',
            p.id,
            p.clientName,
            p.status.labelFr,
            p.totalAmount.toStringAsFixed(2),
            p.createdAt.toIso8601String(),
          ];
        }),
      ];
      await Clipboard.setData(
        ClipboardData(
          text: rows.map((row) => row.map(_csvCell).join(',')).join('\n'),
        ),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rapport CSV copié dans le presse-papiers.'),
          ),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export impossible : $error')));
    }
  }

  Widget
  _buildReportsTable() => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('reports').snapshots(),
    builder: (context, snapshot) {
      final docs = [...?snapshot.data?.docs]
        ..sort(
          (a, b) =>
              (_reportDate(b.data()) ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    _reportDate(a.data()) ??
                        DateTime.fromMillisecondsSinceEpoch(0),
                  ),
        );
      final reports = docs.where((doc) {
        final r = doc.data();
        final status = (r['status'] ?? 'Ouvert').toString();
        final search =
            '${doc.id} ${r['category'] ?? ''} ${r['title'] ?? ''} ${r['targetName'] ?? ''} ${r['reporterName'] ?? ''} ${r['description'] ?? ''}'
                .toLowerCase();
        return (_reportStatusFilter == 'Tous les statuts' ||
                _reportStatusGroup(status) == _reportStatusFilter) &&
            (_reportSearch.isEmpty ||
                search.contains(_reportSearch.toLowerCase()));
      }).toList();
      return Container(
        decoration: BoxDecoration(
          color: _cardBg,
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 340,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Rechercher dans cette liste...',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _reportSearch = v),
                    ),
                  ),
                  _filterDropdown(_reportStatusFilter, const [
                    'Tous les statuts',
                    'À examiner',
                    'En cours',
                    'Résolu',
                  ], (v) => setState(() => _reportStatusFilter = v!)),
                ],
              ),
            ),
            if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossible de charger les signalements : ${snapshot.error}',
                ),
              )
            else if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              )
            else if (reports.isEmpty)
              Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  children: [
                    Icon(Icons.flag_outlined, size: 36, color: _textSecondary),
                    const SizedBox(height: 10),
                    Text(
                      docs.isEmpty
                          ? 'Aucun signalement enregistré.'
                          : 'Aucun résultat pour ces filtres.',
                      style: TextStyle(color: _textSecondary),
                    ),
                  ],
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('RÉFÉRENCE')),
                    DataColumn(label: Text('MOTIF')),
                    DataColumn(label: Text('PERSONNE CONCERNÉE')),
                    DataColumn(label: Text('AUTEUR')),
                    DataColumn(label: Text('DATE')),
                    DataColumn(label: Text('STATUT')),
                    DataColumn(label: Text('ACTIONS')),
                  ],
                  rows: reports.map((doc) {
                    final r = doc.data();
                    final status = (r['status'] ?? 'Ouvert').toString();
                    final group = _reportStatusGroup(status);
                    final date = _reportDate(r);
                    final reason =
                        (r['category'] ??
                                r['title'] ??
                                r['type'] ??
                                'Signalement')
                            .toString();
                    final target =
                        (r['targetName'] ??
                                r['proName'] ??
                                r['clientName'] ??
                                r['bookingId'] ??
                                '—')
                            .toString();
                    final author = (r['reporterName'] ?? 'Utilisateur')
                        .toString();
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            'SIG-${doc.id.substring(0, min(8, doc.id.length)).toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D756F),
                            ),
                          ),
                          onTap: () => _showReportDetails(doc.id, r),
                        ),
                        DataCell(
                          Text(
                            reason,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(Text(target)),
                        DataCell(Text(author)),
                        DataCell(
                          Text(
                            date == null
                                ? '—'
                                : DateFormat('dd MMM yyyy', 'fr').format(date),
                          ),
                        ),
                        DataCell(_reportStatusChip(group)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton(
                                onPressed: () => _showReportDetails(doc.id, r),
                                child: const Text('Examiner'),
                              ),
                              if (group != 'Résolu') ...[
                                const SizedBox(width: 6),
                                FilledButton(
                                  onPressed: () =>
                                      _confirmResolveReport(doc.id, r),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D544E),
                                  ),
                                  child: const Text('Résoudre'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            if (snapshot.hasData)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${reports.length} résultat${reports.length > 1 ? 's' : ''}',
                    style: TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  String _reportStatusGroup(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('résolu') ||
        normalized.contains('resolu') ||
        normalized == 'resolved')
      return 'Résolu';
    if (normalized.contains('cours') || normalized == 'in_progress')
      return 'En cours';
    return 'À examiner';
  }

  DateTime? _reportDate(Map<String, dynamic> report) {
    final date = report['createdAt'];
    if (date is Timestamp) return date.toDate();
    if (date is DateTime) return date;
    if (date is String) return DateTime.tryParse(date);
    return null;
  }

  Widget _reportStatusChip(String status) {
    final color = status == 'Résolu'
        ? const Color(0xFF16805D)
        : status == 'En cours'
        ? const Color(0xFF5967D9)
        : const Color(0xFFBA681B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _confirmResolveReport(
    String reportId,
    Map<String, dynamic> report, {
    BuildContext? closeDetailsContext,
  }) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.flag_outlined, color: Color(0xFF0D756F)),
        title: Text('admin_resolve_report_confirm'.tr()),
        content: const Text('Cette action clôturera ce dossier.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D544E),
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update({
            'status': 'Résolu',
            'resolvedAt': FieldValue.serverTimestamp(),
            'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
          });
      await FirebaseService().logSecurityEvent(
        action: 'Résolution signalement',
        actorEmail: _currentAdminEmail,
        target: report['targetName']?.toString() ?? reportId,
        details:
            'Signalement ${report['category'] ?? report['title'] ?? ''} résolu',
        severity: 'info',
      );
      if (closeDetailsContext != null && closeDetailsContext.mounted) {
        Navigator.of(closeDetailsContext).pop();
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signalement marqué comme résolu.')),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de résoudre le signalement : $error'),
          ),
        );
    }
  }

  void _showReportDetails(String id, Map<String, dynamic> report) {
    final reason =
        (report['category'] ??
                report['title'] ??
                report['type'] ??
                'Signalement')
            .toString();
    final target =
        (report['targetName'] ??
                report['proName'] ??
                report['clientName'] ??
                report['bookingId'] ??
                '—')
            .toString();
    final author = (report['reporterName'] ?? 'Utilisateur').toString();
    final group = _reportStatusGroup((report['status'] ?? 'Ouvert').toString());
    final date = _reportDate(report);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer le signalement',
      barrierColor: Colors.black.withValues(alpha: .3),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, _) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: _isDark ? const Color(0xFF0F172A) : const Color(0xFFF7F8FA),
          child: SizedBox(
            width: min(480, MediaQuery.of(ctx).size.width),
            height: double.infinity,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SIG-${id.substring(0, min(8, id.length)).toUpperCase()}',
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Dossier de signalement',
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _borderColor),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D544E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'APERÇU DU DOSSIER',
                              style: TextStyle(
                                color: Color(0xFF9AC8C1),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'SIG-${id.substring(0, min(8, id.length)).toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Signalement transmis par $author.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _reportDetailsCard([
                        (
                          'Id',
                          'SIG-${id.substring(0, min(8, id.length)).toUpperCase()}',
                        ),
                        ('Motif', reason),
                        ('Personne concernée', target),
                        ('Auteur', author),
                        (
                          'Description',
                          (report['description'] ?? '—').toString(),
                        ),
                        (
                          'Intervention',
                          (report['bookingId'] ?? '—').toString(),
                        ),
                        (
                          'Date',
                          date == null
                              ? '—'
                              : DateFormat('dd MMMM yyyy', 'fr').format(date),
                        ),
                        ('Statut', group),
                      ]),
                      if (group != 'Résolu')
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: FilledButton(
                            onPressed: () => _confirmResolveReport(
                              id,
                              report,
                              closeDetailsContext: ctx,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0D544E),
                            ),
                            child: Text('admin_mark_resolved'.tr()),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (ctx, animation, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
        child: child,
      ),
    );
  }

  Widget _reportDetailsCard(List<(String, String)> values) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: _cardBg,
      border: Border.all(color: _borderColor),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: values.indexed.map((entry) {
        final index = entry.$1;
        final item = entry.$2;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 125,
                    child: Text(
                      item.$1,
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.$2,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index < values.length - 1)
              Divider(height: 1, color: _borderColor),
          ],
        );
      }).toList(),
    ),
  );

  Future<void> _exportReports() async {
    try {
      final docs =
          (await FirebaseFirestore.instance.collection('reports').get()).docs;
      final rows = <List<String>>[
        [
          'Référence',
          'Motif',
          'Personne concernée',
          'Auteur',
          'Description',
          'Date',
          'Statut',
        ],
        ...docs.map((doc) {
          final r = doc.data();
          return [
            doc.id,
            (r['category'] ?? r['title'] ?? r['type'] ?? '').toString(),
            (r['targetName'] ??
                    r['proName'] ??
                    r['clientName'] ??
                    r['bookingId'] ??
                    '')
                .toString(),
            (r['reporterName'] ?? '').toString(),
            (r['description'] ?? '').toString(),
            _reportDate(r)?.toIso8601String() ?? '',
            (r['status'] ?? '').toString(),
          ];
        }),
      ];
      await Clipboard.setData(
        ClipboardData(
          text: rows.map((r) => r.map(_csvCell).join(',')).join('\n'),
        ),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${docs.length} signalements copiés au format CSV.'),
          ),
        );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export impossible : $error')));
    }
  }

  Widget _buildSecurityLogList() => StreamBuilder<List<Map<String, dynamic>>>(
    stream: FirebaseService().streamSecurityLogs(isSuperAdmin: isSuperAdmin),
    builder: (context, snapshot) {
      final logs = snapshot.data ?? [];
      if (snapshot.hasError)
        return Center(
          child: Text('Impossible de charger les journaux : ${snapshot.error}'),
        );
      if (snapshot.connectionState == ConnectionState.waiting)
        return const Center(child: CircularProgressIndicator());
      if (logs.isEmpty)
        return Center(
          child: Text(
            'admin_no_security_logs'.tr(),
            style: TextStyle(color: _textSecondary),
          ),
        );
      return ListView.builder(
        itemCount: logs.length,
        itemBuilder: (ctx, index) {
          final log = logs[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFF1F5F9),
                  child: Icon(
                    Icons.security_rounded,
                    size: 16,
                    color: Color(0xFF0D544E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            log['action']?.toString() ?? 'ACTION',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _textPrimary,
                            ),
                          ),
                          Text(
                            log['actorEmail']?.toString() ?? 'Système',
                            style: TextStyle(
                              fontSize: 11,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        log['details']?.toString() ?? '',
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  Widget _buildSubTabButton(String label, int index) {
    final isSelected = _supervisionSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _supervisionSubTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isDark ? const Color(0xFF334155) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? _textPrimary : _textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSupervisionCard({
    required String reportId,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
    Map<String, dynamic>? reportData,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, color: statusColor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 18,
              color: _textSecondary,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (val) async {
              if (val == 'examine') {
                _showSignalementDetailDialog(
                  reportId,
                  title,
                  subtitle,
                  status,
                  statusColor,
                  reportData,
                );
              } else if (val == 'resolve') {
                try {
                  await FirebaseFirestore.instance
                      .collection('reports')
                      .doc(reportId)
                      .update({
                        'status': 'Résolu',
                        'resolvedAt': FieldValue.serverTimestamp(),
                        'resolvedBy': FirebaseAuth.instance.currentUser?.uid,
                      });
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Signalement marqué comme résolu.'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                } catch (error) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Impossible de résoudre le signalement : $error',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'examine',
                child: Text('Examiner le signalement'),
              ),
              if (status != 'Résolu')
                const PopupMenuItem(
                  value: 'resolve',
                  child: Text('Marquer comme résolu'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProTableHeader extends StatelessWidget {
  const _ProTableHeader(this.label, this.width);

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Color(0xFF94A3B8),
      ),
    ),
  );
}

class AdminWebOnlyScreen extends StatelessWidget {
  const AdminWebOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.desktop_windows_rounded,
                size: 56,
                color: Color(0xFF0D544E),
              ),
              const SizedBox(height: 16),
              Text(
                'admin_web_only_title'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('admin_web_only_body'.tr(), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/login', (route) => false),
                child: Text('admin_back_to_login'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
