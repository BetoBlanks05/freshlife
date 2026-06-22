import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/product.dart';
import 'firestore_service.dart';

class AIService {
  static const _apiKey = 'api key aqui';
  final _db = FirestoreService();

  static const _modelCandidates = [
    'gemini-2.0-flash',
    'gemini-2.5-flash',
    'gemini-2.5-flash-latest',
  ];

  // Palabras que SÍ son alimentos
  static const _foodWords = {
    'leche', 'arroz', 'aceite', 'azucar', 'sal', 'harina', 'frijol',
    'lenteja', 'garbanzo', 'pasta', 'espagueti', 'sopa', 'crema',
    'yogurt', 'yogur', 'queso', 'mantequilla', 'margarina', 'huevo',
    'pollo', 'carne', 'res', 'cerdo', 'jamon', 'salchicha', 'chorizo',
    'atun', 'sardina', 'tortilla', 'pan', 'bolillo', 'telera', 'bimbo',
    'galleta', 'cereal', 'avena', 'granola', 'mermelada', 'miel',
    'cajeta', 'chocolate', 'cafe', 'jugo', 'refresco', 'agua purificada',
    'tomate', 'jitomate', 'cebolla', 'ajo', 'papa', 'zanahoria',
    'limon', 'naranja', 'manzana', 'platano', 'mango', 'aguacate',
    'chile', 'salsa', 'vinagre', 'mostaza', 'catsup', 'ketchup',
    'mayonesa', 'aderezo', 'consome', 'caldo', 'atole', 'elote',
    'maiz', 'trigo', 'soya', 'lala', 'alpura', 'nutrileche', 'boing',
    'jumex', 'sabritas', 'barcel', 'marinela', 'maseca', 'minsa',
    'knorr', 'maggi', 'nescafe', 'lipton', 'quaker', 'kellogs',
    'kellogg', 'nestle', 'herdez', 'clemente', 'la costena', 'costena',
  };

  static const _nonFoodWords = {
    'pila', 'bateria', 'desodorante', 'shampoo', 'champu', 'jabon',
    'detergente', 'cloro', 'suavitel', 'ariel', 'ace', 'fabuloso',
    'pinol', 'escoba', 'trapeador', 'panal', 'kleenex', 'foco',
    'cable', 'usb', 'cargador', 'audifono', 'sarten', 'aluminio',
    'encendedor', 'cerillos', 'navaja', 'rastrillo', 'colgate',
    'oral-b', 'pantene', 'head', 'axe', 'gillette', 'schick',
    'scott', 'sanit', 'toilet', 'bano', 'limpia',
  };

  // FILTRAR EN LOTE — con caché Firestore
  Future<List<Product>> filtrarAlimentosEnLote(
      List<Product> productos) async {
    if (productos.isEmpty) return [];

    final confirmed = <Product>[];     // ya son comida
    final toClassify = <Product>[];    // necesitan consultarse

    // Revisar caché primero
    for (final p in productos) {
      final cached = await _db.getCachedClassification(p.name);
      if (cached != null) {
        debugPrint('Cache hit → "${p.name}": ${cached ? "alimento" : "no alimento"}');
        if (cached) confirmed.add(p);
      } else {
        toClassify.add(p);
      }
    }

    if (toClassify.isEmpty) {
      debugPrint('AIService: 100% cache hit. Sin llamadas a la API.');
      return confirmed;
    }

    debugPrint('AIService: ${confirmed.length} desde caché, '
        '${toClassify.length} necesitan IA.');

    // Llamar a la IA para los no cacheados
    List<Product> aiResult = [];
    bool aiWorked = false;

    for (final modelName in _modelCandidates) {
      try {
        final result = await _callGemini(modelName, toClassify);
        if (result != null) {
          aiResult = result;
          aiWorked = true;
          debugPrint('AIService: $modelName funcionó → '
              '${aiResult.length}/${toClassify.length} son alimentos');
          break;
        }
      } catch (e) {
        debugPrint('AIService: $modelName falló → $e');
        continue;
      }
    }

    if (!aiWorked) {
      debugPrint('AIService: Todos los modelos fallaron, usando fallback local.');
      aiResult = toClassify.where((p) => _isFood(p.name)).toList();
    }

    // Guardar resultados en caché para futuras consultas
    for (final p in toClassify) {
      final isFood = aiResult.any((r) => r.name == p.name);
      await _db.saveCachedClassification(p.name, isFood);
    }

    confirmed.addAll(aiResult);
    return confirmed;
  }

  //  Llamada de Gemini para clasificar en lote
  Future<List<Product>?> _callGemini(
      String modelName, List<Product> productos) async {
    final model = GenerativeModel(model: modelName, apiKey: _apiKey);
    final nombres = productos.map((p) => p.name).toList();

    final prompt = '''
Eres un clasificador de productos de supermercado mexicano.
Analiza esta lista y determina si cada producto es un alimento o ingrediente comestible.

Lista: ${jsonEncode(nombres)}

Reglas:
- true = alimento, bebida, ingrediente o condimento comestible
- false = artículo de limpieza, higiene, electrónico, utensilio u otro no comestible

Responde SOLO con un arreglo JSON de booleanos en el mismo orden, sin explicaciones.
Ejemplo: [true, false, true, true]
''';

    final response =
        await model.generateContent([Content.text(prompt)]);
    String text = response.text?.trim() ?? '[]';
    text =
        text.replaceAll(RegExp(r'```(?:json)?\s*|\s*```'), '').trim();

    final List<dynamic> bools = jsonDecode(text);
    return [
      for (int i = 0; i < bools.length && i < productos.length; i++)
        if (bools[i] == true) productos[i],
    ];
  }

  // RECETAS con los ingredientes disponibles

  Future<List<Map<String, dynamic>>> generarRecetas(
      List<String> ingredientes) async {
    if (ingredientes.isEmpty) return [];

    for (final modelName in _modelCandidates) {
      try {
        final model =
            GenerativeModel(model: modelName, apiKey: _apiKey);
        final prompt = '''
Soy dueño de una despensa con estos ingredientes disponibles:
${ingredientes.join(', ')}

Sugiere exactamente 3 recetas mexicanas caseras que pueda preparar (totales o parcialmente) con estos ingredientes.

Responde ÚNICAMENTE con un JSON válido con esta estructura exacta (sin markdown):
[
  {
    "nombre": "Nombre de la receta",
    "tiempo": "30 min",
    "porciones": "4",
    "ingredientesUsados": ["ingrediente1", "ingrediente2"],
    "ingredientesExtra": ["ingrediente opcional 1"],
    "pasos": ["Paso 1...", "Paso 2...", "Paso 3..."]
  }
]
''';

        final response =
            await model.generateContent([Content.text(prompt)]);
        String text = response.text?.trim() ?? '[]';
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();

        final List<dynamic> json = jsonDecode(text);
        return json.cast<Map<String, dynamic>>();
      } catch (e) {
        debugPrint('AIService: Fallo crítico de API. Activando Fallback local de recetas.');
        continue;
      }
    }
    return [
      {
        "nombre": "Guiso Casero (Sugerencia de contingencia)",
        "tiempo": "25 min",
        "porciones": "2",
        "ingredientesUsados": ingredientes.take(3).toList(),
        "ingredientesExtra": ["sal", "pimienta", "aceite"],
        "pasos": [
          "Prepara los ingredientes disponibles: ${ingredientes.take(3).join(', ')}.",
          "Calienta una sartén con un poco de aceite a fuego medio.",
          "Cocina los ingredientes principales hasta que estén dorados.",
          "Sazona al gusto con sal y pimienta. Sirve caliente."
        ]
      }
    ];
  }

  // Fallback local por palabras clave
  bool _isFood(String name) {
    final lower = _norm(name);
    for (final kw in _nonFoodWords) {
      if (lower.contains(kw)) return false;
    }
    for (final kw in _foodWords) {
      if (lower.contains(kw)) return true;
    }
    return true; // duda → incluye
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàä]'), 'a')
      .replaceAll(RegExp(r'[éèë]'), 'e')
      .replaceAll(RegExp(r'[íìï]'), 'i')
      .replaceAll(RegExp(r'[óòö]'), 'o')
      .replaceAll(RegExp(r'[úùü]'), 'u');

  Future<bool> esComida(String nombre) async {
    final cached = await _db.getCachedClassification(nombre);
    if (cached != null) return cached;

    for (final modelName in _modelCandidates) {
      try {
        final model =
            GenerativeModel(model: modelName, apiKey: _apiKey);
        final response = await model.generateContent([
          Content.text(
              'Solo responde "true" o "false": ¿"$nombre" es un alimento comestible?'),
        ]);
        final result =
            response.text?.trim().toLowerCase().startsWith('true') ??
                false;
        await _db.saveCachedClassification(nombre, result);
        return result;
      } catch (_) {
        continue;
      }
    }
    final local = _isFood(nombre);
    await _db.saveCachedClassification(nombre, local);
    return local;
  }
}
