import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../widgets/professional_input_field.dart';
import '../widgets/contact_admin_sheet.dart';
import 'home_screen.dart';
import 'login_screen.dart';

enum AccountType { client, professionnel }

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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedServiceType;
  bool _obscurePassword = true;
  bool _isLoading = false;

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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_accountType == AccountType.professionnel && _selectedServiceType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner votre type de service.'),
          backgroundColor: AppTheme.orangePrimary,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final firebaseService = FirebaseService();

    if (_accountType == AccountType.client) {
      // 1. Inscription CLIENT
      final result = await firebaseService.registerClient(
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String),
            backgroundColor: AppTheme.tealPrimary,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
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
      // 2. Soumission Demande PROFESSIONNEL pour l'Admin
      final result = await firebaseService.submitProApplication(
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        password: _passwordController.text,
        serviceType: _selectedServiceType!,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        _showProSuccessDialog();
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
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppTheme.tealPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.tealPrimary,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Demande transmise à l\'Admin !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.titleColor,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Merci ${_fullNameController.text}.\nVotre demande de création de compte professionnel pour le service "$_selectedServiceType" a été envoyée avec succès à l\'administrateur DAR PLUS.\n\nVous serez contacté sous 24h par notre équipe pour finaliser l\'activation.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                // Contacter admin button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ContactAdminSheet.show(context);
                  },
                  icon: const Icon(Icons.headset_mic_rounded, size: 18),
                  label: const Text('Nous contacter directement'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.tealPrimary,
                    side: const BorderSide(color: AppTheme.tealPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Terminer
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.tealPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Retour à l\'accueil',
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
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Dark Teal Top Header (matches screenshot)
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
                  // Back button
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Retour',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Title
                  const Text(
                    'S\'inscrire',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'serif',
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Subtitle
                  Text(
                    'Vos services à domicile',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                ],
              ),
            ),

            // 2. Body with Toggle and Input Fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Segmented Toggle: Client / Professionnel (matches screenshot)
                    Container(
                      height: 54,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECE8E1),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        children: [
                          // Tab 1: Client
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _accountType = AccountType.client;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: _accountType == AccountType.client
                                      ? const Color(0xFF0C5050)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      size: 18,
                                      color: _accountType == AccountType.client
                                          ? Colors.white
                                          : const Color(0xFF7A8696),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Client',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: _accountType == AccountType.client
                                            ? Colors.white
                                            : const Color(0xFF6B7A8E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Tab 2: Professionnel
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _accountType = AccountType.professionnel;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: _accountType == AccountType.professionnel
                                      ? const Color(0xFF0C5050)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.build_rounded,
                                      size: 16,
                                      color: _accountType == AccountType.professionnel
                                          ? Colors.white
                                          : const Color(0xFF7A8696),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Professionnel',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: _accountType == AccountType.professionnel
                                            ? Colors.white
                                            : const Color(0xFF6B7A8E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Professional Notice & Direct Contact Link (Requested feature)
                    if (_accountType == AccountType.professionnel)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C5050).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF0C5050).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              color: Color(0xFF0C5050),
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Demande de validation Partenaire',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0C5050),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'L\'admin recevra votre demande pour créer votre compte.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: const Color(0xFF0C5050).withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => ContactAdminSheet.show(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Nous contacter',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.orangePrimary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Field 1: Nom complet
                    ProfessionalInputField(
                      controller: _fullNameController,
                      hintText: 'Ahmed Ben Salah',
                      iconType: ProfessionalIconType.user,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir votre nom complet';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Field 2: Téléphone
                    ProfessionalInputField(
                      controller: _phoneController,
                      hintText: '+216 XX XXX XXX',
                      iconType: ProfessionalIconType.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Veuillez saisir votre numéro de téléphone';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Field 3: Email
                    ProfessionalInputField(
                      controller: _emailController,
                      hintText: 'nom@email.com',
                      iconType: ProfessionalIconType.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'Veuillez saisir une adresse email valide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Field 4: Mot de passe
                    ProfessionalInputField(
                      controller: _passwordController,
                      hintText: '••••••••',
                      iconType: ProfessionalIconType.password,
                      isPassword: true,
                      obscureText: _obscurePassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Le mot de passe doit comporter au moins 6 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Field 5: Type de service (Visible ONLY when Professionnel is selected)
                    if (_accountType == AccountType.professionnel) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE8E4DC),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedServiceType,
                          decoration: InputDecoration(
                            prefixIcon: Container(
                              width: 32,
                              height: 32,
                              margin: const EdgeInsets.only(left: 14, right: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.build_rounded,
                                color: Color(0xFF64748B),
                                size: 18,
                              ),
                            ),
                            prefixIconConstraints:
                                const BoxConstraints(minWidth: 58, minHeight: 48),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          hint: const Text(
                            'Type de service',
                            style: TextStyle(
                              color: Color(0xFF8B98A8),
                              fontSize: 14.5,
                            ),
                          ),
                          icon: const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF0C5050),
                              size: 26,
                            ),
                          ),
                          isExpanded: true,
                          items: _serviceTypes.map((service) {
                            return DropdownMenuItem(
                              value: service,
                              child: Text(
                                service,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: Color(0xFF0B1B2B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedServiceType = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    const SizedBox(height: 6),

                    // Terms disclaimer (matches screenshot)
                    Text(
                      'En m\'inscrivant, j\'accepte les Conditions d\'utilisation et la Politique de confidentialité',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF6B7A8E).withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Button: S'inscrire (Terracotta / Orange, matches screenshot)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.orangePrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'S\'inscrire',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Footer Link: Déjà un compte ? Connexion (matches screenshot)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Déjà un compte ? ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7A8E),
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
                            'Connexion',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0C5050),
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
          ],
        ),
      ),
    );
  }
}
