import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service d'envoi d'emails via EmailJS REST API.
///
/// EmailJS autorise les appels CORS depuis Flutter Web — aucun proxy nécessaire.
/// Le template HTML complet est généré côté Dart et envoyé comme variable.
///
/// ─── CONFIGURATION (à remplir une seule fois) ────────────────────────────
/// 1. Créez un compte gratuit sur https://emailjs.com
/// 2. Email Services → Add New Service → choisissez Gmail → connectez votre compte
///    → notez le SERVICE ID (ex: service_abc123)
/// 3. Email Templates → Create New Template → dans le body HTML mettez juste :
///       {{{html_body}}}
///    et dans Subject : {{subject}}
///    → notez le TEMPLATE ID (ex: template_xyz789)
/// 4. Account → General → API Keys → copiez la PUBLIC KEY
/// ─────────────────────────────────────────────────────────────────────────
class EmailService {
  static const String _serviceId  = 'service_zg0xu1t';   // Votre Service ID SMTP
  static const String _templateId = 'template_ppiwd7b';  // Votre Template ID
  static const String _publicKey  = '8HgQH6Ou_rETVjTLu';   // Votre Public Key EmailJS

  /// Envoie un email de bienvenue à un nouvel administrateur.
  /// Le beau template HTML est entièrement généré ici, dans le code Dart.
  static Future<bool> sendNewAdminCredentials({
    required String toEmail,
    required String adminName,
    required String generatedPassword,
  }) async {
    final htmlBody = _buildAdminWelcomeHtml(
      adminName: adminName,
      toEmail: toEmail,
      generatedPassword: generatedPassword,
    );

    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id':  _serviceId,
          'template_id': _templateId,
          'user_id':     _publicKey,
          'template_params': {
            'to_email': toEmail,
            'to_name':  adminName,
            'from_name': 'DAR PLUS',
            'name': 'DAR PLUS',
            'subject':  'Vos accès Administrateur DAR PLUS',
            'html_body': htmlBody,  // Le HTML complet passe ici
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Email envoyé avec succès à $toEmail via EmailJS !');
        return true;
      } else {
        debugPrint('❌ EmailJS erreur ${response.statusCode}: ${response.body}');
        _logFallback(toEmail, adminName, generatedPassword);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur réseau EmailJS: $e');
      _logFallback(toEmail, adminName, generatedPassword);
      return false;
    }
  }

  /// Envoie un email de réinitialisation de mot de passe avec un mot de passe temporaire
  static Future<bool> sendPasswordResetEmail({
    required String toEmail,
    required String userName,
    required String temporaryPassword,
  }) async {
    final htmlBody = _buildPasswordResetHtml(
      userName: userName,
      toEmail: toEmail,
      temporaryPassword: temporaryPassword,
    );

    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': toEmail,
            'to_name': userName,
            'from_name': 'DAR PLUS',
            'name': 'DAR PLUS',
            'subject': 'Réinitialisation de votre mot de passe DAR PLUS',
            'html_body': htmlBody,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Email de réinitialisation envoyé avec succès à $toEmail via EmailJS !');
        return true;
      } else {
        debugPrint('❌ EmailJS erreur ${response.statusCode}: ${response.body}');
        _logFallback(toEmail, userName, temporaryPassword);
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur réseau EmailJS: $e');
      _logFallback(toEmail, userName, temporaryPassword);
      return false;
    }
  }

  /// Envoie un email d'acceptation de compte professionnel
  static Future<bool> sendProApprovedEmail({
    required String toEmail,
    required String proName,
    required String serviceType,
  }) async {
    final htmlBody = _buildProApprovedHtml(
      proName: proName,
      serviceType: serviceType,
    );

    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': toEmail,
            'to_name': proName,
            'from_name': 'DAR PLUS',
            'name': 'DAR PLUS',
            'subject': 'Félicitations ! Votre compte professionnel DAR PLUS est validé',
            'html_body': htmlBody,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Email d\'acceptation envoyé avec succès à $toEmail via EmailJS !');
        return true;
      } else {
        debugPrint('❌ EmailJS erreur ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur réseau EmailJS: $e');
      return false;
    }
  }

  /// Envoie un email de refus de candidature avec le motif rédigé par l'administrateur
  static Future<bool> sendProRejectedEmail({
    required String toEmail,
    required String proName,
    required String reason,
  }) async {
    final htmlBody = _buildProRejectedHtml(
      proName: proName,
      reason: reason,
    );

    try {
      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': toEmail,
            'to_name': proName,
            'from_name': 'DAR PLUS',
            'name': 'DAR PLUS',
            'subject': 'Mise à jour concernant votre candidature DAR PLUS',
            'html_body': htmlBody,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Email de refus envoyé avec succès à $toEmail via EmailJS !');
        return true;
      } else {
        debugPrint('❌ EmailJS erreur ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur réseau EmailJS: $e');
      return false;
    }
  }

  static void _logFallback(String email, String name, String pwd) {
    if (kDebugMode) {
      debugPrint('=== [FALLBACK — EMAIL NON ENVOYÉ] ===');
      debugPrint('Destinataire : $email ($name)');
      debugPrint('Mot de passe : $pwd');
      debugPrint('=====================================');
    }
  }

  /// Template HTML complet pour l'invitation d'un administrateur DAR PLUS.
  static String _buildAdminWelcomeHtml({
    required String adminName,
    required String toEmail,
    required String generatedPassword,
  }) {
    final year = DateTime.now().year;
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; }
    .card { max-width: 540px; margin: 0 auto; background: #ffffff; border-radius: 18px; padding: 32px; border: 1px solid #e2e8f0; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
    .badge { display: inline-block; background-color: #0D544E; color: #ffffff; padding: 6px 14px; border-radius: 20px; font-weight: bold; font-size: 13px; margin-bottom: 16px; }
    h2 { color: #0F172A; margin-top: 0; font-size: 22px; }
    p { color: #475569; font-size: 14.5px; line-height: 1.6; }
    .credentials { background-color: #f1f5f9; border-radius: 14px; padding: 20px; margin: 24px 0; border: 1px solid #cbd5e1; }
    .cred-line { display: flex; justify-content: space-between; margin-bottom: 10px; font-size: 14px; }
    .cred-line:last-child { margin-bottom: 0; }
    .cred-label { color: #64748B; font-weight: 500; }
    .cred-val { color: #0F172A; font-weight: bold; font-family: monospace; font-size: 15px; }
    .pwd { color: #7C3AED; background: #EDE9FE; padding: 4px 10px; border-radius: 8px; }
    .alert { background: #FEF3C7; border: 1px solid #FDE68A; border-radius: 12px; padding: 12px 16px; color: #92400E; font-size: 13px; line-height: 1.4; margin-top: 20px; }
    .footer { text-align: center; margin-top: 24px; color: #94a3b8; font-size: 12px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">DAR PLUS • Administration</div>
    <h2>Bienvenue dans l'équipe, $adminName !</h2>
    <p>Votre compte administrateur sur la plateforme <strong>DAR PLUS</strong> a été créé avec succès.</p>

    <div class="credentials">
      <div class="cred-line">
        <span class="cred-label">Identifiant (Email) :</span>
        <span class="cred-val">$toEmail</span>
      </div>
      <div class="cred-line" style="margin-top: 12px;">
        <span class="cred-label">Mot de passe temporaire :</span>
        <span class="cred-val pwd">$generatedPassword</span>
      </div>
      <div class="cred-line" style="margin-top: 12px;">
        <span class="cred-label">Rôle :</span>
        <span class="cred-val">Administrateur</span>
      </div>
    </div>

    <div class="alert">
      <strong>Conseil de sécurité :</strong> Pour des raisons de confidentialité,
      nous vous recommandons de modifier ce mot de passe dès votre première
      connexion dans votre onglet <em>Profil</em>.
    </div>

    <p style="margin-top: 24px;">Vous pouvez dès à présent vous connecter pour superviser les demandes, valider les prestataires et gérer les utilisateurs.</p>

    <div class="footer">© $year DAR PLUS. Tous droits réservés.</div>
  </div>
</body>
</html>''';
  }

  /// Template HTML : Candidature Professionnelle Acceptée
  static String _buildProApprovedHtml({
    required String proName,
    required String serviceType,
  }) {
    final year = DateTime.now().year;
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; }
    .card { max-width: 540px; margin: 0 auto; background: #ffffff; border-radius: 18px; padding: 32px; border: 1px solid #e2e8f0; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
    .badge { display: inline-block; background-color: #10B981; color: #ffffff; padding: 6px 14px; border-radius: 20px; font-weight: bold; font-size: 13px; margin-bottom: 16px; }
    h2 { color: #0F172A; margin-top: 0; font-size: 22px; }
    p { color: #475569; font-size: 14.5px; line-height: 1.6; }
    .highlight { background-color: #ECFDF5; border: 1px solid #A7F3D0; border-radius: 14px; padding: 18px; margin: 20px 0; color: #065F46; }
    .info-line { display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 14px; }
    .info-line:last-child { margin-bottom: 0; }
    .info-label { color: #047857; font-weight: 600; }
    .info-val { color: #064E3B; font-weight: bold; }
    .cta-button { display: inline-block; background-color: #0D544E; color: #ffffff !important; padding: 14px 28px; border-radius: 12px; font-weight: bold; text-decoration: none; font-size: 15px; margin-top: 20px; text-align: center; }
    .footer { text-align: center; margin-top: 28px; color: #94a3b8; font-size: 12px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">DAR PLUS • Partenaire Professionnel</div>
    <h2>Félicitations, $proName ! 🎉</h2>
    <p>Nous avons le plaisir de vous informer que votre candidature en tant que professionnel sur <strong>DAR PLUS</strong> a été vérifiée et <strong>validée avec succès</strong>.</p>

    <div class="highlight">
      <div class="info-line">
        <span class="info-label">Spécialité activée :</span>
        <span class="info-val">$serviceType</span>
      </div>
      <div class="info-line" style="margin-top: 10px;">
        <span class="info-label">Statut du compte :</span>
        <span class="info-val">Actif & Vérifié ✅</span>
      </div>
    </div>

    <p>Votre profil est dès à présent visible auprès des clients. Vous pouvez vous connecter avec vos identifiants pour accéder à votre tableau de bord, gérer vos disponibilités et recevoir des demandes d'interventions.</p>

    <div class="footer">© $year DAR PLUS. Tous droits réservés.</div>
  </div>
</body>
</html>''';
  }

  /// Template HTML : Candidature Professionnelle Rejetée (avec cause)
  static String _buildProRejectedHtml({
    required String proName,
    required String reason,
  }) {
    final year = DateTime.now().year;
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; }
    .card { max-width: 540px; margin: 0 auto; background: #ffffff; border-radius: 18px; padding: 32px; border: 1px solid #e2e8f0; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
    .badge { display: inline-block; background-color: #EF4444; color: #ffffff; padding: 6px 14px; border-radius: 20px; font-weight: bold; font-size: 13px; margin-bottom: 16px; }
    h2 { color: #0F172A; margin-top: 0; font-size: 22px; }
    p { color: #475569; font-size: 14.5px; line-height: 1.6; }
    .reason-box { background-color: #FEF2F2; border-left: 4px solid #EF4444; border-radius: 0 12px 12px 0; padding: 18px 20px; margin: 22px 0; }
    .reason-title { color: #991B1B; font-weight: bold; font-size: 14px; margin-bottom: 6px; }
    .reason-content { color: #7F1D1D; font-size: 14.5px; line-height: 1.5; font-style: italic; }
    .footer { text-align: center; margin-top: 28px; color: #94a3b8; font-size: 12px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">DAR PLUS • Candidatures</div>
    <h2>Bonjour $proName,</h2>
    <p>Nous vous remercions pour l'intérêt que vous portez à <strong>DAR PLUS</strong> et pour votre démarche d'inscription en tant que professionnel partenaire.</p>
    <p>Après examen attentif de votre dossier et des documents fournis, nous avons le regret de vous informer que votre candidature ne peut pas être validée pour le moment.</p>

    <div class="reason-box">
      <div class="reason-title">Motif indiqué par l'administration :</div>
      <div class="reason-content">« $reason »</div>
    </div>

    <p>Si vous souhaitez apporter des pièces complémentaires ou corriger vos informations pour soumettre une nouvelle candidature, n'hésitez pas à répondre à cet e-mail ou à vous réinscrire.</p>

    <div class="footer">© $year DAR PLUS. Tous droits réservés.</div>
  </div>
</body>
</html>''';
  }

  /// Template HTML pour réinitialisation de mot de passe
  static String _buildPasswordResetHtml({
    required String userName,
    required String toEmail,
    required String temporaryPassword,
  }) {
    final year = DateTime.now().year;
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; }
    .card { max-width: 540px; margin: 0 auto; background: #ffffff; border-radius: 18px; padding: 32px; border: 1px solid #e2e8f0; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
    .badge { display: inline-block; background-color: #0D544E; color: #ffffff; padding: 6px 14px; border-radius: 20px; font-weight: bold; font-size: 13px; margin-bottom: 16px; }
    h2 { color: #0F172A; margin-top: 0; font-size: 22px; }
    p { color: #475569; font-size: 14.5px; line-height: 1.6; }
    .credentials { background-color: #f1f5f9; border-radius: 14px; padding: 20px; margin: 24px 0; border: 1px solid #cbd5e1; }
    .cred-line { display: flex; justify-content: space-between; margin-bottom: 10px; font-size: 14px; }
    .cred-line:last-child { margin-bottom: 0; }
    .cred-label { color: #64748B; font-weight: 500; }
    .cred-val { color: #0F172A; font-weight: bold; font-family: monospace; font-size: 15px; }
    .pwd { color: #0D544E; background: #E6F4F1; padding: 4px 10px; border-radius: 8px; font-size: 17px; }
    .alert { background: #FEF3C7; border: 1px solid #FDE68A; border-radius: 12px; padding: 12px 16px; color: #92400E; font-size: 13px; line-height: 1.4; margin-top: 20px; }
    .footer { text-align: center; margin-top: 24px; color: #94a3b8; font-size: 12px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">DAR PLUS • Sécurité</div>
    <h2>Réinitialisation de mot de passe</h2>
    <p>Bonjour <strong>$userName</strong>,</p>
    <p>Une demande de réinitialisation de mot de passe a été effectuée pour votre compte <strong>DAR PLUS</strong> ($toEmail).</p>

    <div class="credentials">
      <div class="cred-line">
        <span class="cred-label">Identifiant (Email) :</span>
        <span class="cred-val">$toEmail</span>
      </div>
      <div class="cred-line" style="margin-top: 14px;">
        <span class="cred-label">Nouveau mot de passe temporaire :</span>
        <span class="cred-val pwd">$temporaryPassword</span>
      </div>
    </div>

    <div class="alert">
      <strong>Important :</strong> Pour votre sécurité, utilisez ce mot de passe pour vous connecter, puis modifiez-le immédiatement depuis votre profil ou lors de l'invite de connexion.
    </div>

    <p style="margin-top: 24px; font-size: 13px; color: #64748B;">Si vous n'êtes pas à l'origine de cette demande, veuillez contacter l'administration de DAR PLUS immédiatement.</p>

    <div class="footer">© $year DAR PLUS. Tous droits réservés.</div>
  </div>
</body>
</html>''';
  }
}
