import 'package:melavpn/features/connection/notifier/connection_notifier.dart';
import 'package:melavpn/features/stats/notifier/stats_notifier.dart';
import 'package:melavpn/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'speed_history_notifier.g.dart';

typedef SpeedPoint = ({double uplink, double downlink});

@Riverpod(keepAlive: true)
class SpeedHistoryNotifier extends _$SpeedHistoryNotifier {
  static const maxPoints = 60;

  @override
  List<SpeedPoint> build() {
    ref.listen<AsyncValue<SystemInfo>>(statsNotifierProvider, (_, next) {
      if (next case AsyncData(value: final info)) {
        _add((
          uplink: info.uplink.toInt().toDouble(),
          downlink: info.downlink.toInt().toDouble(),
        ));
      }
    });

    ref.listen(serviceRunningProvider, (_, running) {
      if (!running) state = [];
    });

    return [];
  }

  void _add(SpeedPoint point) {
    final list = [...state, point];
    state = list.length > maxPoints ? list.sublist(list.length - maxPoints) : list;
  }
}
