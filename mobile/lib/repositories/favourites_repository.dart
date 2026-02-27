import 'dart:async';
import 'dart:developer' as dev;

import '../core/supabase_client.dart';
import '../models/business_model.dart';

const _kBusinessSelect =
    '*, categories(*), business_images(image_url, display_order)';

class FavouritesRepository {
  static final Map<String, Future<void>> _toggleChains = {};

  // ── Fetch all saved businesses ─────────────────────────────────────────────

  Future<List<Business>> getSaved() async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) return [];

    final data = await SupabaseClientProvider.client
        .from('saved_businesses')
        .select('business_id, businesses($_kBusinessSelect)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => Business.fromJson(e['businesses'] as Map<String, dynamic>))
        .toList();
  }

  // ── Check if a business is saved ──────────────────────────────────────────

  Future<bool> isSaved(String businessId) async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) return false;

    final data = await SupabaseClientProvider.client
        .from('saved_businesses')
        .select('business_id')
        .eq('user_id', userId)
        .eq('business_id', businessId)
        .maybeSingle();

    return data != null;
  }

  // ── Save a business ────────────────────────────────────────────────────────

  Future<void> save(String businessId) async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseClientProvider.client.from('saved_businesses').upsert({
        'user_id': userId,
        'business_id': businessId,
      });
    } catch (e, st) {
      dev.log('FavouritesRepository.save error: $e', stackTrace: st);
      rethrow;
    }
  }

  // ── Unsave a business ──────────────────────────────────────────────────────

  Future<void> unsave(String businessId) async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) return;

    await SupabaseClientProvider.client
        .from('saved_businesses')
        .delete()
        .eq('user_id', userId)
        .eq('business_id', businessId);
  }

  // ── Toggle ─────────────────────────────────────────────────────────────────

  Future<bool> toggle(String businessId) async {
    final chainKey = businessId;
    final previous = _toggleChains[chainKey] ?? Future<void>.value();
    final gate = Completer<void>();
    final currentChain = previous.catchError((_) {}).then((_) => gate.future);
    _toggleChains[chainKey] = currentChain;

    try {
      await previous.catchError((_) {});
      final saved = await isSaved(businessId);
      if (saved) {
        await unsave(businessId);
        return false;
      } else {
        await save(businessId);
        return true;
      }
    } finally {
      gate.complete();
      if (identical(_toggleChains[chainKey], currentChain)) {
        _toggleChains.remove(chainKey);
      }
    }
  }
}
