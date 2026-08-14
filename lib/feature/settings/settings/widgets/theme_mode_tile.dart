import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/theme/app_theme_mode_controller.dart';
import 'package:trusttunnel/widgets/common/custom_list_tile_separated.dart';
import 'package:trusttunnel/widgets/custom_icon.dart';

class ThemeModeTile extends StatelessWidget {
  const ThemeModeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeModeScope.controllerOf(context);

    return CustomListTileSeparated(
      title: context.ln.theme,
      subtitle: _labelFor(context, controller.themeMode),
      onTileTap: () => _showThemeDialog(context, controller),
      showVerticalDivider: false,
      trailing: CustomIcon.medium(
        icon: AssetIcons.navigateNext,
        color: context.colors.neutralDark,
      ),
    );
  }

  Future<void> _showThemeDialog(
    BuildContext context,
    AppThemeModeController controller,
  ) async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.ln.theme),
        children: ThemeMode.values
            .map(
              (mode) => RadioListTile<ThemeMode>(
                value: mode,
                groupValue: controller.themeMode,
                title: Text(_labelFor(context, mode)),
                onChanged: (value) => Navigator.of(context).pop(value),
              ),
            )
            .toList(),
      ),
    );

    if (selected != null) {
      await controller.setThemeMode(selected);
    }
  }

  String _labelFor(BuildContext context, ThemeMode mode) => switch (mode) {
    ThemeMode.system => context.ln.themeSystem,
    ThemeMode.light => context.ln.themeLight,
    ThemeMode.dark => context.ln.themeDark,
  };
}
