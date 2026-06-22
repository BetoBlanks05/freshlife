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

  // ══════════════════════════════════════════════════════════════
  // ESCANEO DE TICKET — flujo completo con revisión
  // ══════════════════════════════════════════════════════════════
  Future<void> _scanTicket() async {
    final picker = ImagePicker();
    final image  = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,   // mejor calidad → mejor OCR
    );
    if (image == null || !mounted) return;

    _showLoading('Leyendo ticket...');

    final inputImage = InputImage.fromFilePath(image.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognized = await recognizer.processImage(inputImage);
      final rawText = recognized.text;

      if (!mounted) return;
      _hideLoading();

      // ── Sin texto detectado ────────────────────────────────
      if (rawText.trim().isEmpty) {
        _showRawTextDialog('No se detectó texto.\n'
            'Asegúrate de que el ticket esté bien iluminado y enfocado.');
        return;
      }

      // ── Parsear productos ──────────────────────────────────
      final rawProducts = TicketParser.parseText(rawText);

      if (rawProducts.isEmpty) {
        _showRawTextDialog(
          'Se leyó el ticket pero no se encontraron productos.\n\n'
          'TEXTO DETECTADO:\n$rawText',
        );
        return;
      }

      // ── Clasificar con IA + caché ──────────────────────────
      _showLoading(
          'Clasificando ${rawProducts.length} productos con IA...');
      final foodProducts =
          await _aiService.filtrarAlimentosEnLote(rawProducts);
      if (!mounted) return;
      _hideLoading();

      // ── Mostrar diálogo de revisión ────────────────────────
      await _showReviewDialog(rawProducts, foodProducts);
    } catch (e) {
      if (mounted) {
        _hideLoading();
        _snack('Error al procesar el ticket: $e', Colors.red);
        debugPrint('Scan error: $e');
      }
    } finally {
      recognizer.close();
    }
  }

  // ── Diálogo de revisión con checkboxes ──────────────────────
  Future<void> _showReviewDialog(
      List<Product> rawProducts, List<Product> foodProducts) async {
    // Inicializa selección: marcados los que la IA dijo que son comida
    final selected = {
      for (var p in rawProducts) p: foodProducts.contains(p),
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (_, scroll) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Revisar Productos',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text('Desmarca lo que no quieras guardar',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${selected.values.where((v) => v).length} selec.',
                        style: const TextStyle(
                            color: _kTeal,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: rawProducts.map((p) {
                    final isFood = foodProducts.contains(p);
                    return CheckboxListTile(
                      value: selected[p],
                      onChanged: (v) =>
                          setModal(() => selected[p] = v ?? false),
                      activeColor: _kTeal,
                      title: Text(p.name,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: p.price > 0
                          ? Text('\$${p.price.toStringAsFixed(2)}',
                              style:
                                  const TextStyle(color: Colors.grey))
                          : null,
                      secondary: Icon(
                        isFood
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: isFood ? _kTeal : Colors.grey,
                        size: 20,
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final toSave = selected.entries
                              .where((e) => e.value)
                              .map((e) => e.key)
                              .toList();
                          Navigator.pop(ctx);
                          if (toSave.isNotEmpty) {
                            await _firestoreService
                                .saveProducts(toSave);
                            if (mounted) {
                              _snack(
                                  '✅ ${toSave.length} productos guardados',
                                  _kTeal);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Guardar Selección',
                            style: TextStyle(
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Muestra texto crudo si el parser falla ───────────────────
  void _showRawTextDialog(String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _kOrange),
            SizedBox(width: 8),
            Text('Problema con el ticket'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(content,
              style: const TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddProductScreen()));
            },
            child: const Text('Agregar manualmente',
                style: TextStyle(color: _kTeal)),
          ),
        ],
      ),
    );
  }

  void _showLoading(String msg) {
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
                const SizedBox(height: 16),
                Text(msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _hideLoading() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
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
            _OptionTile(
              color: _kTeal,
              icon: Icons.camera_alt,
              title: 'Escanear Ticket de Compra',
              subtitle: 'La IA filtra solo los alimentos (con caché)',
              onTap: () { Navigator.pop(context); _scanTicket(); },
            ),
            const SizedBox(height: 10),
            _OptionTile(
              color: const Color(0xFF66BB6A),
              icon: Icons.edit_outlined,
              title: 'Agregar Manualmente',
              subtitle: 'Ingresa un producto a mano',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => const AddProductScreen()));
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
        title: const Text('Mi Despensa',
            style: TextStyle(
                color: _kDark,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getInventoryStream(),
            builder: (context, snap) {
              final count = (snap.data?.docs ?? [])
                  .map((d) => Product.fromMap(
                      d.data() as Map<String, dynamic>, d.id))
                  .where((p) => p.isLowStock)
                  .length;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: _kDark),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const AlertsScreen())),
                  ),
                  if (count > 0)
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
                          child: Text('$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
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
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),

              if (lowStock.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text('Por Agotarse',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _kDark)),
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

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Todo el Inventario',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _kDark)),
                      Text('${filtered.length} productos',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ),

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
                        const Text('Tu despensa está vacía',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
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

              const SliverToBoxAdapter(
                  child: SizedBox(height: 80)),
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

class _OptionTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _OptionTile(
      {required this.color,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        tileColor: color.withValues(alpha: 0.07),
        leading: CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: Colors.white)),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12)),
        onTap: onTap,
      );
}

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
              offset: const Offset(0, 2)),
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
                child: Text(product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
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
                    minHeight: 7),
              ),
              const SizedBox(height: 5),
              Text('Queda ${(ratio * 100).toInt()}%',
                  style:
                      const TextStyle(color: _kOrange, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryItem extends StatelessWidget {
  final Product product;
  final FirestoreService firestoreService;
  const _InventoryItem(
      {required this.product, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(
              builder: (_) => AddProductScreen(product: product))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _kTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_catIcon(product.category),
                    color: _kTeal, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                        '${product.quantity.toInt()} ${product.unit}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Row(
                children: [
                  _QtyBtn(
                      icon: Icons.remove,
                      onTap: () {
                        if (product.id != null && product.quantity > 0) {
                          firestoreService.updateQuantity(
                              product.id!, product.quantity - 1);
                        }
                      }),
                  const SizedBox(width: 6),
                  _QtyBtn(
                      icon: Icons.add,
                      onTap: () {
                        if (product.id != null) {
                          firestoreService.updateQuantity(
                              product.id!, product.quantity + 1);
                        }
                      }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _catIcon(String c) {
    switch (c) {
      case 'Lácteos':           return Icons.egg_outlined;
      case 'Frutas y Verduras': return Icons.eco_outlined;
      case 'Carnes':            return Icons.set_meal_outlined;
      case 'Bebidas':           return Icons.local_drink_outlined;
      case 'Congelados':        return Icons.ac_unit_outlined;
      case 'Panadería':         return Icons.bakery_dining_outlined;
      default:                  return Icons.shopping_basket_outlined;
    }
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: _kTeal, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );
}
