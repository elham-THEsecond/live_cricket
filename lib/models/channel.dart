import 'stream_url.dart';

/// Safe list cast: the API is untrusted input, so a wrong-typed field must
/// degrade to empty rather than throw a TypeError.
List<T> asList<T>(Object? value) =>
    value is List ? value.whereType<T>().toList() : <T>[];

class Channel {
  final String id;
  final String name;
  final List<String> altNames;
  final String country;
  final String logo;
  final List<StreamUrl> streams;

  const Channel({
    required this.id,
    required this.name,
    this.altNames = const [],
    this.country = '',
    this.logo = '',
    this.streams = const [],
  });

  /// Only live streams survive parsing — dead entries are dropped here so no
  /// downstream code has to re-check `status`.
  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        altNames: asList<String>(json['alt_names']),
        country: json['country'] as String? ?? '',
        logo: json['logo'] as String? ?? '',
        streams: asList<Map<String, dynamic>>(json['streams'])
            .map(StreamUrl.fromJson)
            .where((s) => s.status == 'live' && s.url.isNotEmpty)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'alt_names': altNames,
        'country': country,
        'logo': logo,
        'streams': streams.map((s) => s.toJson()).toList(),
      };

  bool get hasLiveStreams => streams.isNotEmpty;

  String get firstStreamUrl {
    if (streams.isEmpty) {
      throw StateError('Channel $id has no live streams');
    }
    return streams.first.url;
  }

  @override
  bool operator ==(Object other) => other is Channel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}