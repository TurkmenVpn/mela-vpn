import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/core/widget/mela_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SaveDialog extends HookConsumerWidget {
  const SaveDialog({super.key, required this.title, required this.description});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return MelaDialog(
      title: title,
      icon: Icons.save_outlined,
      iconColor: MelaColors.primary,
      content: Text(description),
      actions: [
        MelaDialogTextButton(label: t.common.discard, onPressed: () => context.pop(false)),
        MelaDialogFilledButton(label: t.common.save, onPressed: () => context.pop(true)),
      ],
    );
  }
}
