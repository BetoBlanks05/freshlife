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

  // ── Inventario ──────────────────────────────────────────────

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

  // ── Lista de Compras 

  Future<void> addToShoppingList(Product product) async {
    final sl = _shoppingList;
    if (sl == null) return;
    // Evita duplicados
    final existing =
        await sl.where('name', isEqualTo: product.name).limit(1).get();
    if (existing.docs.isEmpty) {
      await sl.add({
        'name': product.name,
        'quantity': '${product.minStock.toInt()} ${product.unit}',
        'checked': false,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
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
