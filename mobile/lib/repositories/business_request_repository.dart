import '../core/supabase_client.dart';

class BusinessRequest {
  const BusinessRequest({
    required this.id,
    required this.businessId,
    required this.requesterId,
    required this.requestText,
    required this.status,
    required this.createdAt,
    this.maxBudget,
    this.neededBy,
    this.claimedBy,
    this.requesterUsername,
  });

  final String id;
  final String businessId;
  final String requesterId;
  final String requestText;
  final String status;
  final DateTime createdAt;
  final double? maxBudget;
  final DateTime? neededBy;
  final String? claimedBy;
  final String? requesterUsername;

  bool get isOpen => status == 'open';
  bool get isClaimed => status == 'claimed';
  bool get isCompleted => status == 'completed';

  factory BusinessRequest.fromJson(Map<String, dynamic> json) {
    return BusinessRequest(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      requesterId: json['user_id'] as String,
      requestText: (json['request_text'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'open',
      createdAt: DateTime.parse(json['created_at'] as String),
      maxBudget: (json['max_budget'] as num?)?.toDouble(),
      neededBy: json['needed_by'] != null
          ? DateTime.parse(json['needed_by'] as String)
          : null,
      claimedBy: json['claimed_by'] as String?,
      requesterUsername: json['requester_username'] as String?,
    );
  }
}

class BusinessRequestRepository {
  Future<void> createRequest({
    required String businessId,
    required String requestText,
    double? maxBudget,
    DateTime? neededBy,
  }) async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await SupabaseClientProvider.client.from('business_requests').insert({
      'business_id': businessId,
      'user_id': userId,
      'request_text': requestText.trim(),
      if (maxBudget != null) 'max_budget': maxBudget,
      if (neededBy != null) 'needed_by': neededBy.toIso8601String(),
    });
  }

  Future<List<BusinessRequest>> getRequestsForBusiness(String businessId) async {
    final data = await SupabaseClientProvider.client
        .from('business_requests')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', ascending: false);

    final requests = (data as List)
        .map((e) => BusinessRequest.fromJson(e as Map<String, dynamic>))
        .toList();

    if (requests.isEmpty) return requests;

    final userIds = requests.map((r) => r.requesterId).toSet().toList();
    try {
      final users = await SupabaseClientProvider.client
          .from('users')
          .select('id, username')
          .inFilter('id', userIds);

      final usernameMap = <String, String>{
        for (final u in users as List)
          u['id'] as String: u['username'] as String? ?? 'Customer',
      };

      return requests.map((r) => BusinessRequest(
        id: r.id,
        businessId: r.businessId,
        requesterId: r.requesterId,
        requestText: r.requestText,
        status: r.status,
        createdAt: r.createdAt,
        maxBudget: r.maxBudget,
        neededBy: r.neededBy,
        claimedBy: r.claimedBy,
        requesterUsername: usernameMap[r.requesterId],
      )).toList();
    } catch (_) {
      return requests;
    }
  }

  /// Returns the total number of open requests across a list of business IDs.
  Future<int> getOutstandingCountForBusinesses(List<String> businessIds) async {
    if (businessIds.isEmpty) return 0;
    try {
      final data = await SupabaseClientProvider.client
          .from('business_requests')
          .select('id')
          .inFilter('business_id', businessIds)
          .eq('status', 'open');
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Claim an open request.
  Future<void> takeRequest(String requestId) async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await SupabaseClientProvider.client
        .from('business_requests')
        .update({
          'status': 'claimed',
          'claimed_by': userId,
        })
        .eq('id', requestId)
        .eq('status', 'open');
  }

  /// Mark a claimed request as completed/done.
  Future<void> markDone(String requestId) async {
    await SupabaseClientProvider.client
        .from('business_requests')
        .update({'status': 'completed'})
        .eq('id', requestId)
        .eq('status', 'claimed');
  }
}