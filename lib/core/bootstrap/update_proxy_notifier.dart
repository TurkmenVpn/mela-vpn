import 'dart:io';

import 'package:melavpn/core/bootstrap/bootstrap_proxy_provider.dart';
import 'package:melavpn/core/bootstrap/update_proxy_service.dart';
import 'package:melavpn/core/directories/directories_provider.dart';
import 'package:melavpn/hiddifycore/hiddify_core_service_provider.dart';
import 'package:melavpn/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_proxy_notifier.g.dart';

@Riverpod(keepAlive: true)
class UpdateProxyNotifier extends _$UpdateProxyNotifier with AppLogger {
  @override
  Future<void> build() async {
    final key = ref.watch(bootstrapKeyProvider);

    ref.onDispose(_clearProxy);

    if (key.isEmpty) {
      await _clearProxy();
      return;
    }
    await _startFromKey(key);
  }

  Future<void> _startFromKey(String key) async {
    final config = UpdateProxyService.buildConfig(key);
    if (config == null) {
      loggy.warning('update-proxy: cannot parse key, skipping');
      return;
    }

    final dirs = ref.read(appDirectoriesProvider).valueOrNull;
    if (dirs == null) return;

    final configFile = File('${dirs.workingDir.path}/update_proxy_config.json');
    await configFile.writeAsString(config);

    final service = ref.read(melavpnCoreServiceProvider);
    final started = await service.startUpdateProxy(configFile.path);
    if (!started) {
      loggy.warning('update-proxy: fgClient.start() returned failure');
      return;
    }

    // Wait up to 3 s for the mixed port to open.
    const proxyAddr = 'socks5:127.0.0.1:${UpdateProxyService.proxyPort}';
    for (var i = 0; i < 15; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      try {
        final s = await Socket.connect('127.0.0.1', UpdateProxyService.proxyPort, timeout: const Duration(milliseconds: 200));
        await s.close();
        await ref.read(bootstrapProxyAddrProvider.notifier).update(proxyAddr);
        loggy.info('update-proxy started on port ${UpdateProxyService.proxyPort}');
        return;
      } on SocketException catch (_) {
        continue;
      }
    }
    loggy.warning('update-proxy: port ${UpdateProxyService.proxyPort} did not open in time');
  }

  Future<void> _clearProxy() async {
    try {
      final service = ref.read(melavpnCoreServiceProvider);
      await service.stopUpdateProxy();
    } catch (_) {}
    try {
      await ref.read(bootstrapProxyAddrProvider.notifier).update('');
    } catch (_) {}
  }
}
