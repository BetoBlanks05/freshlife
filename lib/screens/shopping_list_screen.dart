import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../services/firestore_service.dart';

const _kTeal   = Color(0xFF4DB6AC);
const _kOrange = Color(0xFFFF9800);
const _kDark   = Color(0xFF263238);

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Lista de Compras',
            style: TextStyle(
                color: _kDark,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: _kTeal),
            tooltip: 'Agregar artículo',
            onPressed: () => _showAddItemDialog(context, service),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Stream 1: inventario para calcular stock bajo automático
        stream: service.getInventoryStream(),
        builder: (context, invSnap) {
          return StreamBuilder<QuerySnapshot>(
            // Stream 2: lista manual de compras
            stream: service.getShoppingListStream(),
            builder: (context, listSnap) {
              if (invSnap.connectionState == ConnectionState.waiting ||
                  listSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kTeal));
              }

              // ── Artículos con stock bajo (auto) ────────────────
              final lowStock = (invSnap.data?.docs ?? [])
                  .map((d) => Product.fromMap(
                      d.data() as Map<String, dynamic>, d.id))
                  .where((p) => p.isLowStock)
                  .toList();

              // ── Artículos manuales ─────────────────────────────
              final manualDocs = listSnap.data?.docs ?? [];
              final pending = manualDocs
                  .where((d) =>
                      (d.data() as Map)['checked'] != true)
                  .toList();
              final done = manualDocs
                  .where((d) =>
                      (d.data() as Map)['checked'] == true)
                  .toList();

              if (lowStock.isEmpty && manualDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 72, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('Tu lista está vacía',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      const Text(
                        'Los productos con stock bajo aparecerán\naquí automáticamente',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () =>
                            _showAddItemDialog(context, service),
                        icon: const Icon(Icons.add, color: _kTeal),
                        label: const Text('Agregar artículo',
                            style: TextStyle(color: _kTeal)),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Sección: Por Agotarse (auto) ───────────────
                  if (lowStock.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.warning_amber_rounded,
                      color: _kOrange,
                      title: 'Por Reponer',
                      subtitle: '${lowStock.length} productos con stock bajo',
                    ),
                    const SizedBox(height: 8),
                    ...lowStock.map((p) => _LowStockItem(
                          product: p,
                          service: service,
                        )),
                    const SizedBox(height: 16),
                  ],

                  // ── Sección: Lista manual ──────────────────────
                  if (pending.isNotEmpty) ...[
                    _SectionHeader(
                      icon: Icons.list_alt,
                      color: _kTeal,
                      title: 'Lista Personal',
                      subtitle: '${pending.length} artículos',
                    ),
                    const SizedBox(height: 8),
                    ...pending.map((d) =>
                        _ManualItem(doc: d, service: service)),
                    const SizedBox(height: 16),
                  ],

                  // ── Sección: Comprados ─────────────────────────
                  if (done.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Comprados',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600)),
                        TextButton(
                          onPressed: () async {
                            for (final d in done) {
                              await service
                                  .removeFromShoppingList(d.id);
                            }
                          },
                          child: const Text('Limpiar',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                    ...done.map((d) =>
                        _ManualItem(doc: d, service: service)),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showAddItemDialog(
      BuildContext context, FirestoreService service) {
    final nameCtrl = TextEditingController();
    final qtyCtrl  = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar artículo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nombre del artículo'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(
                  labelText: 'Cantidad (ej: 2 kg)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await service.addManualItem(
                  nameCtrl.text.trim(),
                  qtyCtrl.text.trim().isEmpty
                      ? '1'
                      : qtyCtrl.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Agregar',
                style: TextStyle(color: _kTeal)),
          ),
        ],
      ),
    );
  }
}

// ── Artículo con stock bajo (auto) ────────────────────────────
class _LowStockItem extends StatelessWidget {
  final Product product;
  final FirestoreService service;
  const _LowStockItem(
      {required this.product, required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(Icons.warning_amber_rounded,
            color: _kOrange, size: 22),
        title: Text(product.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            'Actual: ${product.quantity.toInt()} ${product.unit}  •  '
            'Mínimo: ${product.minStock.toInt()} ${product.unit}',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: IconButton(
          icon: const Icon(Icons.add_shopping_cart,
              color: _kTeal, size: 22),
          tooltip: 'Agregar a lista manual',
          onPressed: () async {
            await service.addToShoppingList(product);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${product.name} agregado a lista manual'),
                  backgroundColor: _kTeal,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

// ── Artículo manual con checkbox ─────────────────────────────
class _ManualItem extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final FirestoreService service;
  const _ManualItem({required this.doc, required this.service});

  @override
  Widget build(BuildContext context) {
    final data      = doc.data() as Map<String, dynamic>;
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
                blurRadius: 4),
        ],
      ),
      child: CheckboxListTile(
        value: isChecked,
        onChanged: (v) =>
            service.toggleShoppingItem(doc.id, v ?? false),
        activeColor: _kTeal,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: Text(
          data['name'] ?? '',
          style: TextStyle(
            decoration: isChecked ? TextDecoration.lineThrough : null,
            color: isChecked ? Colors.grey : _kDark,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: (data['neededQty'] ?? '').isNotEmpty
            ? Text(data['neededQty'],
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey))
            : null,
        secondary: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          color: Colors.grey.shade400,
          onPressed: () => service.removeFromShoppingList(doc.id),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _SectionHeader(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(width: 8),
          Text(subtitle,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 12)),
        ],
      );
}
