import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/router/dialog/dialog_notifier.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/features/profile/notifier/profile_notifier.dart';

class EmptyProfilesHomeBody extends HookConsumerWidget {
  const EmptyProfilesHomeBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

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

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Column(
        children: [
          const Spacer(),
          Icon(Icons.link_off_rounded, size: 52, color: MelaColors.textMuted),
          const Gap(14),
          Text(
            t.dialogs.noActiveProfile.msg,
            style: const TextStyle(color: MelaColors.textSecondary, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: pasteClipboard,
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: const Text('Вставить'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: scanQr,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('QR-код'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
