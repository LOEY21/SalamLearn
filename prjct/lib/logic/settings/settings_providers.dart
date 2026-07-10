import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Independent volume channels (FR-7.1). Values 0.0–1.0.
class VolumeState {
  const VolumeState({
    this.background = 0.7,
    this.effects = 0.8,
    this.voice = 1.0,
  });

  final double background;
  final double effects;
  final double voice;

  VolumeState copyWith({double? background, double? effects, double? voice}) {
    return VolumeState(
      background: background ?? this.background,
      effects: effects ?? this.effects,
      voice: voice ?? this.voice,
    );
  }
}

class VolumeNotifier extends Notifier<VolumeState> {
  @override
  VolumeState build() => const VolumeState();

  void setBackground(double v) => state = state.copyWith(background: v);
  void setEffects(double v) => state = state.copyWith(effects: v);
  void setVoice(double v) => state = state.copyWith(voice: v);
}

final volumeProvider =
    NotifierProvider<VolumeNotifier, VolumeState>(VolumeNotifier.new);
