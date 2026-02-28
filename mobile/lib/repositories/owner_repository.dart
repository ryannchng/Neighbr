import '../core/constants.dart';
import '../core/supabase_client.dart';
import '../models/business_model.dart';
import '../models/category_model.dart';

class ReviewSummary {
  const ReviewSummary({
    required this.id,
    required this.rating,
    required this.content,
    required this.authorUsername,
    required this.isVerifiedVisit,
    required this.isFlagged,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String? content;
  final String authorUsername;
  final bool isVerifiedVisit;
  final bool isFlagged;
  final DateTime createdAt;

  factory ReviewSummary.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>?;
    return ReviewSummary(
      id: json['id'] as String,
      rating: json['rating'] as int,
      content: json['content'] as String?,
      authorUsername: user?['username'] as String? ?? 'Anonymous',
      isVerifiedVisit: json['is_verified_visit'] as bool? ?? false,
      isFlagged: json['is_flagged'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class RatingDistribution {
  const RatingDistribution({required this.counts});

  /// counts[0] = 1-star count, counts[4] = 5-star count
  final List<int> counts;

  int get total => counts.fold(0, (a, b) => a + b);
}

class OwnerRepository {
  // -------------------------------------------------------------------------
  // My Businesses
  // -------------------------------------------------------------------------

  Future<List<Business>> getMyBusinesses() async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) return [];
    final data = await SupabaseClientProvider.client
        .from('businesses')
        .select('*, categories(*), business_images(image_url, display_order)')
        .eq('owner_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Business.fromJson(e)).toList();
  }

  // -------------------------------------------------------------------------
  // Single business (owner view)
  // -------------------------------------------------------------------------

  Future<Business?> getBusinessById(String id) async {
    final data = await SupabaseClientProvider.client
        .from('businesses')
        .select('*, categories(*), business_images(image_url, display_order)')
        .eq('id', id)
        .maybeSingle();
    return data != null ? Business.fromJson(data) : null;
  }

  // -------------------------------------------------------------------------
  // Reviews
  // -------------------------------------------------------------------------

  Future<List<ReviewSummary>> getReviews(
    String businessId, {
    int limit = AppConstants.pageSize,
    int offset = 0,
  }) async {
    final data = await SupabaseClientProvider.client
        .from('reviews')
        .select('*, users(username)')
        .eq('business_id', businessId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((e) => ReviewSummary.fromJson(e)).toList();
  }

  Future<RatingDistribution> getRatingDistribution(String businessId) async {
    final data = await SupabaseClientProvider.client
        .from('reviews')
        .select('rating')
        .eq('business_id', businessId);
    final counts = List<int>.filled(5, 0);
    for (final row in data as List) {
      final r = (row['rating'] as int?) ?? 0;
      if (r >= 1 && r <= 5) counts[r - 1]++;
    }
    return RatingDistribution(counts: counts);
  }

  // -------------------------------------------------------------------------
  // Categories
  // -------------------------------------------------------------------------

  Future<List<Category>> getCategories() async {
    final data = await SupabaseClientProvider.client
        .from('categories')
        .select()
        .order('name');
    return (data as List).map((e) => Category.fromJson(e)).toList();
  }

  // -------------------------------------------------------------------------
  // Create / Update business
  // -------------------------------------------------------------------------

  Future<Business> createBusiness({
    required String name,
    required String description,
    String? categoryId,
    String? address,
    String? city,
    String? province,
    String? phone,
    String? website,
    int? priceRange,
  }) async {
    final userId = SupabaseClientProvider.currentUser!.id;
    final data = await SupabaseClientProvider.client
        .from('businesses')
        .insert({
          'owner_id': userId,
          'name': name.trim(),
          'description': description.trim(),
          'category_id': ?categoryId,
          if (address != null && address.trim().isNotEmpty)
            'address': address.trim(),
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
          if (province != null && province.trim().isNotEmpty)
            'province': province.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (website != null && website.trim().isNotEmpty)
            'website': website.trim(),
          'price_range': ?priceRange,
        })
        .select('*, categories(*), business_images(image_url, display_order)')
        .single();
    return Business.fromJson(data);
  }

  Future<Business> updateBusiness({
    required String id,
    required String name,
    required String description,
    String? categoryId,
    String? address,
    String? city,
    String? province,
    String? phone,
    String? website,
    int? priceRange,
  }) async {
    final data = await SupabaseClientProvider.client
        .from('businesses')
        .update({
          'name': name.trim(),
          'description': description.trim(),
          'category_id': categoryId,
          'address': address?.trim(),
          'city': city?.trim(),
          'province': province?.trim(),
          'phone': phone?.trim(),
          'website': website?.trim(),
          'price_range': priceRange,
        })
        .eq('id', id)
        .select('*, categories(*), business_images(image_url, display_order)')
        .single();
    return Business.fromJson(data);
  }

  Future<void> deleteBusiness(String id) async {
    await SupabaseClientProvider.client
        .from('businesses')
        .delete()
        .eq('id', id);
  }

  // -------------------------------------------------------------------------
  // Business hours
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getBusinessHours(
      String businessId) async {
    final data = await SupabaseClientProvider.client
        .from('business_hours')
        .select()
        .eq('business_id', businessId)
        .order('day_of_week');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> upsertBusinessHours(
      String businessId, List<Map<String, dynamic>> hours) async {
    // Delete existing, then insert fresh
    await SupabaseClientProvider.client
        .from('business_hours')
        .delete()
        .eq('business_id', businessId);
    if (hours.isEmpty) return;
    await SupabaseClientProvider.client.from('business_hours').insert(
      hours
          .map((h) => {
                'business_id': businessId,
                'day_of_week': h['day_of_week'],
                'open_time': h['open_time'],
                'close_time': h['close_time'],
              })
          .toList(),
    );
  }
}




