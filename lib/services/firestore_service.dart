import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference? get _inventory {
    if (_uid == null) return null;
    return _db.collection('users').doc(_uid).collection('inventory');
  }

  CollectionReference? get _shoppingList {
    if (_uid == null) return null;
    return _db.collection('users').doc(_uid).collection('shopping_list');
  }

  // ── Cache GLOBAL de clasificación de productos ───────────────
  // Todos los usuarios comparten esta colección, ahorrando llamadas a la IA
  CollectionReference get _cache =>
      _db.collection('product_knowledge');

  String _normalizeKey(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[áàä]'), 'a')
      .replaceAll(RegExp(r'[éèë]'), 'e')
      .replaceAll(RegExp(r'[íìï]'), 'i')
      .replaceAll(RegExp(r'[óòö]'), 'o')
      .replaceAll(RegExp(r'[úùü]'), 'u')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .trim();

  /// Consulta si un producto ya fue clasificado antes.
  /// Retorna null si no existe en caché.
  Future<bool?> getCachedClassification(String productName) async {
    try {
      final key = _normalizeKey(productName);
      if (key.isEmpty) return null;
      final doc = await _cache.doc(key).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>?;
      return data?['isFood'] as bool?;
    } catch (e) {
      return null; // Si falla la caché, no bloquear
    }
  }

  /// Guarda la clasificación de un producto en la caché global.
  Future<void> saveCachedClassification(
      String productName, bool isFood) async {
    try {
      final key = _normalizeKey(productName);
      if (key.isEmpty) return;
      await _cache.doc(key).set({
        'isFood': isFood,
        'name': productName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Silencioso: la caché es opcional
    }
  }

  // ── Inventario ───────────────────────────────────────────────

  Future<void> saveProducts(List<Product> products) async {
    final inv = _inventory;
    if (inv == null) return;
    for (var p in products) {
      await inv.add(p.toMap());
    }
  }

  Future<void> updateProduct(Product product) async {
    if (product.id == null) return;
    await _inventory?.doc(product.id).update(product.toMap());
  }

  Future<void> updateQuantity(String id, double qty) async {
    if (qty < 0) return;
    await _inventory?.doc(id).update({'quantity': qty});
  }

  Future<void> deleteProduct(String id) async {
    await _inventory?.doc(id).delete();
  }

  Stream<QuerySnapshot> getInventoryStream() {
    if (_uid == null) return const Stream.empty();
    return _inventory!.orderBy('name').snapshots();
  }

  // ── Lista de Compras ─────────────────────────────────────────

  Future<void> addToShoppingList(Product product) async {
    final sl = _shoppingList;
    if (sl == null) return;
    final existing =
        await sl.where('name', isEqualTo: product.name).limit(1).get();
    if (existing.docs.isEmpty) {
      await sl.add({
        'name': product.name,
        'neededQty':
            '${product.minStock.toInt()} ${product.unit}',
        'checked': false,
        'isAuto': true,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> addManualItem(String name, String qty) async {
    final sl = _shoppingList;
    if (sl == null) return;
    await sl.add({
      'name': name,
      'neededQty': qty,
      'checked': false,
      'isAuto': false,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getShoppingListStream() {
    if (_uid == null) return const Stream.empty();
    return _shoppingList!.orderBy('addedAt').snapshots();
  }

  Future<void> toggleShoppingItem(String id, bool checked) async {
    await _shoppingList?.doc(id).update({'checked': checked});
  }

  Future<void> removeFromShoppingList(String id) async {
    await _shoppingList?.doc(id).delete();
  }
}
