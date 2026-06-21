import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  static const _teal = Color(0xFF4DB6AC);
  static const _dark = Color(0xFF263238);

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Lista de Compras',
          style: TextStyle(
              color: _dark, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          // Limpiar items marcados
          StreamBuilder<QuerySnapshot>(
            stream: service.getShoppingListStream(),
            builder: (context, snap) {
              final hasChecked = (snap.data?.docs ?? [])
                  .any((d) => (d.data() as Map)['checked'] == true);
              if (!hasChecked) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  final docs = snap.data?.docs ?? [];
                  for (var d in docs) {
                    if ((d.data() as Map)['checked'] == true) {
                      await service.removeFromShoppingList(d.id);
                    }
                  }
                },
                child: const Text('Limpiar',
                    style: TextStyle(color: Colors.red)),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getShoppingListStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _teal));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 72, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Tu lista de compras está vacía',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Los productos con stock bajo\naparecerán aquí automáticamente',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final pending =
              docs.where((d) => (d.data() as Map)['checked'] != true).toList();
          final done =
              docs.where((d) => (d.data() as Map)['checked'] == true).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...pending.map((d) =>
                  _ShoppingItem(doc: d, service: service)),
              if (done.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Comprados',
                      style:
                          TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                ),
                ...done.map((d) =>
                    _ShoppingItem(doc: d, service: service)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ShoppingItem extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final FirestoreService service;
  const _ShoppingItem({required this.doc, required this.service});

  static const _teal = Color(0xFF4DB6AC);

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final isChecked = data['checked'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isChecked ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (!isChecked)
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
        ],
      ),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: (v) => service.toggleShoppingItem(doc.id, v ?? false),
        activeColor: _teal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          data['name'] ?? '',
          style: TextStyle(
            decoration:
                isChecked ? TextDecoration.lineThrough : null,
            color: isChecked ? Colors.grey : const Color(0xFF263238),
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: data['quantity'] != null
            ? Text(data['quantity'],
                style: const TextStyle(fontSize: 12, color: Colors.grey))
            : null,
        secondary: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          color: Colors.grey,
          onPressed: () => service.removeFromShoppingList(doc.id),
        ),
      ),
    );
  }
}
