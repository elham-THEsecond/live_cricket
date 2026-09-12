class StreamUrl {
  final String url;
  final String referrer;
  final String userAgent;
  final String status;
  final DateTime? validated;

  const StreamUrl({
    required this.url,
    this.referrer = '',
    this.userAgent = '',
    this.status = 'live',
    this.validated,
  });

  factory StreamUrl.fromJson(Map<String, dynamic> json) => StreamUrl(
        url: json['url'] as String? ?? '',
        referrer: json['referrer'] as String? ?? '',
        userAgent: json['user_agent'] as String? ?? '',
        status: json['status'] as String? ?? 'live',
        validated: DateTime.tryParse(json['validated'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'referrer': referrer,
        'user_agent': userAgent,
        'status': status,
        'validated': validated?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) => other is StreamUrl && other.url == url;

  @override
  int get hashCode => url.hashCode;
}