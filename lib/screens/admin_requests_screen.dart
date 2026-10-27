import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/email_service.dart';
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
  int _currentBottomNavIndex = 0; // Redirige directement vers le Tableau de bord (Dashboard)
  int _supervisionSubTab = 0; // 0: Signalements, 1: Journaux de sécurité
  int _selectedValidationTab = 0; // 0: �? valider, 1: Validés, 2: Rejetés
  // User management tab filters
  String _userRoleFilter = 'tous';
  final TextEditingController _userSearchController = TextEditingController();
  String _userSearchQuery = '';
  late String _currentAdminName;
  late String _currentAdminRole;
  String _currentAdminEmail = 'admin@darplus.tn';
  String _currentAdminPhone = '+216 71 000 000';
  String? _adminPhotoBase64;
  bool _forceDialogShown = false;
  bool _adminCanManageCategories = false;
  StreamSubscription<List<Map<String, dynamic>>>? _categoriesSub;
  StreamSubscription<Map<String, dynamic>>? _globalSettingsSub;

  bool get isSuperAdmin =>
      _currentAdminRole.toLowerCase() == 'super_admin' ||
      _currentAdminEmail.trim().toLowerCase() == 'admin@darplus.tn' ||
      widget.adminEmail?.trim().toLowerCase() == 'admin@darplus.tn' ||
      widget.adminRole.toLowerCase() == 'super_admin';

  bool get canManageCategories => isSuperAdmin || _adminCanManageCategories;
  // Categories list (8 catégories · 7 actives)
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
      'name': '�?lectricité',
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
    _currentAdminRole = widget.adminRole;
    if (widget.adminEmail != null && widget.adminEmail!.isNotEmpty) {
      _currentAdminEmail = widget.adminEmail!;
    }
    if (widget.adminPhone != null && widget.adminPhone!.isNotEmpty) {
      _currentAdminPhone = widget.adminPhone!;
    }
    NotificationService().markAllAsRead();
    _loadRealAdminProfile();
    _categoriesSub = FirebaseService().streamCategories().listen((list) {
      if (mounted && list.isNotEmpty) {
        setState(() {
          _adminCategories.clear();
          _adminCategories.addAll(list);
        });
      }
    });
    _globalSettingsSub = FirebaseService().streamGlobalSettings().listen((settings) {
      if (mounted) {
        setState(() {
          _adminCanManageCategories = settings['adminCanManageCategories'] == true;
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
      final data = await FirebaseService().getCurrentUserData();
      if (data != null && mounted) {
        setState(() {
          if (data['fullName'] != null && data['fullName'].toString().trim().isNotEmpty) {
            _currentAdminName = data['fullName'].toString().trim();
          }
          if (data['email'] != null && data['email'].toString().trim().isNotEmpty) {
            _currentAdminEmail = data['email'].toString().trim();
          }
          if (data['phone'] != null && data['phone'].toString().trim().isNotEmpty) {
            _currentAdminPhone = data['phone'].toString().trim();
          }
          if (data['photoBase64'] != null && data['photoBase64'].toString().trim().isNotEmpty) {
            _adminPhotoBase64 = data['photoBase64'].toString().trim();
          }
          if (data['role'] != null && (data['role'] == 'super_admin' || data['role'] == 'admin')) {
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
    _userSearchController.dispose();
    super.dispose();
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: Color(0xFFD97706), size: 28),
                SizedBox(width: 10),
                Expanded(child: Text('Changement de mot de passe obligatoire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pour des raisons de securite, vous devez changer votre mot de passe temporaire avant de continuer.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (val) {
                      if (val == null || val.length < 6) return 'Minimum 6 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPassCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (val) {
                      if (val != newPassCtrl.text) return 'Les mots de passe ne correspondent pas';
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
                            await FirebaseService().updateUserField(user.uid, 'mustChangePassword', false);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mot de passe mis a jour avec succes !'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isChanging = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D544E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isChanging
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Changer le mot de passe'),
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
        const SnackBar(
          content: Text('Seul le Super Admin (ou admin autorisé via paramètres globaux) peut ajouter des catégories.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final nameCtrl = TextEditingController();
    final prosCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.add_circle_rounded, color: Color(0xFFF5A623), size: 26),
              SizedBox(width: 10),
              Text('Nouvelle catégorie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    labelText: 'Nom de la catégorie (ex: Menuiserie)',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: prosCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Nombre initial de professionnels',
                    prefixIcon: const Icon(Icons.people_outline_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final name = nameCtrl.text.trim();
                      final pros = int.tryParse(prosCtrl.text.trim()) ?? 0;
                      final ok = await FirebaseService().addCategory(
                        name: name,
                        pros: pros,
                        isActive: true,
                        icon: Icons.handyman_rounded,
                        bgColor: const Color(0xFFE8F0FE),
                        iconColor: const Color(0xFF1E40AF),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Catégorie "$name" enregistrée avec succès !'
                                : 'Erreur lors de l\'ajout de la catégorie'),
                            backgroundColor: ok ? const Color(0xFF0D544E) : Colors.redAccent,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5A623),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
  void _showEditCategoryDialog(Map<String, dynamic> cat) {
    if (!canManageCategories) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Action réservée au Super Admin ou admin autorisé.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final nameCtrl = TextEditingController(text: cat['name']);
    final prosCtrl = TextEditingController(text: '${cat['pros']}');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Color(0xFF0D544E), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Modifier ${cat['name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: prosCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Nombre de professionnels associés',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (cctx) => AlertDialog(
                          title: const Text('Confirmer la suppression'),
                          content: Text('Voulez-vous vraiment supprimer "${cat['name']}" ?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(cctx, false), child: const Text('Annuler')),
                            TextButton(
                              onPressed: () => Navigator.pop(cctx, true),
                              child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      setDialogState(() => isSaving = true);
                      final ok = await FirebaseService().deleteCategory(cat['id'] as String);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Catégorie supprimée avec succès.'
                                : 'Erreur lors de la suppression.'),
                            backgroundColor: ok ? const Color(0xFF0D544E) : Colors.redAccent,
                          ),
                        );
                      }
                    },
              child: const Text('Supprimer', style: TextStyle(color: Color(0xFFDC2626))),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      final updatedName = nameCtrl.text.trim();
                      final updatedPros = int.tryParse(prosCtrl.text.trim()) ?? (cat['pros'] as int? ?? 0);
                      final ok = await FirebaseService().updateCategory(
                        cat['id'] as String,
                        name: updatedName,
                        pros: updatedPros,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Catégorie modifiée avec succès.'
                                : 'Erreur lors de la modification.'),
                            backgroundColor: ok ? const Color(0xFF0D544E) : Colors.redAccent,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D544E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _pickAdminImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 70);
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
            const SnackBar(content: Text('Photo Administrateur mise à jour !'), backgroundColor: Color(0xFF10B981)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
  void _showAdminPhotoPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),
              const Text('Photo de profil Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0284C7)),
                ),
                title: const Text('Choisir depuis la galerie', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Importer une photo', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                onTap: () { Navigator.pop(ctx); _pickAdminImage(ImageSource.gallery); },
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: const Color(0xFFD7F3EA), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0D544E)),
                ),
                title: const Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Utiliser l\'appareil photo', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                onTap: () { Navigator.pop(ctx); _pickAdminImage(ImageSource.camera); },
              ),
              if (_adminPhotoBase64 != null && _adminPhotoBase64!.isNotEmpty) ...[
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                  ),
                  title: const Text('Supprimer la photo', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() { _adminPhotoBase64 = null; });
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.lock_reset_rounded, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text('Changer le mot de passe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      labelText: 'Mot de passe actuel',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Mot de passe actuel requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Nouveau mot de passe',
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nouveau mot de passe requis';
                      if (v.trim().length < 6) return 'Minimum 6 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) {
                      if (v != newPassCtrl.text) return 'Les mots de passe ne correspondent pas';
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
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
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
              child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
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
                          const SnackBar(
                            content: Text('Mot de passe mis à jour avec succès !'),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Mettre à jour'),
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
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.manage_accounts_rounded, color: Color(0xFF0D544E), size: 26),
                SizedBox(width: 10),
                Text(
                  'Modifier mon profil Admin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.titleColor,
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
                    const Text(
                      'Modifiez vos informations administratives.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nom complet',
                        prefixIcon: const Icon(Icons.person_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Adresse e-mail',
                        prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone',
                        prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Téléphone requis' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
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
                            const SnackBar(
                              content: Text('Profil Administrateur mis à jour avec succès !'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D544E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer'),
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
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 10),
            Text('Déconnexion Admin'),
          ],
        ),
        content: const Text('Voulez-vous quitter le panneau d\'administration DAR PLUS ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
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
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
  String _generateSecurePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
    final random = Random.secure();
    return List.generate(10, (index) => chars[random.nextInt(chars.length)]).join();
  }
  void _showGlobalSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<Map<String, dynamic>>(
        stream: FirebaseService().streamGlobalSettings(),
        builder: (context, snapshot) {
          final settings = snapshot.data ?? {
            'maintenanceMode': false,
            'adminCanManageCategories': false,
            'serviceFeePercent': 10.0,
            'maxUploadSizeBytes': 5242880,
          };
          bool maintenance = settings['maintenanceMode'] == true;
          bool canCategories = settings['adminCanManageCategories'] == true;
          double fee = (settings['serviceFeePercent'] as num?)?.toDouble() ?? 10.0;
          return StatefulBuilder(
            builder: (ctx, setDlgState) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              title: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: Color(0xFFD97706), size: 26),
                  SizedBox(width: 10),
                  Text('Paramètres globaux', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Mode Maintenance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Bloque les accès clients pendant les mises à jour'),
                    value: maintenance,
                    activeThumbColor: const Color(0xFFD97706),
                    onChanged: (val) async {
                      setDlgState(() => maintenance = val);
                      await FirebaseService().updateGlobalSettings(
                        {'maintenanceMode': val},
                        actorEmail: _currentAdminEmail,
                      );
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Admin peut gérer catégories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Autoriser les administrateurs à créer/éditer des catégories'),
                    value: canCategories,
                    activeThumbColor: const Color(0xFF0D544E),
                    onChanged: (val) async {
                      setDlgState(() => canCategories = val);
                      await FirebaseService().updateGlobalSettings(
                        {'adminCanManageCategories': val},
                        actorEmail: _currentAdminEmail,
                      );
                    },
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Frais de service plateforme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('${fee.toStringAsFixed(0)} %', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D544E))),
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
                            await FirebaseService().updateGlobalSettings(
                              {'serviceFeePercent': val},
                              actorEmail: _currentAdminEmail,
                            );
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Fermer'),
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
        const SnackBar(
          content: Text('Seul le Super Admin peut creer de nouveaux administrateurs.'),
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
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF7C3AED),
                    size: 26,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Créer un compte Admin',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.titleColor,
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
                      const Text(
                        'Ajoutez un nouvel administrateur. Un mot de passe sera généré automatiquement et lui sera envoyé directement par e-mail.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Nom complet',
                          prefixIcon: const Icon(Icons.person_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Téléphone',
                          prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Téléphone requis'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email institutionnel',
                          prefixIcon:
                              const Icon(Icons.alternate_email_rounded, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        validator: (v) =>
                            v == null || !v.contains('@') ? 'Email invalide' : null,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.mark_email_read_rounded, color: Color(0xFF7C3AED), size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Le mot de passe sera généré de façon sécurisée et transmis automatiquement par email au nouvel administrateur.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF5B21B6),
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
                  child: const Text('Annuler',
                      style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          final autoPassword = _generateSecurePassword();
                          final newAdminName = nameController.text.trim();
                          final newAdminEmail = emailController.text.trim();
                          final newAdminPhone = phoneController.text.trim();
                          final messenger = ScaffoldMessenger.of(context);
                          final res = await FirebaseService().registerAdmin(
                            fullName: newAdminName,
                            phone: newAdminPhone,
                            email: newAdminEmail,
                            password: autoPassword,
                          );
                          bool emailSent = false;
                          if (res['success'] == true) {
                            emailSent = await EmailService.sendNewAdminCredentials(
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
                              _showAdminCreatedDialog(newAdminName, newAdminEmail, autoPassword, emailSent: emailSent);
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
                    backgroundColor: const Color(0xFF7C3AED),
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Créer et Envoyer l\'accès'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _showAdminCreatedDialog(String name, String email, String generatedPassword, {bool emailSent = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text('Admin créé avec succès !', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Le compte de $name a été activé.', style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569))),
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
                  const Text('Email envoyé à :', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  Text(email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 10),
                  const Text('Mot de passe généré automatiquement :', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      generatedPassword,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('Ce mot de passe a été expédié par e-mail au nouvel administrateur pour lui permettre de se connecter immédiatement.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D544E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Compris'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 26),
              SizedBox(width: 10),
              Text('Valider la candidature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
                  children: [
                    const TextSpan(text: 'Voulez-vous valider la candidature de '),
                    TextSpan(
                      text: app.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' ('),
                    TextSpan(
                      text: app.serviceType,
                      style: const TextStyle(color: Color(0xFF0D544E), fontWeight: FontWeight.w600),
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
                    const Icon(Icons.mark_email_read_rounded, color: Color(0xFF059669), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Un email d\'acceptation sera automatiquement envoyé à ${app.email}.',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF065F46)),
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
              child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isApproving
                  ? null
                  : () async {
                      setDialogState(() => isApproving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final success = await FirebaseService().approveProApplication(app.id, proApp: app);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (success) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Candidature de ${app.fullName} validée ! Email d\'acceptation envoyé.'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                          setState(() {});
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Erreur lors de la validation. Réessayez.'),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isApproving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmer la validation'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectProDialog(ProApplication app) {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 26),
            SizedBox(width: 10),
            Text('Rejeter la candidature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Candidat : ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Motif du rejet *',
                  hintText: 'Expliquez la raison du rejet...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Le motif est obligatoire';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final reason = reasonCtrl.text.trim();
              await FirebaseService().rejectProApplication(app.id, reason: reason, proApp: app);
              // Envoyer email de rejet au professionnel
              try {
                await EmailService.sendProRejectedEmail(
                  toEmail: app.email,
                  proName: app.fullName,
                  reason: reason,
                );
              } catch (_) {}
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Candidature de  rejetee.'),
                  backgroundColor: const Color(0xFFDC2626),
                ),
              );
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirmer le rejet'),
          ),
        ],
      ),
    );
  }
  void _showDocumentPreview(ProApplication app, String docName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 8),
            Text(docName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Candidat : ${app.fullName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Spécialité : ${app.serviceType}',
              style: const TextStyle(color: Color(0xFF0D544E), fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.file_present_rounded, color: Color(0xFF0D544E), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$docName (PDF vérifié)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Text('Validité conforme �?� République Tunisienne',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
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
                      backgroundColor: const Color(0xFF0D544E).withValues(alpha: 0.12),
                      backgroundImage: MemoryImage(base64Decode(userPhoto)),
                    );
                  } catch (_) {}
                }
                return CircleAvatar(
                  backgroundColor: const Color(0xFF0D544E).withValues(alpha: 0.12),
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
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
            _buildDetailRow(Icons.badge_rounded, 'Rôle', role.toUpperCase()),
            if (role == 'professionnel') ...[
              const SizedBox(height: 10),
              _buildDetailRow(Icons.handyman_rounded, 'Spécialité', serviceType),
            ],
            const SizedBox(height: 10),
            _buildDetailRow(
              Icons.check_circle_outline_rounded,
              'Statut du compte',
              isActive ? 'Actif' : 'Suspendu / Inactif',
            ),
          ],
        ),
        actions: [
          if (isSuperAdmin && (user['email'] ?? '') != 'admin@darplus.tn')
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showEditUserRoleDialog(user);
              },
              icon: const Icon(Icons.manage_accounts_rounded, size: 16),
              label: const Text('Modifier rôle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFF7C3AED), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Modifier le rôle : $fullName',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email : $email', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              const Text('Sélectionnez le nouveau rôle :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              _buildRoleOption('client', 'Client (Accès standard)', selectedRole, (val) => setDialogState(() => selectedRole = val)),
              _buildRoleOption('professionnel', 'Professionnel (Prestation de services)', selectedRole, (val) => setDialogState(() => selectedRole = val)),
              _buildRoleOption('admin', 'Admin (Gestion courante limitée)', selectedRole, (val) => setDialogState(() => selectedRole = val)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
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
                            content: Text(success
                                ? 'Rôle de $fullName mis à jour en $selectedRole'
                                : 'Impossible de modifier le rôle.'),
                            backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildRoleOption(String roleKey, String label, String currentRole, ValueChanged<String> onSelect) {
    final bool isSelected = currentRole == roleKey;
    return InkWell(
      onTap: () => onSelect(roleKey),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF1E293B),
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
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
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
    return StreamBuilder<List<ProApplication>>(
      stream: FirebaseService().streamProApplications(),
      builder: (context, snapshot) {
        final allList = snapshot.data ?? [];
        final pendingList = allList.where((a) => a.status == 'en_attente').toList();
        return Scaffold(
          backgroundColor: const Color(0xFFF7F9F9),
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _currentBottomNavIndex,
              children: [
                // Tab 0: TABLEAU DE BORD
                _buildDashboardTab(pendingList),
                // Tab 1: UTILISATEURS (FONCTIONNEL)
                _buildUsersTab(),
                // Tab 2: VALIDATIONS (EXACT MATCH TO SCREENSHOT)
                _buildValidationsTab(allList),
                // Tab 3: CATÉGORIES (EXACT MATCH TO SCREENSHOT)
                _buildCategoriesTab(),
                // Tab 4: PROFIL ADMIN (MODIFIER PROFIL & LOGOUT) - RECOMMANDÉ & AJOUTÉ
                _buildAdminProfileTab(),
                // Tab 5: SUPERVISION (ACCESSIBLE VIA MENU / DASHBOARD)
                _buildSupervisionTab(),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentBottomNavIndex > 4 ? 4 : _currentBottomNavIndex,
              onTap: (index) {
                setState(() {
                  _currentBottomNavIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF0D544E),
              unselectedItemColor: const Color(0xFF64748B),
              selectedFontSize: 11,
              unselectedFontSize: 10.5,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
              elevation: 0,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_rounded),
                  label: 'Tableau',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline_rounded),
                  activeIcon: Icon(Icons.people_rounded),
                  label: 'Utilisateurs',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.verified_user_outlined),
                      if (pendingList.isNotEmpty)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEA580C),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${pendingList.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  activeIcon: const Icon(Icons.verified_user_rounded),
                  label: 'Validations',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.category_outlined),
                  activeIcon: Icon(Icons.category_rounded),
                  label: 'Catégories',
                ),
                // 5th ITEM: PROFIL (EXACTEMENT DEMAND�? PAR L'UTILISATEUR)
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  // ================= TAB 0: DASHBOARD =================
  Widget _buildDashboardTab(List<ProApplication> pendingList) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tableau de bord',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _currentBottomNavIndex = 4),
                child: Row(
                  children: [
                    if (_adminPhotoBase64 != null && _adminPhotoBase64!.isNotEmpty)
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFFD7F3EA),
                        backgroundImage: MemoryImage(base64Decode(_adminPhotoBase64!)),
                      )
                    else
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xFF0D544E),
                        child: Text(
                          _currentAdminName.isNotEmpty ? _currentAdminName[0].toUpperCase() : 'A',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSuperAdmin ? const Color(0xFFD97706) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isSuperAdmin ? 'Super Admin' : 'Admin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 20),
          // 2x2 KPI Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _buildDashboardCard(
                icon: Icons.people_alt_rounded,
                iconBg: const Color(0xFFF1F5F9),
                iconColor: const Color(0xFF0F172A),
                value: '1 284',
                label: 'Utilisateurs',
                onTap: () => setState(() => _currentBottomNavIndex = 1),
              ),
              _buildDashboardCard(
                icon: Icons.verified_user_rounded,
                iconBg: const Color(0xFFFFF7ED),
                iconColor: const Color(0xFFEA580C),
                value: '${pendingList.length}',
                valueColor: const Color(0xFFEA580C),
                label: 'Pros à valider',
                onTap: () => setState(() => _currentBottomNavIndex = 2),
              ),
              _buildDashboardCard(
                icon: Icons.category_rounded,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                value: '${_adminCategories.length}',
                valueColor: const Color(0xFFD97706),
                label: 'Catégories',
                onTap: () => setState(() => _currentBottomNavIndex = 3),
              ),
              _buildDashboardCard(
                icon: Icons.person_rounded,
                iconBg: const Color(0xFFD7F3EA),
                iconColor: const Color(0xFF0D544E),
                value: 'Profil',
                valueColor: const Color(0xFF0D544E),
                label: 'Mon Profil Admin',
                onTap: () => setState(() => _currentBottomNavIndex = 4),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Chart card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Réservations par semaine',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildWeeklyBar(height: 60, label: 'S1', isSolidTeal: false),
                    _buildWeeklyBar(height: 90, label: 'S2', isSolidTeal: false),
                    _buildWeeklyBar(height: 75, label: 'S3', isSolidTeal: false),
                    _buildWeeklyBar(height: 135, label: 'S4', isSolidTeal: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // À traiter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'À traiter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _currentBottomNavIndex = 2),
                child: const Text(
                  'Tout voir',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D544E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pendingList.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  'Aucune demande en attente pour le moment.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                ),
              ),
            )
          else
            ...pendingList.take(3).map((app) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFFEF3C7),
                    child: Text(
                      _getInitials(app.fullName),
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  title: Text(
                    app.fullName,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    'Demande de validation �?� ${app.serviceType}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                  onTap: () => setState(() => _currentBottomNavIndex = 2),
                ),
              );
            }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  Widget _buildDashboardCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String value,
    Color? valueColor,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: valueColor ?? const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildWeeklyBar({
    required double height,
    required String label,
    required bool isSolidTeal,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: height,
          decoration: BoxDecoration(
            color: isSolidTeal
                ? const Color(0xFF0D544E)
                : const Color(0xFFB7DFD7),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSolidTeal ? FontWeight.bold : FontWeight.w600,
            color: isSolidTeal ? const Color(0xFF0D544E) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
  // ================= TAB 1: UTILISATEURS (FONCTIONNEL ET CONNECT�? FIREBASE) =================
  Widget _buildUsersTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirebaseService().streamUsers(),
      builder: (context, snapshot) {
        final allUsers = snapshot.data ?? [];
        // Filtrage selon rôle
        // Exclure l'administrateur connecté de la liste des utilisateurs
        var filteredUsers = allUsers.where((u) {
          final uEmail = (u['email'] as String? ?? '').toLowerCase().trim();
          return uEmail != _currentAdminEmail.toLowerCase().trim();
        }).toList();
        if (_userRoleFilter != 'tous') {
          filteredUsers = filteredUsers.where((u) {
            final role = (u['role'] as String? ?? 'client').toLowerCase();
            return role == _userRoleFilter;
          }).toList();
        }
        // Filtrage selon recherche
        if (_userSearchQuery.trim().isNotEmpty) {
          final q = _userSearchQuery.toLowerCase();
          filteredUsers = filteredUsers.where((u) {
            final name = (u['fullName'] as String? ?? '').toLowerCase();
            final email = (u['email'] as String? ?? '').toLowerCase();
            final role = (u['role'] as String? ?? '').toLowerCase();
            return name.contains(q) || email.contains(q) || role.contains(q);
          }).toList();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                children: [
    
                  const Text(
                    'Utilisateurs',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const Spacer(),
                  // Button + Admin
                  if (isSuperAdmin)
                  ElevatedButton.icon(
                    onPressed: _showNewAdminDialog,
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('+ Admin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D544E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Search Bar
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _userSearchController,
                        onChanged: (val) {
                          setState(() {
                            _userSearchQuery = val;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Rechercher un utilisateur (nom, email)...',
                          hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_userSearchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _userSearchController.clear();
                          setState(() => _userSearchQuery = '');
                        },
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Role Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildUserRoleChip('tous', 'Tous (${allUsers.length})'),
                    const SizedBox(width: 8),
                    _buildUserRoleChip(
                      'client',
                      'Clients (${allUsers.where((u) => (u['role'] as String? ?? 'client').toLowerCase() == 'client').length})',
                    ),
                    const SizedBox(width: 8),
                    _buildUserRoleChip(
                      'professionnel',
                      'Pros (${allUsers.where((u) => (u['role'] as String? ?? '').toLowerCase() == 'professionnel').length})',
                    ),
                    const SizedBox(width: 8),
                    _buildUserRoleChip(
                      'admin',
                      'Admins (${allUsers.where((u) => (u['role'] as String? ?? '').toLowerCase() == 'admin').length})',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // List of Users
              Expanded(
                child: filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded,
                                size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 10),
                            const Text(
                              'Aucun utilisateur trouvé',
                              style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return _buildUserCard(user);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildUserRoleChip(String roleKey, String label) {
    final isSelected = _userRoleFilter == roleKey;
    return GestureDetector(
      onTap: () => setState(() => _userRoleFilter = roleKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D544E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D544E) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  Widget _buildUserCard(Map<String, dynamic> user) {
    final docId = user['id'] ?? user['uid'] ?? '';
    final fullName = user['fullName'] as String? ?? 'Utilisateur';
    final email = user['email'] as String? ?? '';
    final role = (user['role'] as String? ?? 'client').toLowerCase();
    final bool isActive = user['isActive'] ?? true;
    Color roleColor;
    String roleLabel;
    switch (role) {
      case 'super_admin':
        roleColor = const Color(0xFFD97706);
        roleLabel = 'Super Admin';
        break;
      case 'admin':
        roleColor = const Color(0xFF7C3AED);
        roleLabel = 'Admin';
        break;
      case 'professionnel':
        roleColor = const Color(0xFF059669);
        roleLabel = 'Pro · ${user['serviceType'] ?? "Service"}';
        break;
      default:
        roleColor = const Color(0xFF2563EB);
        roleLabel = 'Client';
    }
    final bool isTargetAdmin = role == 'admin' || role == 'super_admin';
    final bool canManageThisUser = isSuperAdmin || !isTargetAdmin;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (context) {
                  final userPhoto = user['photoBase64'] as String?;
                  if (userPhoto != null && userPhoto.isNotEmpty) {
                    try {
                      return CircleAvatar(
                        radius: 22,
                        backgroundColor: roleColor.withValues(alpha: 0.12),
                        backgroundImage: MemoryImage(base64Decode(userPhoto)),
                      );
                    } catch (_) {}
                  }
                  return CircleAvatar(
                    radius: 22,
                    backgroundColor: roleColor.withValues(alpha: 0.12),
                    child: Text(
                      _getInitials(fullName),
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  roleLabel,
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                      size: 13,
                      color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isActive ? 'Actif' : 'Suspendu',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _showUserDetailsDialog(user),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Détails', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 6),
                  if (canManageThisUser)
                  OutlinedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await FirebaseService().toggleUserStatus(docId, email, isActive);
                      setState(() {});
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(isActive
                              ? '$fullName a été suspendu.'
                              : '$fullName a été réactivé.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(
                        color: isActive ? const Color(0xFFEA580C) : const Color(0xFF10B981),
                      ),
                    ),
                    child: Text(
                      isActive ? 'Suspendre' : 'Activer',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isActive ? const Color(0xFFEA580C) : const Color(0xFF10B981),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (canManageThisUser)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: Color(0xFFDC2626)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Supprimer l\'utilisateur'),
                          content: Text('Voulez-vous supprimer définitivement $fullName ?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Annuler'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await FirebaseService().deleteUser(docId, email);
                                setState(() {});
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Supprimer'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ================= TAB 2: VALIDATIONS DES PROS (EXACT DESIGN MATCH TO SCREENSHOT) =================
  Widget _buildValidationsTab(List<ProApplication> allList) {
    final pendingList = allList.where((a) => a.status == 'en_attente').toList();
    final validatedList = allList.where((a) => a.status == 'valide').toList();
    final rejectedList = allList.where((a) => a.status == 'refuse').toList();
    List<ProApplication> currentDisplayList;
    if (_selectedValidationTab == 0) {
      currentDisplayList = pendingList;
    } else if (_selectedValidationTab == 1) {
      currentDisplayList = validatedList;
    } else {
      currentDisplayList = rejectedList;
    }
    return Column(
      children: [
        // 1. Top Bar: Menu Button + "Validation des pros"
        Padding(
          padding: const EdgeInsets.only(left: 18, right: 18, top: 16, bottom: 8),
          child: Row(
            children: [
              const Text(
                'Validation des pros',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
        // 2. Horizontal Filter Tabs: "�? valider (X)", "Validés", "Rejetés"
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFF7F9F9),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              _buildValidationSubTabItem(
                index: 0,
                label: 'À valider',
                badgeCount: pendingList.length,
                isSelected: _selectedValidationTab == 0,
              ),
              const SizedBox(width: 24),
              _buildValidationSubTabItem(
                index: 1,
                label: 'Validés',
                badgeCount: null,
                isSelected: _selectedValidationTab == 1,
              ),
              const SizedBox(width: 24),
              _buildValidationSubTabItem(
                index: 2,
                label: 'Rejetés',
                badgeCount: null,
                isSelected: _selectedValidationTab == 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // 3. Pro Cards List
        Expanded(
          child: currentDisplayList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_outlined,
                          size: 52, color: Colors.grey.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        _selectedValidationTab == 0
                            ? 'Aucune demande en attente'
                            : (_selectedValidationTab == 1
                                ? 'Aucun professionnel validé'
                                : 'Aucune demande rejetée'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  itemCount: currentDisplayList.length,
                  itemBuilder: (context, index) {
                    final app = currentDisplayList[index];
                    return _buildScreenshotProCard(app, index);
                  },
                ),
        ),
      ],
    );
  }
  Widget _buildValidationSubTabItem({
    required int index,
    required String label,
    required int? badgeCount,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedValidationTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: isSelected
              ? const Border(
                  bottom: BorderSide(
                    color: Color(0xFF0D544E),
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF0D544E) : const Color(0xFF64748B),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFDE6D1B),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  Widget _buildScreenshotProCard(ProApplication app, int index) {
    final avatarPalettes = [
      {'bg': const Color(0xFFFDF2DC), 'text': const Color(0xFF92400E)}, // LB
      {'bg': const Color(0xFFE0EAFA), 'text': const Color(0xFF1E40AF)}, // IC
      {'bg': const Color(0xFFD7F3EA), 'text': const Color(0xFF065F46)}, // WH
      {'bg': const Color(0xFFFCE7F3), 'text': const Color(0xFF9D174D)},
    ];
    final palette = avatarPalettes[index % avatarPalettes.length];
    String statusText = 'En attente';
    Color statusBg = const Color(0xFFFEF3C7);
    Color statusTextCol = const Color(0xFF92400E);
    if (app.status == 'valide') {
      statusText = 'Validé';
      statusBg = const Color(0xFFD1FAE5);
      statusTextCol = const Color(0xFF065F46);
    } else if (app.status == 'refuse') {
      statusText = 'Rejeté';
      statusBg = const Color(0xFFFEE2E2);
      statusTextCol = const Color(0xFF991B1B);
    }
    final city = app.phone.contains('Tunis') ||
            app.phone.contains('Ariana') ||
            app.phone.contains('Marsa')
        ? app.phone
        : (index == 0 ? 'Tunis' : (index == 1 ? 'Ariana' : 'La Marsa'));
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Avatar + Name/City + Status pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette['bg'],
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  _getInitials(app.fullName),
                  style: TextStyle(
                    color: palette['text'],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${app.serviceType} · $city',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: statusTextCol,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 2. Documents row (Pièce d'identité, Certificat)
          Row(
            children: [
              _buildDocumentPill(
                icon: Icons.badge_outlined,
                label: 'Pièce d\'identité',
                onTap: () => _showDocumentPreview(app, 'Pièce d\'identité'),
              ),
              if (index != 1) ...[
                const SizedBox(width: 8),
                _buildDocumentPill(
                  icon: Icons.description_outlined,
                  label: 'Certificat',
                  onTap: () => _showDocumentPreview(app, 'Certificat Professionnel'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // 3. Action Buttons: "Rejeter" (red outlined) & "Valider" (dark teal filled)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => _showRejectProDialog(app),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF991B1B),
                      side: const BorderSide(color: Color(0xFFB91C1C), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      app.status == 'refuse' ? 'Déjà rejeté' : 'Rejeter',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: app.status == 'valide' ? null : () => _showApproveProDialog(app),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D544E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      app.status == 'valide' ? 'Déjà validé' : 'Valider',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildDocumentPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ================= TAB 3: CATÉGORIES (EXACT DESIGN MATCH TO LATEST SCREENSHOT) =================
  Widget _buildCategoriesTab() {
    final activeCount = _adminCategories.where((c) => c['isActive'] == true).length;
    final totalCount = _adminCategories.length;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Bar: Menu Button + Title "Catégories"
              Row(
                children: [
    
                  const Text(
                    'Catégories',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 2. Subtitle: "8 catégories · 7 actives"
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '$totalCount catégories · $activeCount actives',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 3. Category Cards List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _adminCategories.length,
                  itemBuilder: (context, index) {
                    final cat = _adminCategories[index];
                    final bool isActive = cat['isActive'] as bool;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Squircle Icon container
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: cat['bgColor'] as Color,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              cat['icon'] as IconData,
                              color: cat['iconColor'] as Color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Name & Count
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isActive
                                      ? '${cat['pros']} professionnel${(cat['pros'] as int? ?? 0) > 1 ? 's' : ''}'
                                      : 'Désactivée',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isActive
                                        ? const Color(0xFF64748B)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Badge compteur pros
                          if (isActive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD7F3EA),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${cat['pros'] as int? ?? 0}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D544E),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          // Pencil Edit button
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 20, color: Color(0xFF64748B)),
                            onPressed: () => _showEditCategoryDialog(cat),
                          ),
                          const SizedBox(width: 2),
                          // Switch Toggle
                          Switch(
                            value: isActive,
                            activeTrackColor: const Color(0xFF0D544E),
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: const Color(0xFFCBD5E1),
                            inactiveThumbColor: Colors.white,
                            onChanged: (val) async {
                              if (!canManageCategories) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Action non autorisée.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                cat['isActive'] = val;
                              });
                              await FirebaseService().toggleCategoryStatus(cat['id'] as String, val);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // 4. Floating Action Button: "+ Nouvelle catégorie" (Orange pill matching screenshot)
        Positioned(
          right: 20,
          bottom: 20,
          child: GestureDetector(
            onTap: _showAddCategoryDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5A623),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Color(0xFF0F172A), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Nouvelle catégorie',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar: Menu Hamburger + "Mon Profil Admin"
          Row(
            children: [
              const Text(
                'Mon Profil Admin',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Admin Profile Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D544E), Color(0xFF147A70)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D544E).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    GestureDetector(
                      onTap: _showAdminPhotoPickerSheet,
                      child: _adminPhotoBase64 != null && _adminPhotoBase64!.isNotEmpty
                          ? CircleAvatar(
                              radius: 38,
                              backgroundColor: Colors.white,
                              backgroundImage: MemoryImage(base64Decode(_adminPhotoBase64!)),
                            )
                          : CircleAvatar(
                              radius: 38,
                              backgroundColor: Colors.white,
                              child: Text(
                                _currentAdminName.isNotEmpty
                                    ? _currentAdminName[0].toUpperCase()
                                    : 'A',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D544E),
                                ),
                              ),
                            ),
                    ),
                    GestureDetector(
                      onTap: _showAdminPhotoPickerSheet,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5A623),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _currentAdminName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentAdminEmail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _currentAdminPhone,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 16),
                // Button to edit profile directly on header
                ElevatedButton.icon(
                  onPressed: _showEditAdminProfileDialog,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Modifier mon profil'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0D544E),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Options & Parameters
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFD7F3EA),
                    child: Icon(Icons.badge_outlined, color: Color(0xFF0D544E)),
                  ),
                  title: const Text('Coordonnées & Informations',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                  subtitle: const Text('Modifier nom, téléphone et adresse email'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showEditAdminProfileDialog,
                ),
                const Divider(height: 1, indent: 64),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.lock_reset_rounded, color: Color(0xFFD97706)),
                  ),
                  title: const Text('Sécurité & Mot de passe',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                  subtitle: const Text('Modifier votre mot de passe directement'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(height: 1, indent: 64),
                if (isSuperAdmin) ...[
                  const Divider(height: 1, indent: 64),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0E7FF),
                      child: Icon(Icons.person_add_rounded, color: Color(0xFF4338CA)),
                    ),
                    title: const Text('Créer un nouvel administrateur',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                    subtitle: const Text('Ajouter un nouveau compte administrateur'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _showNewAdminDialog,
                  ),
                  const Divider(height: 1, indent: 64),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF3C7),
                      child: Icon(Icons.tune_rounded, color: Color(0xFFD97706)),
                    ),
                    title: const Text('Paramètres globaux',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                    subtitle: const Text('Maintenance, commissions et permissions'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _showGlobalSettingsDialog,
                  ),
                ],
              ],
            ),
            ),
          ),
          const SizedBox(height: 24),
          // Logout Button
          InkWell(
            onTap: _handleLogout,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text(
                    'Se déconnecter (Logout)',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
  // ================= TAB 5: SUPERVISION =================
  Widget _buildSupervisionTab() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Supervision & Alertes',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildSubTabButton('Signalements', 0),
                    _buildSubTabButton('Sécurité & Logs', 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _supervisionSubTab == 0
                ? ListView(
                    children: [
                      _buildSupervisionCard(
                        title: 'Signalement #104 : Retard intervention',
                        subtitle: 'Client : Sonia Mansouri · Pro : Mohamed Ali',
                        status: 'Ouvert',
                        statusColor: const Color(0xFFDC2626),
                      ),
                      _buildSupervisionCard(
                        title: 'Signalement #103 : Annulation tardive',
                        subtitle: 'Client : Karim Belhaj · Pro : Rami Chaari',
                        status: 'En cours',
                        statusColor: const Color(0xFFEA580C),
                      ),
                      _buildSupervisionCard(
                        title: 'Signalement #102 : Qualité prestation',
                        subtitle: 'Client : Ahmed Ben Salah · Pro : Fatma T.',
                        status: 'Résolu',
                        statusColor: const Color(0xFF10B981),
                      ),
                    ],
                  )
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: FirebaseService().streamSecurityLogs(isSuperAdmin: isSuperAdmin),
                    builder: (context, snapshot) {
                      final logs = snapshot.data ?? [];
                      if (logs.isEmpty) {
                        return const Center(
                          child: Text(
                            'Aucun journal de sécurité enregistré.',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (ctx, index) {
                          final log = logs[index];
                          final action = log['action'] ?? 'ACTION';
                          final details = log['details'] ?? '';
                          final actor = log['actorEmail'] ?? 'Système';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Color(0xFFF1F5F9),
                                  child: Icon(Icons.security_rounded, size: 16, color: Color(0xFF0D544E)),
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
                                            action,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            actor,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        details,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
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
                  ),
          ),
        ],
      ),
    );
  }
  Widget _buildSubTabButton(String label, int index) {
    final isSelected = _supervisionSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _supervisionSubTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
  Widget _buildSupervisionCard({
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, color: statusColor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
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
                  color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
