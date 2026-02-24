import '../core/constants.dart';
import '../core/supabase_client.dart';
import '../models/category_model.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class MarketplaceRequest {
  const MarketplaceRequest({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.category,
    this.city,
    this.maxBudget,
    this.neededBy,
    this.recommendationCount,
  });

  final String id;
  final String userId;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;
  final Category? category;
  final String? city;
  final double? maxBudget;
  final DateTime? neededBy;
  final int? recommendationCount;

  bool get isOpen => status == 'open';
  bool get isFulfilled => status == 'fulfilled';
  bool get isCancelled => status == 'cancelled';

  factory MarketplaceRequest.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['categories'] as Map<String, dynamic>?;
    return MarketplaceRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.parse(json['created_at'] as String),
      category:
          rawCategory != null ? Category.fromJson(rawCategory) : null,
      city: json['city'] as String?,
      maxBudget: (json['max_budget'] as num?)?.toDouble(),
      neededBy: json['needed_by'] != null
          ? DateTime.parse(json['needed_by'] as String)
          : null,
      recommendationCount: json['recommendation_count'] as int?,
    );
  }
}

/// A marketplace request as seen by a business owner — enriched with
/// the requester's username and the recommendation's current status.
class RecommendedRequest {
  const RecommendedRequest({
    required this.recommendationId,
    required this.recommendationStatus,
    required this.request,
    this.requesterUsername,
  });

  final String recommendationId;

  /// 'pending' | 'viewed' | 'claimed' | 'declined'
  final String recommendationStatus;
  final MarketplaceRequest request;
  final String? requesterUsername;

  bool get isPending => recommendationStatus == 'pending';
  bool get isClaimed => recommendationStatus == 'claimed';
  bool get isDeclined => recommendationStatus == 'declined';

  factory RecommendedRequest.fromJson(Map<String, dynamic> json) {
    final reqJson = json['marketplace_requests'] as Map<String, dynamic>;
    return RecommendedRequest(
      recommendationId: json['id'] as String,
      recommendationStatus: json['status'] as String? ?? 'pending',
      request: MarketplaceRequest.fromJson(reqJson),
      requesterUsername: json['requester_username'] as String?,
    );
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class MarketplaceRequestRepository {
  // ── Customer: create ─────────────────────────────────────────────────────

  Future<MarketplaceRequest> createRequest({
    required String title,
    required String description,
    String? categoryId,
    String? city,
    double? maxBudget,
    DateTime? neededBy,
  }) async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final data = await SupabaseClientProvider.client
        .from('marketplace_requests')
        .insert({
          'user_id': userId,
          'title': title.trim(),
          'description': description.trim(),
          if (categoryId != null) 'category_id': categoryId,
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
          if (maxBudget != null) 'max_budget': maxBudget,
          if (neededBy != null) 'needed_by': neededBy.toIso8601String(),
        })
        .select('*, categories(*)')
        .single();

    return MarketplaceRequest.fromJson(data);
  }

  // ── Customer: fetch own requests ─────────────────────────────────────────

  Future<List<MarketplaceRequest>> getMyRequests({
    int limit = AppConstants.pageSize,
    int offset = 0,
  }) async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) return [];

    final data = await SupabaseClientProvider.client
        .from('marketplace_requests')
        .select('*, categories(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List)
        .map((e) => MarketplaceRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Customer: cancel ─────────────────────────────────────────────────────

  Future<void> cancelRequest(String requestId) async {
    await SupabaseClientProvider.client
        .from('marketplace_requests')
        .update({'status': 'cancelled'})
        .eq('id', requestId)
        .eq('status', 'open'); // Only open requests can be cancelled
  }

  // ── Owner: fetch recommendations for a business ──────────────────────────

  Future<List<RecommendedRequest>> getRecommendationsForBusiness(
    String businessId, {
    String? statusFilter, // null = all, or 'pending'/'claimed'/etc.
    int limit = AppConstants.pageSize,
    int offset = 0,
  }) async {
    var query = SupabaseClientProvider.client
        .from('request_recommendations')
        .select(
          '''
          id,
          status,
          created_at,
          marketplace_requests(
            id, user_id, title, description, status, city,
            max_budget, needed_by, created_at,
            categories(id, name, icon)
          )
          ''',
        )
        .eq('business_id', businessId)
        // Only show recommendations where the underlying request is still open
        .not('marketplace_requests.status', 'eq', 'cancelled');

    if (statusFilter != null) {
      query = query.eq('status', statusFilter);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    // Enrich with requester usernames in a single follow-up query
    final recs = (data as List)
        .where((e) => e['marketplace_requests'] != null)
        .map((e) => RecommendedRequest.fromJson(e as Map<String, dynamic>))
        .toList();

    if (recs.isEmpty) return recs;

    final userIds = recs.map((r) => r.request.userId).toSet().toList();
    try {
      final users = await SupabaseClientProvider.client
          .from('users')
          .select('id, username')
          .inFilter('id', userIds);

      final usernameMap = <String, String>{
        for (final u in users as List)
          u['id'] as String: u['username'] as String? ?? 'Customer',
      };

      return recs
          .map(
            (r) => RecommendedRequest(
              recommendationId: r.recommendationId,
              recommendationStatus: r.recommendationStatus,
              request: r.request,
              requesterUsername: usernameMap[r.request.userId],
            ),
          )
          .toList();
    } catch (_) {
      return recs;
    }
  }

  /// Count of pending (not yet acted on) recommendations for a business.
  Future<int> getPendingRecommendationCount(String businessId) async {
    try {
      final data = await SupabaseClientProvider.client
          .from('request_recommendations')
          .select('id')
          .eq('business_id', businessId)
          .eq('status', 'pending');
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  // ── Owner: update recommendation status ─────────────────────────────────

  Future<void> markViewed(String recommendationId) async {
    await SupabaseClientProvider.client
        .from('request_recommendations')
        .update({'status': 'viewed'})
        .eq('id', recommendationId)
        .eq('status', 'pending'); // Only advance from pending
  }

  Future<void> claimRecommendation(String recommendationId) async {
    await SupabaseClientProvider.client
        .from('request_recommendations')
        .update({'status': 'claimed'})
        .eq('id', recommendationId)
        .inFilter('status', ['pending', 'viewed']);
  }

  Future<void> declineRecommendation(String recommendationId) async {
    await SupabaseClientProvider.client
        .from('request_recommendations')
        .update({'status': 'declined'})
        .eq('id', recommendationId)
        .inFilter('status', ['pending', 'viewed']);
  }
}