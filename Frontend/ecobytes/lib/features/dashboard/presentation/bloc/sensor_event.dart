import 'package:equatable/equatable.dart';

sealed class SensorEvent extends Equatable {
  const SensorEvent();

  @override
  List<Object?> get props => [];
}

final class SensorStarted extends SensorEvent {
  const SensorStarted();
}

final class SensorRefreshed extends SensorEvent {
  const SensorRefreshed();
}
