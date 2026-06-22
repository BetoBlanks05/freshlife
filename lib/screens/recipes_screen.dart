import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';

const _kTeal   = Color(0xFF4DB6AC);
const _kDark   = Color(0xFF263238);
const _kOrange = Color(0xFFFF9800);

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _aiService        = AIService();
  final _firestoreService = FirestoreService();

  List<Map<String, dynamic>> _recipes  = [];
  bool _loading   = false;
  bool _generated = false;
  String _error   = '';

  Future<void> _generateRecipes() async {
    setState(() { _loading = true; _error = ''; });

    try {
      // Obtiene inventario actual
      final snap = await _firestoreService
          .getInventoryStream()
          .first;

      final ingredients = snap.docs
          .map((d) => Product.fromMap(
              d.data() as Map<String, dynamic>, d.id))
          .map((p) => p.name)
          .toList();

      if (ingredients.isEmpty) {
        setState(() {
          _error = 'Tu despensa está vacía.\nAgrega productos primero.';
          _loading = false;
        });
        return;
      }

      final result =
          await _aiService.generarRecetas(ingredients);

      if (!mounted) return;

      setState(() {
        _recipes   = result;
        _generated = true;
        _loading   = false;
        if (result.isEmpty) {
          _error = 'No se pudieron generar recetas.\nIntenta de nuevo.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = 'Error: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Recetas',
            style: TextStyle(
                color: _kDark,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        actions: [
          if (_generated)
            IconButton(
              icon: const Icon(Icons.refresh, color: _kTeal),
              tooltip: 'Regenerar',
              onPressed: _loading ? null : _generateRecipes,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _kTeal),
                  SizedBox(height: 20),
                  Text(
                    'Analizando tu despensa\ny buscando recetas...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView( // --- AQUÍ ESTÁ EL CAMBIO ---
              child: !_generated
                  ? _buildWelcome()
                  : _error.isNotEmpty
                      ? _buildError()
                      : _buildRecipeList(),
            ),
    );
  }

  // ── Pantalla inicial ──────────────────────────────────────────
  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _kTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu_book_outlined,
                  size: 52, color: _kTeal),
            ),
            const SizedBox(height: 24),
            const Text(
              'Recetas con tu Despensa',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _kDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Se analizarán los ingredientes que tienes\n'
              'y sugerirá 3 recetas.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Vista previa de ingredientes disponibles
            StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getInventoryStream(),
              builder: (context, snap) {
                final products = (snap.data?.docs ?? [])
                    .map((d) => Product.fromMap(
                        d.data() as Map<String, dynamic>, d.id))
                    .toList();

                if (products.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kOrange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _kOrange.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: _kOrange, size: 18),
                        SizedBox(width: 8),
                        Text('No hay ingredientes en tu despensa',
                            style: TextStyle(color: _kOrange)),
                      ],
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kTeal.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _kTeal.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${products.length} ingredientes disponibles',
                        style: const TextStyle(
                            color: _kTeal,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: products.take(10).map((p) =>
                          Chip(
                            label: Text(p.name,
                                style: const TextStyle(
                                    fontSize: 11)),
                            backgroundColor:
                                Colors.white,
                            padding: EdgeInsets.zero,
                            visualDensity:
                                VisualDensity.compact,
                          ),
                        ).toList(),
                      ),
                      if (products.length > 10)
                        Text(
                            '+ ${products.length - 10} más',
                            style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _generateRecipes,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generar Recetas',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lista de recetas ──────────────────────────────────────────
  Widget _buildRecipeList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: _kTeal, size: 18),
            const SizedBox(width: 6),
            const Text('Sugerencias para hoy',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kDark)),
            const Spacer(),
            TextButton(
              onPressed: _generateRecipes,
              child: const Text('Regenerar',
                  style: TextStyle(color: _kTeal, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._recipes.map((r) => _RecipeCard(recipe: r)).toList(),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _generateRecipes,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Intentar de nuevo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de receta expandible ─────────────────────────────
class _RecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  const _RecipeCard({required this.recipe});

  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final nombre      = r['nombre']           ?? 'Receta';
    final tiempo      = r['tiempo']           ?? '';
    final porciones   = r['porciones']        ?? '';
    final usados      = List<String>.from(r['ingredientesUsados']  ?? []);
    final extra       = List<String>.from(r['ingredientesExtra']   ?? []);
    final pasos       = List<String>.from(r['pasos']               ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Cabecera
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _kTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.restaurant_menu,
                        color: _kTeal, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _kDark)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (tiempo.isNotEmpty) ...[
                              const Icon(Icons.access_time,
                                  size: 12,
                                  color: Colors.grey),
                              const SizedBox(width: 3),
                              Text(tiempo,
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12)),
                              const SizedBox(width: 10),
                            ],
                            if (porciones.isNotEmpty) ...[
                              const Icon(Icons.people_outline,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 3),
                              Text('$porciones porciones',
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // Detalle expandido
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ingredientes que tienes
                  if (usados.isNotEmpty) ...[
                    const Text('Ingredientes en tu despensa',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _kTeal,
                            fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: usados.map((i) => Chip(
                            label: Text(i,
                                style:
                                    const TextStyle(fontSize: 11)),
                            backgroundColor:
                                _kTeal.withValues(alpha: 0.1),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                          )).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Ingredientes extra que necesitas
                  if (extra.isNotEmpty) ...[
                    const Text('🛒 También necesitas',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _kOrange,
                            fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: extra.map((i) => Chip(
                            label: Text(i,
                                style:
                                    const TextStyle(fontSize: 11)),
                            backgroundColor:
                                _kOrange.withValues(alpha: 0.08),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                          )).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Pasos
                  if (pasos.isNotEmpty) ...[
                    const Text('Preparación',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _kDark,
                            fontSize: 13)),
                    const SizedBox(height: 8),
                    ...pasos.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                  color: _kTeal,
                                  shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  '${e.key + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(e.value,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: _kDark)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
