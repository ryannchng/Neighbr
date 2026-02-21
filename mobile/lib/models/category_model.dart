class Category {
  const Category({
    required this.id,
    required this.name,
    required this.iconKey,
  });

  final String id;
  final String name;
  final String iconKey;

  // Backward-compatible alias for older code paths.
  String get icon => iconKey;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        iconKey: (json['icon_key'] ?? json['icon']) as String? ?? '',
      );
}
