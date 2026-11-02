import 'geo_point.dart';

/// A search result / destination returned by `GET /places/search`.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    this.category,
    this.rating,
    this.ratingCount,
  });

  final String id;
  final String name;
  final String address;
  final GeoPoint location;
  final String? category;
  final double? rating;
  final int? ratingCount;

  factory Place.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] ?? json['displayName'] ?? '';
    final rawAddress = json['address'] ?? json['formattedAddress'] ?? '';
    final locationJson = json['location'];
    final location = locationJson is Map
        ? GeoPoint.fromJson(Map<String, dynamic>.from(locationJson))
        : GeoPoint.fromJson(json);
    final rawRatingCount = json['rating_count'] ?? json['userRatingsTotal'];

    return Place(
      id: '${json['id'] ?? json['place_id'] ?? json['placeId'] ?? rawName}',
      name: rawName is Map ? '${rawName['text'] ?? ''}' : '$rawName',
      address: '$rawAddress',
      location: location,
      category: json['category'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: rawRatingCount is num ? rawRatingCount.toInt() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'location': location.toJson(),
        if (category != null) 'category': category,
        if (rating != null) 'rating': rating,
        if (ratingCount != null) 'rating_count': ratingCount,
      };

  Place copyWith({
    String? id,
    String? name,
    String? address,
    GeoPoint? location,
    String? category,
    double? rating,
    int? ratingCount,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      location: location ?? this.location,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
    );
  }

  @override
  bool operator ==(Object other) => other is Place && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Place($id, $name)';
}
