import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:melavpn/core/app_info/app_info_provider.dart';
import 'package:melavpn/core/http_client/http_client_provider.dart';
import 'package:melavpn/core/localization/locale_preferences.dart';
import 'package:melavpn/core/model/constants.dart';
import 'package:melavpn/core/model/environment.dart';
import 'package:melavpn/core/preferences/preferences_provider.dart';
import 'package:melavpn/core/utils/preferences_utils.dart';
import 'package:melavpn/features/app_update/data/app_update_data_providers.dart';
import 'package:melavpn/features/app_update/model/app_update_failure.dart';
import 'package:melavpn/features/app_update/model/remote_version_entity.dart';
import 'package:melavpn/features/app_update/notifier/app_update_state.dart';
import 'package:melavpn/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:upgrader/upgrader.dart';
import 'package:version/version.dart';

part 'app_update_notifier.g.dart';

const _debugUpgrader = true;

@riverpod
Upgrader upgrader(Ref ref) => Upgrader(
  storeController: UpgraderStoreController(
    onAndroid: () => ref.read(appInfoProvider).requireValue.release.allowCustomUpdateChecker
        ? UpgraderAppcastStore(appcastURL: Constants.appCastUrl)
        : UpgraderPlayStore(),
    oniOS: () => UpgraderAppStore(),
    onLinux: () => UpgraderAppcastStore(appcastURL: Constants.appCastUrl),
    onWindows: () => UpgraderAppcastStore(appcastURL: Constants.appCastUrl),
    onMacOS: () => UpgraderAppcastStore(appcastURL: Constants.appCastUrl),
    onWeb: () => UpgraderAppcastStore(appcastURL: Constants.appCastUrl),
  ),
  debugLogging: false && _debugUpgrader && kDebugMode,
  // durationUntilAlertAgain: const Duration(hours: 12),
  messages: UpgraderMessages(code: ref.watch(localePreferencesProvider).languageCode),
);

@Riverpod(keepAlive: true)
class AppUpdateNotifier extends _$AppUpdateNotifier with AppLogger {
  @override
  AppUpdateState build() => const AppUpdateState.initial();

  PreferencesEntry<String?, dynamic> get _ignoreReleasePref => PreferencesEntry(
    preferences: ref.read(sharedPreferencesProvider).requireValue,
    key: 'ignored_release_version',
    defaultValue: null,
  );

  Future<AppUpdateState> check() async {
    loggy.debug("checking for update");
    state = const AppUpdateState.checking();
    final appInfo = ref.watch(appInfoProvider).requireValue;
    if (!appInfo.release.allowCustomUpdateChecker) {
      loggy.debug("custom update checkers are not allowed for [${appInfo.release.name}] release");
      return state = const AppUpdateState.disabled();
    }
    return ref
        .watch(appUpdateRepositoryProvider)
        .getLatestVersion()
        .match(
          (err) {
            loggy.warning("failed to get latest version", err);
            return state = AppUpdateState.error(err);
          },
          (remote) {
            try {
              final latestVersion = Version.parse(remote.version);
              final currentVersion = Version.parse(appInfo.version);
              if (latestVersion > currentVersion) {
                if (remote.version == _ignoreReleasePref.read()) {
                  loggy.debug("ignored release [${remote.version}]");
                  return state = AppUpdateStateIgnored(remote);
                }
                loggy.debug("new version available: $remote");
                return state = AppUpdateState.available(remote);
              }
              loggy.info("already using latest version[$currentVersion], remote: [${remote.version}]");
              return state = const AppUpdateState.notAvailable();
            } catch (error, stackTrace) {
              loggy.warning("error parsing versions", error, stackTrace);
              return state = AppUpdateState.error(AppUpdateFailure.unexpected(error, stackTrace));
            }
          },
        )
        .run();
  }

  Future<void> ignoreRelease(RemoteVersionEntity version) async {
    loggy.debug("ignoring release [${version.version}]");
    await _ignoreReleasePref.write(version.version);
    state = AppUpdateStateIgnored(version);
  }

  Future<String?> downloadUpdate(
    RemoteVersionEntity version, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final apkUrl = version.apkUrl;
    if (apkUrl == null) {
      loggy.warning("no apk url in release [${version.version}]");
      return null;
    }
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/mela_vpn_update.apk';
    loggy.debug("downloading update [${version.version}] to [$savePath]");
    await ref.read(httpClientProvider).download(
      apkUrl,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      },
    );
    loggy.debug("download complete: [$savePath]");
    return savePath;
  }
}
