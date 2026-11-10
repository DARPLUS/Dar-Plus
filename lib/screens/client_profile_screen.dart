import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'payment_history_screen.dart';

class ClientProfileScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String userPhone;

  const ClientProfileScreen({
    super.key,
    this.userName = 'Client',
    this.userEmail = '',
    this.userPhone = '',
  });

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  late String _currentName;
  late String _currentEmail;
  late String _currentPhone;
  String? _photoBase64;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _currentName = widget.userName.isNotEmpty ? widget.userName : 'Client DAR PLUS';
    _currentEmail = widget.userEmail;
    _currentPhone = widget.userPhone;
    _loadRealProfile();
  }

  Future<void> _loadRealProfile() async {
    try {
      final data = await FirebaseService().getCurrentUserData();
      if (data != null && mounted) {
        setState(() {
          if (data['fullName'] != null && data['fullName'].toString().trim().isNotEmpty) {
            _currentName = data['fullName'].toString().trim();
          }
          if (data['email'] != null && data['email'].toString().trim().isNotEmpty) {
            _currentEmail = data['email'].toString().trim();
          }
          if (data['phone'] != null && data['phone'].toString().trim().isNotEmpty) {
            _currentPhone = data['phone'].toString().trim();
          }
          if (data['photoUrl'] != null && data['photoUrl'].toString().trim().isNotEmpty) {
            _photoUrl = data['photoUrl'].toString().trim();
          }
          if (data['photoBase64'] != null && data['photoBase64'].toString().trim().isNotEmpty) {
            _photoBase64 = data['photoBase64'].toString().trim();
          }
        });
        return;
      }
    } catch (_) {}
  }

  void _showPhotoPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 18),
              const Text('Photo de profil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0284C7)),
                ),
                title: const Text('Choisir depuis la galerie', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Importer une image existante', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
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
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
              ),
              if ((_photoBase64 != null && _photoBase64!.isNotEmpty) || (_photoUrl != null && _photoUrl!.isNotEmpty)) ...[
                const SizedBox(height: 6),
                ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                  ),
                  title: const Text('Supprimer la photo', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                  onTap: () { Navigator.pop(ctx); _removePhoto(); },
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 70);
      if (picked != null) {
        final file = File(picked.path);
        
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Row(children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Upload en cours...'),
            ]),
            backgroundColor: Color(0xFF0C5050),
            duration: Duration(seconds: 10),
          ));
        }

        // Upload to Firebase Storage
        final downloadUrl = await FirebaseService().uploadProfileImage(file);
        
        if (downloadUrl != null) {
          setState(() {
            _photoUrl = downloadUrl;
            _photoBase64 = null; // Clear old base64
          });
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo de profil mise à jour !'), backgroundColor: Color(0xFF10B981)));
          }
        } else {
          // Fallback to base64 if Storage fails
          final Uint8List bytes = await picked.readAsBytes();
          final base64Str = base64Encode(bytes);
          setState(() { _photoBase64 = base64Str; });
          await FirebaseService().updateCurrentUserData(photoBase64: base64Str);
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo mise à jour (mode local).'), backgroundColor: Color(0xFFD97706)));
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _removePhoto() async {
    setState(() { _photoBase64 = null; _photoUrl = null; });
    await FirebaseService().updateCurrentUserData(photoBase64: '');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo de profil supprimée.'), backgroundColor: Color(0xFF64748B)));
    }
  }

  Widget _buildProfileAvatar({double size = 68, double fontSize = 22, double borderRadius = 18}) {
    // Priority 1: Firebase Storage URL
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
          image: DecorationImage(
            image: NetworkImage(_photoUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    // Priority 2: Legacy base64
    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_photoBase64!);
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
            image: DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover),
          ),
        );
      } catch (_) {}
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Center(
        child: Text(
          _currentName.trim().isNotEmpty
              ? _currentName.trim().split(' ').where((s) => s.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase()
              : 'CL',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _currentName);
    final emailCtrl = TextEditingController(text: _currentEmail);
    final phoneCtrl = TextEditingController(text: _currentPhone);
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
                Icon(Icons.edit_note_rounded, color: Color(0xFF0C5050), size: 26),
                SizedBox(width: 10),
                Text(
                  'Modifier le profil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.titleColor,
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
                      labelText: 'Nom et Prénom',
                      prefixIcon: const Icon(Icons.person_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Nom requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Adresse e-mail',
                      prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) =>
                        v == null || !v.contains('@') ? 'Email invalide' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Numéro de téléphone',
                      prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) {
                      final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      return digits.length < 8
                          ? 'Veuillez saisir un numéro de téléphone valide'
                          : null;
                    },
                  ),
                ],
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
                        setDialogState(() {
                          isSaving = true;
                        });

                        final newName = nameCtrl.text.trim();
                        final newEmail = emailCtrl.text.trim();
                        final newPhone = phoneCtrl.text.trim();

                        final success = await FirebaseService().updateCurrentUserData(
                          fullName: newName,
                          phone: newPhone,
                          email: newEmail,
                        );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }

                        if (mounted) {
                          setState(() {
                            _currentName = newName;
                            _currentEmail = newEmail;
                            _currentPhone = newPhone;
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Profil client mis à jour avec succès !'
                                      : 'Profil client mis à jour !',
                                ),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C5050),
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
                    : const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: Color(0xFF0D544E), size: 24),
                SizedBox(width: 10),
                Text('Sécurité & Mot de passe',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Modifiez directement votre mot de passe pour sécuriser votre compte DAR PLUS.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: currentPassCtrl,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe actuel',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
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
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
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
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      validator: (v) {
                        if (v != newPassCtrl.text) return 'Les mots de passe ne correspondent pas';
                        return null;
                      },
                    ),
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
                            SnackBar(
                              content: Text(result['message'] as String),
                              backgroundColor: const Color(0xFF0D544E),
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
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Mettre à jour'),
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
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter de DAR PLUS ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              await FirebaseService().signOut();
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
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    context.watch<LocaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F2),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP HEADER (matches screenshot 1 exactly)
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: topPadding + 14,
                left: 20,
                right: 20,
                bottom: 24,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0C5050),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Settings Cog Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'profile'.tr(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                        onPressed: _showEditProfileDialog,
                        tooltip: 'Paramètres du profil',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Avatar + User Info Row
                  Row(
                    children: [
                      // Rounded Square Avatar with edit badge
                      Stack(
                        children: [
                          _buildProfileAvatar(),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _showPhotoPickerSheet,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA580C),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // Text details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _currentEmail,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    _currentPhone.isNotEmpty
                                        ? _currentPhone
                                        : 'Numéro non renseigné',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
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

                  const SizedBox(height: 20),

                  // 3 Stat Cards Row (Réservations, Ma note, Favoris)
                  Row(
                    children: [
                      _buildHeaderStatCard(
                        count: '12',
                        label: 'bookings'.tr(),
                      ),
                      const SizedBox(width: 10),
                      _buildHeaderStatCard(
                        count: '4.8',
                        label: 'client_my_rating'.tr(),
                      ),
                      const SizedBox(width: 10),
                      _buildHeaderStatCard(
                        count: '3',
                        label: 'favorites'.tr(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 2. MAIN BODY
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION 1: COMPTE
                  _buildSectionHeader('account_header'.tr()),
                  _buildCardContainer([
                    _buildMenuItem(
                      icon: Icons.edit_outlined,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      title: 'client_edit_profile'.tr(),
                      onTap: _showEditProfileDialog,
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.lock_reset_rounded,
                      iconBg: const Color(0xFFE0E7FF),
                      iconColor: const Color(0xFF4338CA),
                      title: 'client_security_password'.tr(),
                      onTap: _showChangePasswordDialog,
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.notifications_none_rounded,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFF59E0B),
                      title: 'client_notifications'.tr(),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Centre de notifications client')),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.favorite_border_rounded,
                      iconBg: const Color(0xFFFCE7F3),
                      iconColor: const Color(0xFFEC4899),
                      title: 'favorites'.tr(),
                      onTap: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const HomeScreen(initialTab: 2)),
                          (route) => false,
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.assignment_outlined,
                      iconBg: const Color(0xFFE0E7FF),
                      iconColor: const Color(0xFF6366F1),
                      title: 'history'.tr(),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.receipt_long_rounded,
                      iconBg: const Color(0xFFD1FAE5),
                      iconColor: const Color(0xFF059669),
                      title: 'Historique des paiements',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.emoji_events_outlined,
                      iconBg: const Color(0xFFFEF9C3),
                      iconColor: const Color(0xFFEAB308),
                      title: 'loyalty_program'.tr(),
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.confirmation_number_outlined,
                      iconBg: const Color(0xFFFFE4E6),
                      iconColor: const Color(0xFFF43F5E),
                      title: 'coupons_promos'.tr(),
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.map_outlined,
                      iconBg: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      title: 'pros_map'.tr(),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // SECTION 2: PRÉFÉRENCES (matches screenshot 2)
                  _buildSectionHeader('preferences_header'.tr()),
                  _buildCardContainer([
                    _buildThemeTile(Theme.of(context).brightness == Brightness.dark),
                    _buildDivider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          _buildIconBadge(
                            icon: Icons.language_rounded,
                            bgColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFE0F2FE),
                            iconColor: const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'language'.tr(),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Text(
                            context.locale.languageCode == 'fr'
                                ? 'Français'
                                : (context.locale.languageCode == 'en' ? 'English' : 'العربية'),
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // SECTION 3: SUPPORT (matches screenshot 2)
                  _buildSectionHeader('support_header'.tr()),
                  _buildCardContainer([
                    _buildMenuItem(
                      icon: Icons.help_outline_rounded,
                      iconBg: const Color(0xFFFFE4E6),
                      iconColor: const Color(0xFFE11D48),
                      title: 'help'.tr(),
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.star_outline_rounded,
                      iconBg: const Color(0xFFFEF9C3),
                      iconColor: const Color(0xFFEAB308),
                      title: 'rate_app'.tr(),
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildMenuItem(
                      icon: Icons.share_outlined,
                      iconBg: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      title: 'share_app'.tr(),
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // SECTION 4: LANGUE (matches screenshot 3)
                  _buildSectionHeader('language_header'.tr()),
                  _buildCardContainer([
                    _buildLanguageTile(),
                  ]),

                  const SizedBox(height: 24),

                  // SECTION 5: DÉCONNEXION BUTTON (matches screenshot 3)
                  InkWell(
                    onTap: _handleLogout,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.door_back_door_outlined,
                            color: Color(0xFFDC2626),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'logout'.tr(),
                            style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStatCard({
    required String count,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F5B5B), // Slightly lighter teal tint matching screenshot
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildThemeTile(bool isDark) {
    final themeProvider = context.watch<ThemeProvider>();
    final themeMode = themeProvider.themeMode;

    String subtitle = 'theme_system'.tr();
    String badgeText = 'theme_auto'.tr();
    IconData icon = Icons.brightness_auto_rounded;
    Color iconColor = const Color(0xFF3B82F6);
    Color bgColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);

    if (themeMode == ThemeMode.dark) {
      subtitle = 'theme_dark'.tr();
      badgeText = 'theme_dark_badge'.tr();
      icon = Icons.dark_mode_rounded;
      iconColor = const Color(0xFFF59E0B);
      bgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
    } else if (themeMode == ThemeMode.light) {
      subtitle = 'theme_light'.tr();
      badgeText = 'theme_light_badge'.tr();
      icon = Icons.light_mode_rounded;
      iconColor = const Color(0xFFEA580C);
      bgColor = isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFEDD5);
    }

    return InkWell(
      onTap: () => _showThemeDialog(context),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildIconBadge(
              icon: icon,
              bgColor: bgColor,
              iconColor: iconColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'theme_mode'.tr(),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0C5050),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.palette_rounded, color: Color(0xFF0C5050)),
              const SizedBox(width: 10),
              Text('theme_choose'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                ctx: ctx,
                provider: themeProvider,
                mode: ThemeMode.system,
                icon: Icons.brightness_auto_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'theme_system'.tr(),
                subtitle: 'theme_subtitle_system'.tr(),
              ),
              _buildThemeOption(
                ctx: ctx,
                provider: themeProvider,
                mode: ThemeMode.light,
                icon: Icons.light_mode_rounded,
                iconColor: Colors.orange,
                title: 'theme_light'.tr(),
              ),
              _buildThemeOption(
                ctx: ctx,
                provider: themeProvider,
                mode: ThemeMode.dark,
                icon: Icons.dark_mode_rounded,
                iconColor: Colors.amber,
                title: 'theme_dark'.tr(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('close'.tr(), style: const TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext ctx,
    required ThemeProvider provider,
    required ThemeMode mode,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
  }) {
    final isSelected = provider.themeMode == mode;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        provider.setThemeMode(mode);
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
            color: isSelected ? const Color(0xFF0C5050) : Colors.transparent,
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF0C5050), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContainer(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFEAE5DC),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildIconBadge(
              icon: icon,
              bgColor: isDark ? iconColor.withValues(alpha: 0.2) : iconBg,
              iconColor: iconColor,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBadge({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: 19),
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1ECE4),
      indent: 64,
    );
  }

  Widget _buildLanguageTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentCode = context.locale.languageCode;

    const langs = [
      {'code': 'fr', 'flag': '🇫🇷', 'name': 'Français', 'nameKey': 'language_fr'},
      {'code': 'en', 'flag': '🇬🇧', 'name': 'English',  'nameKey': 'language_en'},
      {'code': 'ar', 'flag': '🇹🇳', 'name': 'العربية',  'nameKey': 'language_ar'},
    ];

    final current = langs.firstWhere(
      (l) => l['code'] == currentCode,
      orElse: () => langs[0],
    );

    return InkWell(
      onTap: () => _showLanguageSheet(langs),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _buildIconBadge(
              icon: Icons.language_rounded,
              bgColor: isDark
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFE0F2FE),
              iconColor: const Color(0xFF0284C7),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'language'.tr(),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
            // Badge langue active
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D544E).withValues(alpha: 0.25)
                    : const Color(0xFFD7F3EA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    current['flag'] as String,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    current['name'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D544E),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet(List<Map<String, String>> langs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentCode = context.locale.languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'lang_select_title'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'lang_select_subtitle'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              ...langs.map((lang) {
                final isSelected = lang['code'] == currentCode;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      final targetLocale = Locale(lang['code']!);
                      await context.setLocale(targetLocale);
                      if (mounted) {
                        context
                            .read<LocaleProvider>()
                            .setLocale(targetLocale, context);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0D544E)
                            : (isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF0D544E)
                              : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0)),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            lang['flag']!,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang['name']!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A)),
                                  ),
                                ),
                                Text(
                                  lang['nameKey']!.tr(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.75)
                                        : (isDark
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
