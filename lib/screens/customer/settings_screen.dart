import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../state/locale_notifier.dart';
import '../../state/theme_mode_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class SettingsScreen extends StatelessWidget {
  final LocaleNotifier localeNotifier;
  final ThemeModeNotifier themeModeNotifier;

  const SettingsScreen({
    super.key,
    required this.localeNotifier,
    required this.themeModeNotifier,
  });

  void _showLanguageDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final languages = [
      ('ar', loc.languageArabic),
      ('en', loc.languageEnglish),
      ('ku', loc.languageKurdish),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(loc.profileLanguage),
        children: languages.map(((String, String) entry) {
          final (code, label) = entry;
          final selected = localeNotifier.locale.languageCode == code;
          return SimpleDialogOption(
            onPressed: () {
              localeNotifier.setLocale(code);
              Navigator.pop(ctx);
            },
            child: _RadioRow(
              label: label,
              selected: selected,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showModeDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final modes = [
      (ThemeMode.system, loc.settingsModeSystem),
      (ThemeMode.light, loc.settingsModeLight),
      (ThemeMode.dark, loc.settingsModeDark),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(loc.settingsMode),
        children: modes.map(((ThemeMode, String) entry) {
          final (mode, label) = entry;
          final selected = themeModeNotifier.themeMode == mode;
          return SimpleDialogOption(
            onPressed: () {
              themeModeNotifier.setThemeMode(mode);
              Navigator.pop(ctx);
            },
            child: _RadioRow(
              label: label,
              selected: selected,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _currentModeName(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    switch (themeModeNotifier.themeMode) {
      case ThemeMode.dark:
        return loc.settingsModeDark;
      case ThemeMode.light:
        return loc.settingsModeLight;
      default:
        return loc.settingsModeSystem;
    }
  }

  String _currentLanguageName(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    switch (localeNotifier.locale.languageCode) {
      case 'en':
        return loc.languageEnglish;
      case 'ku':
        return loc.languageKurdish;
      default:
        return loc.languageArabic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([localeNotifier, themeModeNotifier]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(loc.profileSettings)),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _SettingsTile(
                icon: Icons.language,
                title: loc.profileLanguage,
                subtitle: _currentLanguageName(context),
                onTap: () => _showLanguageDialog(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SettingsTile(
                icon: Icons.brightness_6_rounded,
                title: loc.settingsMode,
                subtitle: _currentModeName(context),
                onTap: () => _showModeDialog(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Center(
                  child: Icon(icon, color: AppColors.primary, size: 28),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String label;
  final bool selected;

  const _RadioRow({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? AppColors.primary : AppColors.textSecondary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppColors.primary : null,
          ),
        ),
      ],
    );
  }
}
