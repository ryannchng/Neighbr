import 'category_model.dart';

class Business {
  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    this.category,
    this.address,
    this.city,
    this.province,
    this.latitude,
    this.longitude,
    this.phone,
    this.website,
    required this.isVerified,
    required this.avgRating,
    required this.reviewCount,
    required this.createdAt,
    this.priceRange,
    this.images = const [],
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final Category? category;
  final String? address;
  final String? city;
  final String? province;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? website;
  final bool isVerified;
  final double avgRating;
  final int reviewCount;
  final DateTime createdAt;
  final int? priceRange;
  final List<String> images;

  /// First image URL, or null if none.
  String? get primaryImage => images.isEmpty ? null : images.first;

  /// City + province shorthand, e.g. "Toronto, ON"
  String? get location {
    if (city != null && province != null) return '$city, $province';
    return city ?? province;
  }

  /// Dollar-sign string for price range, e.g. "\$\$"
  String? get priceRangeLabel =>
      priceRange != null ? List.filled(priceRange!, '\$').join() : null;

  factory Business.fromJson(Map<String, dynamic> json) {
    final rawImages = json['business_images'] as List<dynamic>?;
    final images = (rawImages ?? [])
        .map((e) => e['image_url'] as String)
        .toList();

    final rawCategory = json['categories'];
    final category = rawCategory != null
        ? Category.fromJson(rawCategory as Map<String, dynamic>)
        : null;

    return Business(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: category,
      address: json['address'] as String?,
      city: json['city'] as String?,
      province: json['province'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      priceRange: json['price_range'] as int?,
      images: images,
    );
  }
}