import 'dart:ui';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:melavpn/core/app_info/app_info_provider.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:melavpn/core/router/dialog/dialog_notifier.dart';
import 'package:melavpn/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/features/connection/notifier/connection_notifier.dart';
import 'package:melavpn/features/home/widget/connection_button.dart';
import 'package:melavpn/features/home/widget/home_traffic_stats.dart';
import 'package:melavpn/features/profile/add/add_profile_action_sheet.dart';
import 'package:melavpn/features/profile/notifier/active_profile_notifier.dart';
import 'package:melavpn/features/profile/notifier/profile_notifier.dart';
import 'package:melavpn/features/profile/widget/profile_tile.dart';
import 'package:melavpn/features/proxy/active/active_proxy_card.dart';
import 'package:melavpn/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final activeProfile = ref.watch(activeProfileProvider);

    return Scaffold(
      backgroundColor: MelaColors.bg(context),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined, size: 22),
          color: MelaColors.textSecondary,
          onPressed: () => context.goNamed('settings'),
        ),
        title: const _MelaLogoTitle(),
        centerTitle: true,
        actions: [
          Semantics(
            key: const ValueKey("profile_add_button"),
            label: t.pages.profiles.add,
            child: IconButton(
              icon: const Icon(Icons.add_rounded, size: 24),
              color: MelaColors.primary,
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: MelaColors.card(context),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const AddProfileActionSheet(),
              ),
            ),
          ),
          const Gap(4),
        ],
      ),
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: MelaColors.bgLinear(context),
              ),
            ),
          ),
          // Ambient purple glow top-left
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MelaColors.primary.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Ambient cyan glow right
          Positioned(
            top: 80,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    MelaColors.secondary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Space under AppBar
              SizedBox(height: MediaQuery.paddingOf(context).top + kToolbarHeight + 12),
              // TOP — connection button
              const ConnectionButton(),
              const Gap(4),
              const ActiveProxyDelayIndicator(),
              const HomeTrafficStats(),
              const Gap(30),
              // BOTTOM — profile subscription card (scrollable)
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: MelaColors.card(context).withValues(alpha: 0.97),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        border: Border(
                          top: BorderSide(
                            color: MelaColors.brd(context).withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                      ),
                      child: switch (activeProfile) {
                        AsyncData(value: final profile?) => ListView(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.paddingOf(context).bottom + 30),
                          children: [
                            _SectionHeader(t: t, ref: ref),
                            const Gap(10),
                            ProfileTile(profile: profile, isMain: true),
                            const Gap(12),
                            ActiveProxyFooter(),
                          ],
                        ),
                        _ => _EmptyProfileHint(t: t),
                      },
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
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.t, required this.ref});
  final TranslationsEn t;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left accent + label
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: MelaColors.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Gap(8),
        Text(
          t.pages.profiles.title,
          style: TextStyle(
            color: MelaColors.textSec(context),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
        ),
        const Spacer(),
        // All profiles button
        GestureDetector(
          onTap: () {
            if (Breakpoint(context).isMobile()) {
              ref.read(bottomSheetsNotifierProvider.notifier).showProfilesOverview();
            } else {
              context.goNamed('profiles');
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: MelaColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MelaColors.primary.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.pages.profiles.viewAllProfiles,
                  style: const TextStyle(
                    color: MelaColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(3),
                const Icon(Icons.chevron_right_rounded, color: MelaColors.primary, size: 13),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyProfileHint extends ConsumerWidget {
  const _EmptyProfileHint({required this.t});
  final TranslationsEn t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> pasteClipboard() async {
      final text = await Clipboard.getData(Clipboard.kTextPlain).then((v) => v?.text ?? '');
      if (text.isEmpty) return;
      ref.read(addProfileNotifierProvider.notifier).addClipboard(text);
    }

    Future<void> scanQr() async {
      final result = await ref.read(dialogNotifierProvider.notifier).showQrScanner();
      if (result == null) return;
      ref.read(addProfileNotifierProvider.notifier).addClipboard(result);
    }

    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad + 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Empty state illustration
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: MelaColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: MelaColors.primary.withValues(alpha: 0.2), width: 1.5),
            ),
            child: const Icon(Icons.shield_outlined, size: 34, color: MelaColors.primary),
          ),
          const Gap(16),
          Text(
            'Нет активного ключа',
            style: TextStyle(color: MelaColors.textPrim(context), fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const Gap(6),
          Text(
            'Вставьте ссылку или отсканируйте QR',
            style: TextStyle(color: MelaColors.textHint(context), fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const Gap(28),
          // Inline action buttons (Paste + QR)
          Row(
            children: [
              // Paste button
              Expanded(
                child: GestureDetector(
                  onTap: pasteClipboard,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: MelaColors.surf(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: MelaColors.brd(context), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_paste_rounded, color: MelaColors.primary, size: 18),
                        const Gap(7),
                        Text(
                          'Вставить',
                          style: TextStyle(
                            color: MelaColors.textPrim(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Gap(12),
              // QR button
              Expanded(
                child: GestureDetector(
                  onTap: scanQr,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [MelaColors.primary, Color(0xFF5B8BF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: MelaColors.primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                        Gap(7),
                        Text(
                          'Сканировать QR',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
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
}

class _MelaLogoTitle extends ConsumerWidget {
  const _MelaLogoTitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(connectionNotifierProvider).valueOrNull?.isConnected ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => MelaColors.primaryGradient.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: const Icon(Icons.security_rounded, size: 22, color: Colors.white),
        ),
        const Gap(7),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [MelaColors.primary, Color(0xFF5B8BF6), Color(0xFF06B6D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text(
            'Mela VPN',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.normal,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (isConnected) ...[
          const Gap(8),
          const _VpnActiveBadge(),
        ],
      ],
    );
  }
}

class _VpnActiveBadge extends StatelessWidget {
  const _VpnActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF00C853),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C853).withValues(alpha: 0.45),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_rounded, size: 11, color: Colors.white),
          const Gap(3),
          const Text(
            'VPN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();

    return Semantics(
      label: t.common.version,
      button: false,
      child: Container(
        decoration: BoxDecoration(
          color: MelaColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: MelaColors.primary.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          version,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: MelaColors.primaryLight,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
