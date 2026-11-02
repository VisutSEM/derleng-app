class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    this.provider = 'password',
  });

  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final String provider;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final email = '${json['email'] ?? ''}';
    final name = '${json['name'] ?? json['display_name'] ?? json['displayName'] ?? _nameFromEmail(email)}';
    return AppUser(
      id: '${json['id'] ?? json['uid'] ?? json['user_id'] ?? email}',
      email: email,
      name: name.isEmpty ? 'Traveler' : name,
      photoUrl: (json['photo_url'] ?? json['photoUrl'] ?? json['avatar']) as String?,
      provider: '${json['provider'] ?? json['provider_id'] ?? 'password'}',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        if (photoUrl != null) 'photo_url': photoUrl,
        'provider': provider,
      };

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
    String? provider,
    bool clearPhotoUrl = false,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      provider: provider ?? this.provider,
    );
  }

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.first.isEmpty ? 'there' : parts.first;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    String firstLetter(String value) => value.substring(0, 1).toUpperCase();
    if (parts.length == 1) return firstLetter(parts.first);
    return firstLetter(parts.first) + firstLetter(parts.last);
  }

  static String _nameFromEmail(String email) {
    final local = email.split('@').first.replaceAll(RegExp(r'[._-]+'), ' ');
    if (local.isEmpty) return '';
    return local
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
