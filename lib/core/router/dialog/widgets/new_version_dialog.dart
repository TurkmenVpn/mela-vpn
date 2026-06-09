import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/core/widget/mela_dialog.dart';
import 'package:melavpn/features/app_update/model/remote_version_entity.dart';
import 'package:melavpn/features/app_update/notifier/app_update_notifier.dart';
import 'package:melavpn/core/notification/in_app_notification_controller.dart';
import 'package:melavpn/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:open_filex/open_filex.dart';

class NewVersionDialog extends HookConsumerWidget with PresLogger {
  NewVersionDialog(this.currentVersion, this.newVersion, {super.key, this.canIgnore = true});

  final String currentVersion;
  final RemoteVersionEntity newVersion;
  final bool canIgnore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;

    final isDownloading = useState(false);
    final progress = useState(0.0);
    final downloadedPath = useState<String?>(null);
    final cancelToken = useState<CancelToken?>(null);

    final hasApkUrl = newVersion.apkUrl != null;

    Future<void> startDownload() async {
      final token = CancelToken();
      cancelToken.value = token;
      isDownloading.value = true;
      progress.value = 0.0;
      try {
        final path = await ref.read(appUpdateNotifierProvider.notifier).downloadUpdate(
          newVersion,
          onProgress: (p) => progress.value = p,
          cancelToken: token,
        );
        if (path != null) downloadedPath.value = path;
      } catch (e) {
        if (e is! DioException || e.type != DioExceptionType.cancel) {
          loggy.warning("download failed", e);
          downloadedPath.value = null;
          ref.read(inAppNotificationControllerProvider).showErrorToast(
            '${t.common.update}: ${t.common.msg.export.file.failure}',
          );
        }
      } finally {
        isDownloading.value = false;
        cancelToken.value = null;
      }
    }

    void cancelDownload() {
      cancelToken.value?.cancel();
      cancelToken.value = null;
      isDownloading.value = false;
      progress.value = 0.0;
    }

    Future<void> installApk() async {
      final path = downloadedPath.value;
      if (path == null) return;
      await OpenFilex.open(path);
      if (context.mounted) context.pop();
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.dialogs.newVersion.msg),
        const Gap(10),
        _VersionRow(
          label: t.dialogs.newVersion.currentVersion,
          version: currentVersion,
          context: context,
        ),
        const Gap(4),
        _VersionRow(
          label: t.dialogs.newVersion.newVersion,
          version: newVersion.presentVersion,
          context: context,
          isNew: true,
        ),
        if (isDownloading.value) ...[
          const Gap(14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.value > 0 ? progress.value : null,
                    color: MelaColors.primary,
                    backgroundColor: MelaColors.primary.withValues(alpha: 0.15),
                    minHeight: 4,
                  ),
                ),
              ),
              const Gap(8),
              Text(
                '${(progress.value * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: MelaColors.textSec(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );

    final actions = <Widget>[
      if (!isDownloading.value && downloadedPath.value == null) ...[
        if (canIgnore)
          MelaDialogTextButton(
            label: t.common.ignore,
            onPressed: () async {
              await ref.read(appUpdateNotifierProvider.notifier).ignoreRelease(newVersion);
              if (context.mounted) context.pop();
            },
          ),
        MelaDialogTextButton(label: t.common.later, onPressed: context.pop),
        MelaDialogFilledButton(
          label: t.dialogs.newVersion.updateNow,
          onPressed: hasApkUrl ? startDownload : () => UriUtils.tryLaunch(Uri.parse(newVersion.url)),
          color: MelaColors.connected,
        ),
      ],
      if (isDownloading.value)
        MelaDialogTextButton(label: t.common.cancel, onPressed: cancelDownload),
      if (!isDownloading.value && downloadedPath.value != null)
        MelaDialogFilledButton(
          label: t.common.kContinue,
          onPressed: installApk,
          color: MelaColors.connected,
        ),
    ];

    return MelaDialog(
      title: t.dialogs.newVersion.title,
      icon: Icons.system_update_outlined,
      iconColor: MelaColors.connected,
      content: content,
      actions: actions,
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({
    required this.label,
    required this.version,
    required this.context,
    this.isNew = false,
  });
  final String label;
  final String version;
  final BuildContext context;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: MelaColors.textSec(context), fontSize: 13),
        ),
        Text(
          version,
          style: TextStyle(
            color: isNew ? MelaColors.connected : MelaColors.textPrim(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
