import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/widget/mela_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class CustomAlertDialog extends HookConsumerWidget {
  const CustomAlertDialog({super.key, this.title, required this.message});

  final String? title;
  final String message;

  factory CustomAlertDialog.fromErr(({String type, String? message}) err) =>
      CustomAlertDialog(title: err.message == null ? null : err.type, message: err.message ?? err.type);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return MelaDialog(
      title: title,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFFF9F0A),
      content: SelectableText(
        message,
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
      actions: [
        MelaDialogFilledButton(label: t.common.ok, onPressed: () => context.pop()),
      ],
    );
  }
}
