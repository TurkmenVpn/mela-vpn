import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/core/widget/mela_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ConfirmationDialog extends HookConsumerWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon,
    this.positiveBtnTxt,
  });
  final String title;
  final String message;
  final IconData? icon;
  final String? positiveBtnTxt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final isDelete = icon == Icons.delete_outline_rounded ||
        (positiveBtnTxt ?? '').toLowerCase().contains('удал') ||
        title.toLowerCase().contains('удал') ||
        title.toLowerCase().contains('delete');

    return MelaDialog(
      title: title,
      icon: icon ?? (isDelete ? Icons.delete_outline_rounded : Icons.help_outline_rounded),
      iconColor: isDelete ? const Color(0xFFFF453A) : MelaColors.primary,
      content: Text(message),
      actions: [
        MelaDialogTextButton(label: t.common.cancel, onPressed: () => context.pop(false)),
        MelaDialogFilledButton(
          label: positiveBtnTxt ?? t.common.ok,
          onPressed: () => context.pop(true),
          isDanger: isDelete,
        ),
      ],
    );
  }
}
