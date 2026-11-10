import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../core/localization/app_localizations.dart';
import '../core/routing/app_routes.dart';

class AppDrawer extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String userPhone;
  final String role;
  final String? photoBase64;
  final VoidCallback? onProfileTap;

  const AppDrawer({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    this.role = 'Client',
    this.photoBase64,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final loc = AppLocalizations.of(context);
    final isDark = themeProvider.isDark(context);

    return Drawer(
      child: Column(
        children: [
          // Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                    : [const Color(0xFF0D544E), const Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFF0D544E),
                ),
              ),
            ),
            accountName: Row(
              children: [
                Text(
                  userName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ],
            ),
            accountEmail: Text(userEmail),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.home_rounded),
                  title: Text(loc.translate('home')),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: Text(loc.translate('profile')),
                  onTap: () {
                    Navigator.pop(context);
                    if (onProfileTap != null) {
                      onProfileTap!();
                    } else {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.profile,
                        arguments: {
                          'userName': userName,
                          'userEmail': userEmail,
                          'userPhone': userPhone,
                        },
                      );
                    }
                  },
                ),
                const Divider(),

                // Theme Mode Selector (Système, Clair, Sombre)
                ListTile(
                  leading: Icon(
                    themeProvider.themeMode == ThemeMode.system
                        ? Icons.brightness_auto_rounded
                        : (isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
                    color: isDark ? Colors.amber : const Color(0xFF0D544E),
                  ),
                  title: Text(loc.translate('theme_mode')),
                  subtitle: Text(
                    themeProvider.themeMode == ThemeMode.system
                        ? loc.translate('theme_system')
                        : (themeProvider.themeMode == ThemeMode.dark
                            ? loc.translate('theme_dark')
                            : loc.translate('theme_light')),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showThemeDialog(context, themeProvider, loc),
                ),

                // Language Selector
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(loc.translate('language')),
                  trailing: DropdownButton<String>(
                    value: localeProvider.locale.languageCode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'fr', child: Text('Français 🇫🇷')),
                      DropdownMenuItem(value: 'en', child: Text('English 🇬🇧')),
                      DropdownMenuItem(value: 'ar', child: Text('العربية 🇹🇳')),
                    ],
                    onChanged: (lang) async {
                      if (lang != null) {
                        final newLoc = Locale(lang);
                        await context.setLocale(newLoc);
                        if (context.mounted) {
                          localeProvider.setLocale(newLoc);
                        }
                      }
                    },
                  ),
                ),

                const Divider(),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(loc.translate('about')),
                  onTap: () {
                    Navigator.pop(context);
                    showAboutDialog(
                      context: context,
                      applicationName: 'DAR PLUS',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2026 DAR PLUS - Tous droits réservés.',
                    );
                  },
                ),
              ],
            ),
          ),

          // Logout Button at bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.red.shade200),
              ),
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: Text(
                loc.translate('logout'),
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(
    BuildContext context,
    ThemeProvider themeProvider,
    AppLocalizations loc,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.palette_rounded, color: Color(0xFF0D544E)),
              const SizedBox(width: 10),
              Text(loc.translate('theme_choose'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDrawerThemeOption(
                ctx: ctx,
                provider: themeProvider,
                mode: ThemeMode.system,
                icon: Icons.brightness_auto_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: loc.translate('theme_system'),
                subtitle: loc.translate('theme_subtitle_system'),
                isDark: isDark,
              ),
              _buildDrawerThemeOption(
                ctx: ctx,
                provider: themeProvider,
                mode: ThemeMode.light,
                icon: Icons.light_mode_rounded,
                iconColor: Colors.orange,
                title: loc.translate('theme_light'),
                isDark: isDark,
              ),
              _buildDrawerThemeOption(
                ctx: ctx,
                provider: themeProvider,
                mode: ThemeMode.dark,
                icon: Icons.dark_mode_rounded,
                iconColor: Colors.amber,
                title: loc.translate('theme_dark'),
                isDark: isDark,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.translate('cancel'), style: const TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDrawerThemeOption({
    required BuildContext ctx,
    required ThemeProvider provider,
    required ThemeMode mode,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool isDark,
  }) {
    final isSelected = provider.themeMode == mode;

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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF0D544E), size: 20),
          ],
        ),
      ),
    );
  }
}
