import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'admin_requests_screen.dart';

enum AccountType { client, professionnel, admin }

class RegisterScreen extends StatefulWidget {
  final AccountType initialType;

  const RegisterScreen({
    super.key,
    this.initialType = AccountType.client,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late AccountType _accountType;
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cinController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _adminKeyController = TextEditingController();

  String? _selectedServiceType;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = true;
  bool _isLoading = false;
  bool _passwordMismatch = false;

  final List<String> _serviceTypes = const [
    'Plomberie & Sanitaire',
    'Électricité & Éclairage',
    'Ménage & Nettoyage à domicile',
    'Bricolage & Petits Travaux',
    'Cuisine & Chef à domicile',
    'Peinture & Rénovation',
    'Climatisation & Chauffage',
    'Menuiserie & Meubles',
    'Jardinage & Espaces verts',
    'Serrurerie & Dépannage',
  ];

  @override
  void initState() {
    super.initState();
    _accountType = widget.initialType;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _cinController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _adminKeyController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _passwordMismatch = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les mots de passe ne correspondent pas.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les conditions d\'utilisation.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (_accountType == AccountType.professionnel && _selectedServiceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner votre domaine de service.'),
          backgroundColor: Color(0xFFEA580C),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final firebaseService = FirebaseService();

    if (_accountType == AccountType.client) {
      // 1. Inscription CLIENT dans Firebase
      final phone = _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : '+216 50 000 000';

      final result = await firebaseService.registerClient(
        fullName: _fullNameController.text,
        phone: phone,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        _showClientEmailVerificationDialog(_emailController.text);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else if (_accountType == AccountType.professionnel) {
      // 2. Soumission Demande PROFESSIONNEL pour examen Admin
      final phone = _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : '+216 52 000 000';

      final result = await firebaseService.submitProApplication(
        fullName: _fullNameController.text,
        phone: phone,
        email: _emailController.text,
        password: _passwordController.text,
        cin: _cinController.text.trim(),
        serviceType: _selectedServiceType!,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        final proApp = ProApplication(
          id: result['id'] ?? 'pro_${DateTime.now().millisecondsSinceEpoch}',
          fullName: _fullNameController.text,
          phone: phone,
          email: _emailController.text,
          cin: _cinController.text.trim(),
          serviceType: _selectedServiceType!,
          status: 'en_attente',
          createdAt: DateTime.now(),
        );

        _showProSuccessDialog();

        // Notification active pour l'administrateur
        NotificationService.showClickableAdminBanner(
          context,
          InAppNotification(
            id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Nouvelle demande Pro reçue !',
            message:
                '${_fullNameController.text} souhaite créer un compte pour "${_selectedServiceType!}". Cliquez pour vérifier ses coordonnées.',
            proApplication: proApp,
            timestamp: DateTime.now(),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminRequestsScreen(
                  highlightAppId: proApp.id,
                ),
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } else {
      // 3. Création Compte ADMINISTRATEUR
      final result = await firebaseService.registerAdmin(
        fullName: _fullNameController.text,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : '+216 71 000 000',
        email: _emailController.text,
        password: _passwordController.text,
        adminSecretKey: _adminKeyController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        _showAdminSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showClientEmailVerificationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Compte Client créé !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Félicitations ${_fullNameController.text} !\nVotre compte client a été créé avec succès avec l\'adresse :\n$email',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                // Button 1: Accéder immédiatement à l'espace client
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => HomeScreen(
                            userName: _fullNameController.text.trim().isNotEmpty
                                ? _fullNameController.text.trim()
                                : 'Client',
                            userEmail: _emailController.text.trim(),
                            userPhone: _phoneController.text.trim(),
                          ),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text(
                      'Accéder à mon espace',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D544E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Button 2: Aller à la connexion
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(prefilledEmail: email),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D544E),
                      side: const BorderSide(color: Color(0xFF0D544E)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Se connecter',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFFEA580C),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Compte Professionnel créé !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Merci ${_fullNameController.text} !\nVotre profil professionnel ($_selectedServiceType) a été transmis à l\'administrateur DAR PLUS. Vos coordonnées seront confirmées avant activation.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(
                            prefilledEmail: _emailController.text,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D544E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Aller à la connexion',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAdminSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF7C3AED),
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Compte Admin créé !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Le compte administrateur ${_fullNameController.text} (${_emailController.text}) a été créé avec succès avec les droits de supervision DAR PLUS.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => LoginScreen(
                            prefilledEmail: _emailController.text,
                          ),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D544E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Se connecter comme Administrateur',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        top: true,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Bouton Retour (Squircle blanc épuré) + Logo Dar Plus
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: Color(0xFF0F172A),
                          size: 28,
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // 2. Titre & Sous-titre (Exactement comme le screenshot)
                const Text(
                  'Créer un compte',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Rejoignez Dar Plus en quelques secondes.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 22),

                // 3. Sélecteur de rôle Segmenté (Client / Professionnel)
                Container(
                  height: 52,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6EEEC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildSegmentTab(
                        title: 'Client',
                        icon: Icons.person_outline_rounded,
                        isSelected: _accountType == AccountType.client,
                        onTap: () {
                          setState(() {
                            _accountType = AccountType.client;
                          });
                        },
                      ),
                      _buildSegmentTab(
                        title: 'Professionnel',
                        icon: Icons.build_outlined,
                        isSelected: _accountType == AccountType.professionnel,
                        onTap: () {
                          setState(() {
                            _accountType = AccountType.professionnel;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // 4. Champ : Nom complet
                _buildFieldLabel('Nom complet'),
                _buildCustomTextField(
                  controller: _fullNameController,
                  hintText: 'Yasmine Ouertani',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Veuillez saisir votre nom complet' : null,
                ),

                const SizedBox(height: 18),

                // 5. Champ : Adresse e-mail
                _buildFieldLabel('Adresse e-mail'),
                _buildCustomTextField(
                  controller: _emailController,
                  hintText: 'yasmine@exemple.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || !v.contains('@') ? 'Veuillez saisir une adresse e-mail valide' : null,
                ),

                // Si Professionnel : Spécialité et Téléphone pro
                if (_accountType == AccountType.professionnel) ...[
                  const SizedBox(height: 18),
                  _buildFieldLabel('Spécialité / Métier'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDDE3EA), width: 1.2),
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedServiceType,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.handyman_outlined, color: Color(0xFF0D544E), size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      hint: const Text(
                        'Sélectionnez votre métier',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14.5),
                      ),
                      icon: const Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                      ),
                      isExpanded: true,
                      items: _serviceTypes.map((service) {
                        return DropdownMenuItem(
                          value: service,
                          child: Text(
                            service,
                            style: const TextStyle(fontSize: 14.5, color: Color(0xFF0F172A)),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedServiceType = val;
                        });
                      },
                      validator: (v) => v == null ? 'Veuillez sélectionner un métier' : null,
                    ),
                  ),

                  const SizedBox(height: 18),
                  _buildFieldLabel('Numéro de téléphone'),
                  _buildCustomTextField(
                    controller: _phoneController,
                    hintText: '+216 52 123 456',
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Numéro de téléphone requis' : null,
                  ),

                  const SizedBox(height: 18),
                  _buildFieldLabel('Numéro CIN (Carte d\'Identité Nationale)'),
                  _buildCustomTextField(
                    controller: _cinController,
                    hintText: 'Ex: 08123456 (8 chiffres)',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (_accountType == AccountType.professionnel) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Numéro CIN requis';
                        }
                        final clean = v.trim();
                        if (clean.length != 8 || int.tryParse(clean) == null) {
                          return 'Le CIN doit comporter exactement 8 chiffres';
                        }
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 18),

                // 6. Champ : Mot de passe
                _buildFieldLabel('Mot de passe'),
                _buildCustomTextField(
                  controller: _passwordController,
                  hintText: '••••••••••',
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onToggleObscure: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  onChanged: (val) {
                    if (_confirmPasswordController.text.isNotEmpty) {
                      setState(() {
                        _passwordMismatch = _confirmPasswordController.text != val;
                      });
                    }
                  },
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Le mot de passe doit comporter au moins 6 caractères' : null,
                ),
                const SizedBox(height: 6),
                const Text(
                  '8 caractères minimum, avec un chiffre.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 18),

                // 7. Champ : Confirmer le mot de passe (avec gestion visuelle de l'erreur comme le screenshot)
                _buildFieldLabel('Confirmer le mot de passe'),
                _buildCustomTextField(
                  controller: _confirmPasswordController,
                  hintText: '••••••••••',
                  isPassword: true,
                  obscureText: _obscureConfirmPassword,
                  hasError: _passwordMismatch,
                  onToggleObscure: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  onChanged: (val) {
                    setState(() {
                      _passwordMismatch = val.isNotEmpty && val != _passwordController.text;
                    });
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Veuillez confirmer votre mot de passe';
                    }
                    if (v != _passwordController.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),
                if (_passwordMismatch) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Les mots de passe ne correspondent pas.',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 18),

                // 8. Case à cocher : J'accepte les conditions d'utilisation
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _acceptTerms = !_acceptTerms;
                    });
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _acceptTerms ? const Color(0xFF0D544E) : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _acceptTerms ? const Color(0xFF0D544E) : const Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _acceptTerms
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'J\'accepte les conditions d\'utilisation et la politique de confidentialité.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 9. Bannière d'information Pro (Jaune pastel comme le screenshot)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFFB45309),
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Les profils professionnels sont validés par un administrateur avant d\'être visibles.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF92400E),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // 10. Bouton d'action principal : Créer mon compte (Vert foncé #0D544E)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D544E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Créer mon compte',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 18),

                // 11. Lien bas de page : Déjà inscrit ? Se connecter
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Déjà inscrit ? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Se connecter',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D544E),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hintText,
    bool isPassword = false,
    bool? obscureText,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool hasError = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? (obscureText ?? true) : false,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 14.5,
        ),
        filled: true,
        fillColor: hasError ? const Color(0xFFFEF2F2) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  (obscureText ?? true)
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFE53935) : const Color(0xFFDDE3EA),
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFE53935) : const Color(0xFFDDE3EA),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: hasError ? const Color(0xFFE53935) : const Color(0xFF0D544E),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE53935),
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFE53935),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF0D544E) : const Color(0xFF475569),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0D544E) : const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
