import 'package:melavpn/core/directories/directories_provider.dart';
import 'package:melavpn/features/connection/data/connection_repository.dart';
import 'package:melavpn/features/profile/data/profile_data_providers.dart';
import 'package:melavpn/features/settings/data/config_option_data_providers.dart';
import 'package:melavpn/hiddifycore/hiddify_core_service_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connection_data_providers.g.dart';

@Riverpod(keepAlive: true)
ConnectionRepository connectionRepository(Ref ref) {
  return ConnectionRepositoryImpl(
    ref: ref,
    directories: ref.watch(appDirectoriesProvider).requireValue,
    configOptionRepository: ref.watch(configOptionRepositoryProvider),
    singbox: ref.watch(melavpnCoreServiceProvider),
    profilePathResolver: ref.watch(profilePathResolverProvider),
  );
}
