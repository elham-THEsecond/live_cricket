import 'channel.dart';

class StreamData {
  final DateTime? generatedAt;
  final int totalChannels;
  final int totalStreams;
  final List<Channel> channels;

  const StreamData({
    this.generatedAt,
    this.totalChannels = 0,
    this.totalStreams = 0,
    this.channels = const [],
  });

  /// Channels with no live streams are dropped here rather than filtered in
  /// the UI.
  factory StreamData.fromJson(Map<String, dynamic> json) {
    final channels = asList<Map<String, dynamic>>(json['channels'])
        .map(Channel.fromJson)
        .where((c) => c.hasLiveStreams)
        .toList();
    return StreamData(
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? ''),
      totalChannels: json['total_channels'] is int
          ? json['total_channels'] as int
          : channels.length,
      totalStreams: json['total_streams'] is int ? json['total_streams'] as int : 0,
      channels: channels,
    );
  }

  Map<String, dynamic> toJson() => {
        'generated_at': generatedAt?.toIso8601String(),
        'total_channels': totalChannels,
        'total_streams': totalStreams,
        'channels': channels.map((c) => c.toJson()).toList(),
      };
}