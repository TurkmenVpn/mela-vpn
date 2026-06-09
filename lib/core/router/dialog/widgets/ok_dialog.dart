import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/widget/mela_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OkDialog extends HookConsumerWidget {
  const OkDialog({super.key, required this.title, required this.description});
  final String title;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return MelaDialog(
      title: title,
      icon: Icons.info_outline_rounded,
      content: Text(description),
      actions: [
        MelaDialogFilledButton(label: t.common.ok, onPressed: () => context.pop()),
      ],
    );
  }
}
