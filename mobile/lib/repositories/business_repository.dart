import '../core/constants.dart';
import '../core/supabase_client.dart';
import '../models/business_model.dart';
import '../models/category_model.dart';
import '../screens/browse/browse_screen.dart' show SortOption;

// Supabase embedded-select fragment reused across every business query.
const _kBusinessSelect =
    '*, categories(*), business_images(image_url, display_order)';

class BusinessRepository {
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
  // All businesses — with sort + pagination (used by Browse screen)
  // -------------------------------------------------------------------------

  Future<List<Business>> getAll({
    SortOption sort = SortOption.topRated,
    int limit = AppConstants.pageSize,
    int offset = 0,
  }) async {
    final base = SupabaseClientProvider.client
        .from('businesses')
        .select(_kBusinessSelect);

    final data = await switch (sort) {
      SortOption.topRated => base
          .order('avg_rating', ascending: false)
          .order('review_count', ascending: false)
          .range(offset, offset + limit - 1),
      SortOption.newest => base
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1),
      SortOption.mostReviewed => base
          .order('review_count', ascending: false)
          .order('avg_rating', ascending: false)
          .range(offset, offset + limit - 1),
      SortOption.nameAZ => base
          .order('name', ascending: true)
          .range(offset, offset + limit - 1),
    };

    return _mapList(data);
  }

  // -------------------------------------------------------------------------
  // Featured — top-rated verified businesses, any category
  // -------------------------------------------------------------------------

  Future<List<Business>> getFeatured({int limit = 6}) async {
    final data = await SupabaseClientProvider.client
        .from('businesses')
        .select(_kBusinessSelect)
        .eq('is_verified', true)
        .gte('avg_rating', 4.0)
        .order('avg_rating', ascending: false)
        .order('review_count', ascending: false)
        .limit(limit);
    return _mapList(data);
  }

  // -------------------------------------------------------------------------
  // Newest — most recently created
  // -------------------------------------------------------------------------

  Future<List<Business>> getNewest({int limit = 10}) async {
    final data = await SupabaseClientProvider.client
        .from('businesses')
        .select(_kBusinessSelect)
        .order('created_at', ascending: false)
        .limit(limit);
    return _mapList(data);
  }

  // -------------------------------------------------------------------------
  // By category — with sort + pagination
  // -------------------------------------------------------------------------

  Future<List<Business>> getByCategory(
    String categoryId, {
    SortOption sort = SortOption.topRated,
    int limit = AppConstants.pageSize,
    int offset = 0,
  }) async {
    final base = SupabaseClientProvider.client
        .from('businesses')
        .select(_kBusinessSelect)
        .eq('category_id', categoryId);

    final data = await switch (sort) {
      SortOption.topRated => base
          .order('avg_rating', ascending: false)
          .order('review_count', ascending: false)
          .range(offset, offset + limit - 1),
      SortOption.newest => base
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1),
      SortOption.mostReviewed => base
          .order('review_count', ascending: false)
          .order('avg_rating', ascending: false)
          .range(offset, offset + limit - 1),
      SortOption.nameAZ => base
          .order('name', ascending: true)
          .range(offset, offset + limit - 1),
    };

    return _mapList(data);
  }

  // -------------------------------------------------------------------------
  // Search by name / city
  // -------------------------------------------------------------------------

  Future<List<Business>> search(
    String query, {
    int limit = AppConstants.pageSize,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final data = await SupabaseClientProvider.client
        .from('businesses')
        .select(_kBusinessSelect)
        .or('name.ilike.%$q%,city.ilike.%$q%,description.ilike.%$q%')
        .order('avg_rating', ascending: false)
        .limit(limit);
    return _mapList(data);
  }

  // -------------------------------------------------------------------------
  // Single business
  // -------------------------------------------------------------------------

  Future<Business?> getById(String id) async {
    final data = await SupabaseClientProvider.client
        .from('businesses')
        .select(_kBusinessSelect)
        .eq('id', id)
        .maybeSingle();
    return data != null ? Business.fromJson(data) : null;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  List<Business> _mapList(dynamic data) =>
      (data as List).map((e) => Business.fromJson(e)).toList();
}