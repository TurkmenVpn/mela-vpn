import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:melavpn/core/app_info/app_info_provider.dart';
import 'package:melavpn/core/device_id/device_id_provider.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/model/failures.dart';
import 'package:melavpn/core/preferences/general_preferences.dart';
import 'package:melavpn/core/router/dialog/dialog_notifier.dart';
import 'package:melavpn/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/features/app_update/notifier/app_update_notifier.dart';
import 'package:melavpn/features/app_update/notifier/app_update_state.dart';
import 'package:melavpn/features/profile/notifier/active_profile_notifier.dart';
import 'package:melavpn/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:melavpn/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:melavpn/core/notification/in_app_notification_controller.dart';
import 'package:melavpn/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: 'warp-section-key');
  static final _fragmentKey = GlobalKey(debugLabel: 'fragment-section-key');

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final appInfo = ref.watch(appInfoProvider).requireValue;
    final appUpdate = ref.watch(appUpdateNotifierProvider);

    ref.listen(appUpdateNotifierProvider, (_, next) async {
      if (!context.mounted) return;
      switch (next) {
        case AppUpdateStateAvailable(:final versionInfo) || AppUpdateStateIgnored(:final versionInfo):
          await ref
              .read(dialogNotifierProvider.notifier)
              .showNewVersion(currentVersion: appInfo.presentVersion, newVersion: versionInfo, canIgnore: false);
        case AppUpdateStateError(:final error):
          ref.read(inAppNotificationControllerProvider).showErrorToast(t.presentShortError(error));
        case AppUpdateStateNotAvailable():
          ref.read(inAppNotificationControllerProvider).showSuccessToast(t.pages.about.notAvailableMsg);
        default:
          break;
      }
    });

    return Scaffold(
      backgroundColor: MelaColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: MelaColors.card(context),
              shape: BoxShape.circle,
              border: Border.all(color: MelaColors.brd(context), width: 1),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, color: MelaColors.textSec(context), size: 15),
          ),
          onPressed: () => context.goNamed('home'),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => MelaColors.primaryGradient.createShader(bounds),
          child: const Text(
            'Настройки',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: MelaColors.textSec(context)),
        actions: [
          MenuAnchor(
            menuChildren: <Widget>[
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromClipboard();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.clipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromJsonFile();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.file),
                  ),
                ],
                child: Text(t.common.import),
              ),
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
                    child: Text(t.pages.settings.options.export.anonymousToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
                    child: Text(t.pages.settings.options.export.anonymousToFile),
                  ),
                  const PopupMenuDivider(),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(configOptionNotifierProvider.notifier)
                        .exportJsonClipboard(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(configOptionNotifierProvider.notifier)
                        .exportJsonFile(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToFile),
                  ),
                ],
                child: Text(t.common.export),
              ),
              const PopupMenuDivider(),
              MenuItemButton(
                child: Text(t.pages.settings.options.reset),
                onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
              ),
            ],
            builder: (context, controller, child) => IconButton(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: Builder(
                builder: (ctx) => Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: MelaColors.card(ctx),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MelaColors.brd(ctx), width: 1),
                  ),
                  child: Icon(Icons.more_vert_rounded, color: MelaColors.textSec(ctx), size: 18),
                ),
              ),
            ),
          ),
          const Gap(8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsGroup(
            children: [
              SettingsSection(
                title: t.pages.settings.general.title,
                icon: Icons.tune_rounded,
                iconColor: MelaColors.primary,
                namedLocation: context.namedLocation('general'),
              ),
            ],
          ).animate().fadeIn(delay: 0.ms, duration: 300.ms).slideY(begin: 0.06, end: 0),
          const Gap(12),
          _SettingsGroup(
            children: [
              if (ref.watch(hasAnyProfileProvider).value ?? false)
                SettingsSection(
                  title: t.pages.settings.chain.title,
                  icon: Icons.account_tree_rounded,
                  iconColor: MelaColors.secondary,
                  subtitle: Text(t.pages.settings.chain.subtitle, style: TextStyle(color: MelaColors.textHint(context), fontSize: 12)),
                  namedLocation: context.namedLocation('chainOptions'),
                ),
              SettingsSection(
                title: t.pages.settings.dns.title,
                icon: Icons.dns_rounded,
                iconColor: const Color(0xFF06B6D4),
                namedLocation: context.namedLocation('dnsOptions'),
              ),
              SettingsSection(
                title: t.pages.settings.inbound.title,
                icon: Icons.input_rounded,
                iconColor: const Color(0xFF10B981),
                namedLocation: context.namedLocation('inboundOptions'),
              ),
            ],
          ).animate().fadeIn(delay: 60.ms, duration: 300.ms).slideY(begin: 0.06, end: 0),
          const Gap(12),
          _SettingsGroup(
            children: [
              SettingsSection(
                title: t.pages.settings.tlsTricks.title,
                icon: Icons.security_rounded,
                iconColor: const Color(0xFFF59E0B),
                namedLocation: context.namedLocation('tlsTricks'),
              ),
              if (PlatformUtils.isIOS)
                _ResetTunnelTile(t: t, ref: ref),
            ],
          ).animate().fadeIn(delay: 120.ms, duration: 300.ms).slideY(begin: 0.06, end: 0),
          if (Breakpoint(context).isMobile()) ...[
            const Gap(12),
            _SettingsGroup(
              children: [
                SettingsSection(
                  title: t.pages.logs.title,
                  icon: Icons.article_rounded,
                  iconColor: const Color(0xFF6366F1),
                  namedLocation: context.namedLocation('logs'),
                ),
                SettingsSection(
                  title: t.pages.about.title,
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF94A3B8),
                  namedLocation: context.namedLocation('about'),
                ),
              ],
            ).animate().fadeIn(delay: 180.ms, duration: 300.ms).slideY(begin: 0.06, end: 0),
          ],
          if (appInfo.release.allowCustomUpdateChecker) ...[
            const Gap(12),
            _SettingsGroup(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.system_update_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  title: Text(
                    t.pages.about.checkForUpdate,
                    style: TextStyle(color: MelaColors.textPrim(context), fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  trailing: appUpdate is AppUpdateStateChecking
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right_rounded, color: MelaColors.textMuted, size: 20),
                  onTap: () async => await ref.read(appUpdateNotifierProvider.notifier).check(),
                ),
              ],
            ).animate().fadeIn(delay: 240.ms, duration: 300.ms).slideY(begin: 0.06, end: 0),
          ],
          const Gap(12),
          _HwidSection(),
          const Gap(32),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final visible = children.where((w) => w is! SizedBox).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: MelaColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MelaColors.brd(context), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, color: MelaColors.brd(context), indent: 56),
          ],
        ],
      ),
    );
  }
}

class _ResetTunnelTile extends StatelessWidget {
  const _ResetTunnelTile({required this.t, required this.ref});
  final TranslationsEn t;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.autorenew_rounded, color: Color(0xFFEF4444), size: 20),
      ),
      title: Text(t.pages.settings.resetTunnel, style: TextStyle(color: MelaColors.textPrim(context), fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: Icon(Icons.chevron_right_rounded, color: MelaColors.textHint(context)),
      onTap: () async => await ref.read(resetTunnelNotifierProvider.notifier).run(),
    );
  }
}

class _HwidSection extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(deviceIdProvider);
    final sendHwid = ref.watch(sendHwidWithSubscription);
    final theme = Theme.of(context);

    return _SettingsGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'Device ID',
            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF6366F1), size: 20),
          ),
          title: Text('Device ID', style: TextStyle(color: MelaColors.textPrim(context), fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Text(deviceId, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: MelaColors.textHint(context))),
          trailing: IconButton(
            icon: Icon(Icons.copy_rounded, size: 18, color: MelaColors.textHint(context)),
            tooltip: 'Copy ID',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: deviceId));
              ref.read(inAppNotificationControllerProvider).showSuccessToast('Device ID copied');
            },
          ),
        ),
        Divider(height: 1, color: MelaColors.brd(context), indent: 56),
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text('Send ID with subscriptions', style: TextStyle(color: MelaColors.textPrim(context), fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Text('Sends X-HWID header when fetching subscription', style: TextStyle(color: MelaColors.textHint(context), fontSize: 12)),
          secondary: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.send_rounded, color: Color(0xFF6366F1), size: 20),
          ),
          value: sendHwid,
          onChanged: ref.read(sendHwidWithSubscription.notifier).update,
        ),
      ],
    );
  }
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    required this.namedLocation,
  });

  final String title;
  final Widget? subtitle;
  final IconData icon;
  final Color iconColor;
  final String namedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: MelaColors.textPrim(context),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle,
      trailing: Icon(Icons.chevron_right_rounded, color: MelaColors.textHint(context), size: 20),
      onTap: () => context.go(namedLocation),
    );
  }
}
