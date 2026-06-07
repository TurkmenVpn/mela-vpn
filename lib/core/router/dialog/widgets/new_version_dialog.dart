import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/features/app_update/model/remote_version_entity.dart';
import 'package:melavpn/features/app_update/notifier/app_update_notifier.dart';
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
    final theme = Theme.of(context);

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
        if (path != null) {
          downloadedPath.value = path;
        }
      } catch (e) {
        if (e is! DioException || e.type != DioExceptionType.cancel) {
          loggy.warning("download failed", e);
          downloadedPath.value = null;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${t.common.update}: ${t.common.msg.export.file.failure}')),
            );
          }
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

    return AlertDialog(
      title: Text(t.dialogs.newVersion.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.dialogs.newVersion.msg),
          const Gap(8),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: t.dialogs.newVersion.currentVersion, style: theme.textTheme.bodySmall),
                TextSpan(text: currentVersion, style: theme.textTheme.labelMedium),
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: t.dialogs.newVersion.newVersion, style: theme.textTheme.bodySmall),
                TextSpan(text: newVersion.presentVersion, style: theme.textTheme.labelMedium),
              ],
            ),
          ),
          if (isDownloading.value) ...[
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(value: progress.value > 0 ? progress.value : null),
                ),
                const Gap(8),
                Text(
                  '${(progress.value * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        if (!isDownloading.value && downloadedPath.value == null) ...[
          if (canIgnore)
            TextButton(
              onPressed: () async {
                await ref.read(appUpdateNotifierProvider.notifier).ignoreRelease(newVersion);
                if (context.mounted) context.pop();
              },
              child: Text(t.common.ignore),
            ),
          TextButton(onPressed: context.pop, child: Text(t.common.later)),
          TextButton(
            onPressed: hasApkUrl ? startDownload : () => UriUtils.tryLaunch(Uri.parse(newVersion.url)),
            child: Text(t.dialogs.newVersion.updateNow),
          ),
        ],
        if (isDownloading.value)
          TextButton(onPressed: cancelDownload, child: Text(t.common.cancel)),
        if (!isDownloading.value && downloadedPath.value != null)
          FilledButton(
            onPressed: installApk,
            child: Text(t.common.kContinue),
          ),
      ],
    );
  }
}
