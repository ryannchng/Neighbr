import 'package:flutter/material.dart';

class CategoryIconMapper {
  const CategoryIconMapper._();

  static IconData fromKey(String? rawKey, {String? fallbackName}) {
    final key = _normalize(rawKey);
    if (key.isNotEmpty) {
      final mapped = _map[key];
      if (mapped != null) return mapped;
    }
    return _fromNameFallback(fallbackName);
  }

  static final Map<String, IconData> _map = {
    'restaurant': Icons.restaurant_rounded,
    'restaurant_rounded': Icons.restaurant_rounded,
    'food': Icons.restaurant_rounded,
    'dining': Icons.restaurant_rounded,
    'shopping_bag': Icons.shopping_bag_rounded,
    'shopping_bag_rounded': Icons.shopping_bag_rounded,
    'retail': Icons.shopping_bag_rounded,
    'shop': Icons.shopping_bag_rounded,
    'store': Icons.shopping_bag_rounded,
    'handyman': Icons.handyman_rounded,
    'handyman_rounded': Icons.handyman_rounded,
    'services': Icons.handyman_rounded,
    'service': Icons.handyman_rounded,
    'repair': Icons.handyman_rounded,
    'favorite': Icons.favorite_rounded,
    'favorite_rounded': Icons.favorite_rounded,
    'health': Icons.favorite_rounded,
    'wellness': Icons.favorite_rounded,
    'medical': Icons.favorite_rounded,
    'theaters': Icons.theaters_rounded,
    'theaters_rounded': Icons.theaters_rounded,
    'entertainment': Icons.theaters_rounded,
    'event': Icons.theaters_rounded,
    'content_cut': Icons.content_cut_rounded,
    'content_cut_rounded': Icons.content_cut_rounded,
    'beauty': Icons.content_cut_rounded,
    'salon': Icons.content_cut_rounded,
    'barber': Icons.content_cut_rounded,
    'storefront': Icons.storefront_rounded,
    'storefront_rounded': Icons.storefront_rounded,
    'category': Icons.category_rounded,
    'category_rounded': Icons.category_rounded,
  };

  static String _normalize(String? value) {
    if (value == null) return '';
    return value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  static IconData _fromNameFallback(String? name) {
    final n = (name ?? '').toLowerCase();
    if (n.contains('food') || n.contains('dining') || n.contains('restaurant')) {
      return Icons.restaurant_rounded;
    }
    if (n.contains('retail') || n.contains('shop') || n.contains('store')) {
      return Icons.shopping_bag_rounded;
    }
    if (n.contains('service') || n.contains('repair')) {
      return Icons.handyman_rounded;
    }
    if (n.contains('health') || n.contains('wellness') || n.contains('medical')) {
      return Icons.favorite_rounded;
    }
    if (n.contains('entertainment') || n.contains('event')) {
      return Icons.theaters_rounded;
    }
    if (n.contains('beauty') || n.contains('salon') || n.contains('barber')) {
      return Icons.content_cut_rounded;
    }
    return Icons.storefront_rounded;
  }
}
