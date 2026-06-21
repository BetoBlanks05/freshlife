class Product {
  final String? id;
  final String name;
  final double price;
  final String category;
  final double quantity;
  final String unit;
  final double minStock;
  final DateTime? expiryDate;

  Product({
    this.id,
    required this.name,
    required this.price,
    this.category = 'General',
    this.quantity = 1.0,
    this.unit = 'pza',
    this.minStock = 1.0,
    this.expiryDate,
  });

  /// true si la cantidad actual está en o por debajo del mínimo
  bool get isLowStock => quantity <= minStock;

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'minStock': minStock,
        'expiryDate': expiryDate?.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map, String id) => Product(
        id: id,
        name: map['name'] ?? '',
        price: (map['price'] ?? 0).toDouble(),
        category: map['category'] ?? 'General',
        quantity: (map['quantity'] ?? 1).toDouble(),
        unit: map['unit'] ?? 'pza',
        minStock: (map['minStock'] ?? 1).toDouble(),
        expiryDate: map['expiryDate'] != null
            ? DateTime.tryParse(map['expiryDate'])
            : null,
      );

  Product copyWith({
    String? id,
    String? name,
    double? price,
    String? category,
    double? quantity,
    String? unit,
    double? minStock,
    DateTime? expiryDate,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        category: category ?? this.category,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        minStock: minStock ?? this.minStock,
        expiryDate: expiryDate ?? this.expiryDate,
      );
}
