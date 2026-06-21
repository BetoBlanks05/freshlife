import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../utils/ticket_parser.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import 'add_product_screen.dart';
import 'alerts_screen.dart';
import 'login_screen.dart';

// Colores globales del módulo (no en clases individuales para evitar "unused")
const _kTeal   = Color(0xFF4DB6AC);
const _kOrange = Color(0xFFFF9800);
const _kDark   = Color(0xFF263238);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _aiService        = AIService();
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Escaneo de ticket ──────────────────────────────────────
  Future<void> _scanTicket() async {
    final picker = ImagePicker();
    final image  = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;
    if (!mounted) return;

    _showLoadingDialog('Analizando ticket...');

    final inputImage = InputImage.fromFilePath(image.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognized = await recognizer.processImage(inputImage);
      final rawProducts = TicketParser.parseText(recognized.text);
      final foodProducts =
          await _aiService.filtrarAlimentosEnLote(rawProducts);

      // FIX: mounted check tras cada await
      if (!mounted) return;
      Navigator.of(context).pop(); // cierra loading

      if (foodProducts.isNotEmpty) {
        await _firestoreService.saveProducts(foodProducts);
        if (mounted) _snack('${foodProducts.length} alimentos guardados', _kTeal);
      } else {
        if (mounted) _snack('No se detectaron alimentos en el ticket', _kOrange);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _snack('Error al procesar: $e', Colors.red);
      }
      debugPrint('Error escaneo: $e');
    } finally {
      recognizer.close();
    }
  }

  void _showLoadingDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: _kTeal),
                const SizedBox(height: 18),
                Text(msg, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Text('Agregar Producto',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              // FIX: withOpacity → withValues(alpha:)
              tileColor: _kTeal.withValues(alpha: 0.07),
              leading: const CircleAvatar(
                backgroundColor: _kTeal,
                child: Icon(Icons.camera_alt, color: Colors.white),
              ),
              title: const Text('Escanear Ticket de Compra',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Agrega productos escaneando el ticket de tu compra'),
              onTap: () {
                Navigator.pop(context);
                _scanTicket();
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFF66BB6A).withValues(alpha: 0.08),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF66BB6A),
                child: Icon(Icons.edit_outlined, color: Colors.white),
              ),
              title: const Text('Agregar Manualmente',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Ingresa un producto a mano'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddProductScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Mi Cuenta'),
        content: const Text('¿Deseas cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(context);
              await AuthService().signOut();
              if (mounted) {
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text('Cerrar Sesión',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.eco_rounded, color: _kTeal, size: 30),
        ),
        title: const Text(
          'Mi Despensa',
          style: TextStyle(
              color: _kDark,
              fontWeight: FontWeight.bold,
              fontSize: 20),
        ),
        actions: [
          // Campanita con badge de alertas
          StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getInventoryStream(),
            builder: (context, snap) {
              final alertCount = (snap.data?.docs ?? [])
                  .map((d) => Product.fromMap(
                      d.data() as Map<String, dynamic>, d.id))
                  .where((p) => p.isLowStock)
                  .length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                        Icons.notifications_outlined,
                        color: _kDark),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AlertsScreen()),
                    ),
                  ),
                  if (alertCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                            color: _kOrange,
                            shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            '$alertCount',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: _kDark),
            onPressed: _showProfileDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getInventoryStream(),
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

          final filtered = _searchQuery.isEmpty
              ? allProducts
              : allProducts
                  .where((p) => p.name
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase()))
                  .toList();

          final lowStock =
              allProducts.where((p) => p.isLowStock).toList();

          return CustomScrollView(
            slivers: [
              // Buscador
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar',
                      hintStyle:
                          const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              // Por Agotarse
              if (lowStock.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Por Agotarse',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kDark),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 115,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12),
                      itemCount: lowStock.length,
                      itemBuilder: (_, i) =>
                          _LowStockCard(product: lowStock[i]),
                    ),
                  ),
                ),
              ],

              // Encabezado inventario
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Todo el Inventario',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _kDark),
                      ),
                      Text(
                        '${filtered.length} productos',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

              // Lista vacía
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 72,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          'Tu despensa está vacía',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Escanea un ticket o agrega\nproductos manualmente',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _InventoryItem(
                        product: filtered[i],
                        firestoreService: _firestoreService,
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        backgroundColor: _kTeal,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Tarjeta stock bajo ─────────────────────────────────────────
class _LowStockCard extends StatelessWidget {
  final Product product;
  const _LowStockCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final ratio =
        (product.quantity / product.minStock).clamp(0.0, 1.0);

    return Container(
      width: 150,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: _kOrange, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: Colors.grey.shade200,
                  color: _kOrange,
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Queda ${(ratio * 100).toInt()}%',
                style: const TextStyle(
                    color: _kOrange, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Fila de inventario ─────────────────────────────────────────
class _InventoryItem extends StatelessWidget {
  final Product product;
  final FirestoreService firestoreService;
  const _InventoryItem(
      {required this.product, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AddProductScreen(product: product)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _kTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_categoryIcon(product.category),
                    color: _kTeal, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.quantity.toInt()} ${product.unit}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _QtyBtn(
                    icon: Icons.remove,
                    onTap: () {
                      if (product.id != null &&
                          product.quantity > 0) {
                        firestoreService.updateQuantity(
                            product.id!, product.quantity - 1);
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  _QtyBtn(
                    icon: Icons.add,
                    onTap: () {
                      if (product.id != null) {
                        firestoreService.updateQuantity(
                            product.id!, product.quantity + 1);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Lácteos':       return Icons.egg_outlined;
      case 'Frutas y Verduras': return Icons.eco_outlined;
      case 'Carnes':        return Icons.set_meal_outlined;
      case 'Bebidas':       return Icons.local_drink_outlined;
      case 'Congelados':    return Icons.ac_unit_outlined;
      case 'Panadería':     return Icons.bakery_dining_outlined;
      default:              return Icons.shopping_basket_outlined;
    }
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _kTeal,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
