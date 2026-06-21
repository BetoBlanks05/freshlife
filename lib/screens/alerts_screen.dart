import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../services/firestore_service.dart';

// FIX: colores al nivel de módulo para no generar "unused field" en clases
const _kTeal   = Color(0xFF4DB6AC);
const _kOrange = Color(0xFFFF9800);
const _kDark   = Color(0xFF263238);

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: _kDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Alertas',
          style: TextStyle(
              color: _kDark,
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.getInventoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _kTeal));
          }

          final docs = snapshot.data?.docs ?? [];
          final allProducts = docs
              .map((d) => Product.fromMap(
                  d.data() as Map<String, dynamic>, d.id))
              .toList();

          final lowStock =
              allProducts.where((p) => p.isLowStock).toList();
          final recentlyUpdated = allProducts
              .where((p) => !p.isLowStock)
              .take(5)
              .toList();

          if (lowStock.isEmpty && recentlyUpdated.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 72, color: _kTeal),
                  SizedBox(height: 16),
                  Text('¡Todo en orden!',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('No hay alertas en este momento',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...lowStock.map(
                  (p) => _AlertCard(product: p, service: service)),
              if (recentlyUpdated.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...recentlyUpdated
                    .map((p) => _InfoCard(product: p)),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Tarjeta alerta naranja ─────────────────────────────────────
class _AlertCard extends StatelessWidget {
  final Product product;
  final FirestoreService service;
  const _AlertCard({required this.product, required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // FIX: withOpacity → withValues(alpha:)
        color: _kOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kOrange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: _kOrange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: _kDark,
                        fontSize: 14,
                        height: 1.4),
                    children: [
                      const TextSpan(
                        text: '¡Atención! ',
                        style:
                            TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: 'Queda poca '),
                      TextSpan(
                        text: '*${product.name}*',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: '. Stock actual: '
                            '${product.quantity.toInt()} ${product.unit}'
                            ' (Mínimo: ${product.minStock.toInt()}).',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await service.addToShoppingList(product);
                // FIX: mounted check tras await
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${product.name} agregado a lista de compras'),
                      backgroundColor: _kTeal,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kOrange),
                foregroundColor: _kOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text('Agregar a Lista de Compras',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta informativa gris ───────────────────────────────────
class _InfoCard extends StatelessWidget {
  final Product product;
  const _InfoCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              color: Colors.blue.shade400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: Color(0xFF455A64),
                    fontSize: 13,
                    height: 1.4),
                children: [
                  const TextSpan(text: 'El '),
                  TextSpan(
                    text: '*${product.name}*',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                      text: ' se ha actualizado correctamente.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
