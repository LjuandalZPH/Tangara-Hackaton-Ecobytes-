import 'package:equatable/equatable.dart';

import '../../domain/models/sensor_data.dart';

enum SensorStatus { initial, loading, success, failure }

final class SensorState extends Equatable {
  const SensorState({
    this.status = SensorStatus.initial,
    this.snapshot,
    this.errorMessage,
  });

  final SensorStatus status;
  final DashboardSnapshot? snapshot;
  final String? errorMessage;

  SensorState copyWith({
    SensorStatus? status,
    DashboardSnapshot? snapshot,
    String? errorMessage,
  }) {
    return SensorState(
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, snapshot, errorMessage];
}
