import 'package:melavpn/core/directories/directories_provider.dart';
import 'package:melavpn/core/notification/in_app_notification_controller.dart';
import 'package:melavpn/core/preferences/general_preferences.dart';
import 'package:melavpn/hiddifycore/hiddify_core_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'hiddify_core_service_provider.g.dart';

@Riverpod(keepAlive: true, dependencies: [AppDirectories, DebugModeNotifier, inAppNotificationController])
MelaVPNCoreService melavpnCoreService(Ref ref) {
  final service = MelaVPNCoreService(ref);
  ref.onDispose(() {
    service.statusController.close();
    service.logController.close();
  });
  return service;
}
