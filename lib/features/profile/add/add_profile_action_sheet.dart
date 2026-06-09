import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:melavpn/core/router/dialog/dialog_notifier.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/features/profile/model/profile_entity.dart';
import 'package:melavpn/features/profile/notifier/profile_notifier.dart';
import 'package:melavpn/features/profile/overview/profiles_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class AddProfileActionSheet extends HookConsumerWidget {
  const AddProfileActionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdding = ref.watch(addProfileNotifierProvider).isLoading;

    Future<void> pasteClipboard() async {
      final text = await Clipboard.getData(Clipboard.kTextPlain).then((v) => v?.text ?? '');
      if (text.isEmpty) return;
      if (context.mounted) context.pop();
      ref.read(addProfileNotifierProvider.notifier).addClipboard(text);
    }

    Future<void> scanQr() async {
      final result = await ref.read(dialogNotifierProvider.notifier).showQrScanner();
      if (result == null) return;
      if (context.mounted) context.pop();
      ref.read(addProfileNotifierProvider.notifier).addClipboard(result);
    }

    Future<void> pasteJson() async {
      final text = await Clipboard.getData(Clipboard.kTextPlain).then((v) => v?.text ?? '');
      if (text.isEmpty) return;
      if (context.mounted) context.pop();
      ref.read(addProfileNotifierProvider.notifier).addClipboard(text);
    }

    Future<void> refreshAll() async {
      if (context.mounted) context.pop();
      final profiles = await ref.read(profilesNotifierProvider.future);
      final remotes = profiles.whereType<RemoteProfileEntity>().toList();
      for (final p in remotes) {
        ref.read(updateProfileNotifierProvider(p.id).notifier).updateProfile(p);
      }
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MelaColors.brd(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap(16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Mela VPN',
              style: TextStyle(
                color: MelaColors.textPrim(context),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(16),
          if (isAdding)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: MelaColors.primary),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _ActionItem(
                    icon: Icons.refresh_rounded,
                    iconColor: MelaColors.secondary,
                    title: 'Обновить все подписки',
                    subtitle: 'Синхронизировать все удалённые профили',
                    onTap: refreshAll,
                  ),
                  const _Divider(),
                  _ActionItem(
                    icon: Icons.vpn_key_rounded,
                    iconColor: MelaColors.primary,
                    title: 'Добавить ключ',
                    subtitle: 'vless:// vmess:// ss:// trojan:// hy2://',
                    onTap: () {
                      context.pop();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _AddKeySheet(ref: ref),
                      );
                    },
                  ),
                  const _Divider(),
                  _ActionItem(
                    icon: Icons.link_rounded,
                    iconColor: const Color(0xFF22C55E),
                    title: 'Добавить подписку',
                    subtitle: 'Добавить по URL-ссылке',
                    onTap: () {
                      context.pop();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _AddSubscriptionSheet(ref: ref),
                      );
                    },
                  ),
                  const _Divider(),
                  _ActionItem(
                    icon: Icons.content_paste_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Вставить из буфера',
                    subtitle: 'Ключ, ссылка или JSON из clipboard',
                    onTap: pasteClipboard,
                  ),
                  const _Divider(),
                  _ActionItem(
                    icon: Icons.qr_code_scanner_rounded,
                    iconColor: MelaColors.textSecondary,
                    title: 'Сканировать QR-код',
                    subtitle: 'Считать ключ или подписку с QR',
                    onTap: scanQr,
                  ),
                  const _Divider(),
                  _ActionItem(
                    icon: Icons.data_object_rounded,
                    iconColor: const Color(0xFFEC4899),
                    title: 'Вставить JSON',
                    subtitle: 'Вставить конфигурацию в формате JSON',
                    onTap: pasteJson,
                  ),
                ],
              ),
            ),
          const Gap(16),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: MelaColors.textPrim(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: null,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: MelaColors.textHint(context),
                      fontSize: 12,
                      fontFamily: null,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: MelaColors.textHint(context), size: 18),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 58),
      color: MelaColors.brd(context).withValues(alpha: 0.4),
    );
  }
}

class _AddKeySheet extends HookConsumerWidget {
  const _AddKeySheet({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final focusNode = useFocusNode();

    useEffect(() {
      Future.microtask(() => focusNode.requestFocus());
      return null;
    }, []);

    void submit() {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      context.pop();
      ref.read(addProfileNotifierProvider.notifier).addClipboard(text);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MelaColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MelaColors.brd(context)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MelaColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.vpn_key_rounded, color: MelaColors.primary, size: 20),
                ),
                const Gap(10),
                Text(
                  'Добавить ключ',
                  style: TextStyle(
                    color: MelaColors.textPrim(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: null,
                  ),
                ),
              ],
            ),
            const Gap(16),
            TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 4,
              minLines: 2,
              style: TextStyle(
                color: MelaColors.textPrim(context),
                fontSize: 13,
                fontFamily: null,
              ),
              decoration: InputDecoration(
                hintText: 'vless://... или vmess://... или ss://... или trojan://...',
                hintStyle: TextStyle(
                  color: MelaColors.textHint(context),
                  fontSize: 12,
                  fontFamily: null,
                ),
                filled: true,
                fillColor: MelaColors.surf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MelaColors.brd(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MelaColors.brd(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MelaColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onSubmitted: (_) => submit(),
            ),
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MelaColors.textSec(context),
                      side: BorderSide(color: MelaColors.brd(context)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Отмена', style: TextStyle(fontFamily: null)),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: FilledButton(
                    onPressed: submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: MelaColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Добавить', style: TextStyle(fontFamily: null)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSubscriptionSheet extends HookConsumerWidget {
  const _AddSubscriptionSheet({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final focusNode = useFocusNode();

    useEffect(() {
      Future.microtask(() => focusNode.requestFocus());
      return null;
    }, []);

    void submit() {
      final text = controller.text.trim();
      if (text.isEmpty) return;
      context.pop();
      ref.read(addProfileNotifierProvider.notifier).addClipboard(text);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MelaColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MelaColors.brd(context)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.link_rounded, color: Color(0xFF22C55E), size: 20),
                ),
                const Gap(10),
                Text(
                  'Добавить подписку',
                  style: TextStyle(
                    color: MelaColors.textPrim(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    fontFamily: null,
                  ),
                ),
              ],
            ),
            const Gap(16),
            TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 3,
              minLines: 1,
              style: TextStyle(
                color: MelaColors.textPrim(context),
                fontSize: 13,
                fontFamily: null,
              ),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: TextStyle(
                  color: MelaColors.textHint(context),
                  fontSize: 12,
                  fontFamily: null,
                ),
                filled: true,
                fillColor: MelaColors.surf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MelaColors.brd(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MelaColors.brd(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: MelaColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              onSubmitted: (_) => submit(),
            ),
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MelaColors.textSec(context),
                      side: BorderSide(color: MelaColors.brd(context)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Отмена', style: TextStyle(fontFamily: null)),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: FilledButton(
                    onPressed: submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Добавить', style: TextStyle(fontFamily: null, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
