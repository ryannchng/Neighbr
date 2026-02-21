import '../core/constants.dart';
import '../core/supabase_client.dart';

class UserReview {
  const UserReview({
    required this.id,
    required this.businessId,
    required this.businessName,
    this.businessImageUrl,
    required this.rating,
    this.content,
    required this.isVerifiedVisit,
    required this.isFlagged,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String? businessImageUrl;
  final int rating;
  final String? content;
  final bool isVerifiedVisit;
  final bool isFlagged;
  final DateTime createdAt;

  factory UserReview.fromJson(Map<String, dynamic> json) {
    final business = json['businesses'] as Map<String, dynamic>?;
    final images = business?['business_images'] as List<dynamic>?;
    final firstImage = images?.isNotEmpty == true
        ? images!.first['image_url'] as String?
        : null;

    return UserReview(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      businessName: business?['name'] as String? ?? 'Unknown Business',
      businessImageUrl: firstImage,
      rating: json['rating'] as int,
      content: json['content'] as String?,
      isVerifiedVisit: json['is_verified_visit'] as bool? ?? false,
      isFlagged: json['is_flagged'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ReviewRepository {
  // ── Fetch user's own reviews ───────────────────────────────────────────────

  Future<List<UserReview>> getMyReviews({
    int limit = AppConstants.pageSize,
    int offset = 0,
  }) async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) return [];

    final data = await SupabaseClientProvider.client
        .from('reviews')
        .select('*, businesses(name, business_images(image_url, display_order))')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List).map((e) => UserReview.fromJson(e)).toList();
  }

  // ── Check if user already reviewed a business ─────────────────────────────

  Future<bool> hasReviewed(String businessId) async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) return false;

    final data = await SupabaseClientProvider.client
        .from('reviews')
        .select('id')
        .eq('business_id', businessId)
        .eq('user_id', userId)
        .maybeSingle();

    return data != null;
  }

  // ── Submit a new review ───────────────────────────────────────────────────

  Future<void> submitReview({
    required String businessId,
    required int rating,
    String? content,
    bool isVerifiedVisit = false,
  }) async {
    final user = SupabaseClientProvider.currentUser;
    if (user?.isAnonymous ?? false) {
      throw Exception('Guest users cannot submit reviews.');
    }

    final userId = user?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Check for duplicate before inserting
    final existing = await SupabaseClientProvider.client
        .from('reviews')
        .select('id')
        .eq('business_id', businessId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('You have already reviewed this business.');
    }

    await SupabaseClientProvider.client.from('reviews').insert({
      'business_id': businessId,
      'user_id': userId,
      'rating': rating,
      if (content != null && content.isNotEmpty) 'content': content,
      'is_verified_visit': isVerifiedVisit,
    });
  }

  // ── Delete a review ───────────────────────────────────────────────────────

  Future<void> deleteReview(String reviewId) async {
    await SupabaseClientProvider.client
        .from('reviews')
        .delete()
        .eq('id', reviewId);
  }
}
