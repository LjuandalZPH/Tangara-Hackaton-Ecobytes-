import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/mock_sensor_repository.dart';
import 'sensor_event.dart';
import 'sensor_state.dart';

/// Bloc base listo para conectarse a un repositorio HTTP/WebSocket.
class SensorBloc extends Bloc<SensorEvent, SensorState> {
  SensorBloc() : super(const SensorState()) {
    on<SensorStarted>(_onStarted);
    on<SensorRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    SensorStarted event,
    Emitter<SensorState> emit,
  ) async {
    emit(state.copyWith(status: SensorStatus.loading));
    await _load(emit);
  }

  Future<void> _onRefreshed(
    SensorRefreshed event,
    Emitter<SensorState> emit,
  ) async {
    await _load(emit);
  }

  Future<void> _load(Emitter<SensorState> emit) async {
    try {
      // TODO: reemplazar por SensorRepository remoto.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      emit(
        state.copyWith(
          status: SensorStatus.success,
          snapshot: MockSensorRepository.dashboardSnapshot,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: SensorStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
