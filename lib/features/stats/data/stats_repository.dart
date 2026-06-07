import 'package:fpdart/fpdart.dart';
import 'package:melavpn/core/utils/exception_handler.dart';
import 'package:melavpn/features/stats/model/stats_failure.dart';
import 'package:melavpn/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:melavpn/hiddifycore/hiddify_core_service.dart';
import 'package:melavpn/utils/custom_loggers.dart';

abstract interface class StatsRepository {
  Stream<Either<StatsFailure, SystemInfo>> watchStats();
}

class StatsRepositoryImpl with ExceptionHandler, InfraLogger implements StatsRepository {
  StatsRepositoryImpl({required this.singbox});

  final MelaVPNCoreService singbox;

  @override
  Stream<Either<StatsFailure, SystemInfo>> watchStats() {
    return singbox.watchStats().handleExceptions(StatsUnexpectedFailure.new);
  }
}
