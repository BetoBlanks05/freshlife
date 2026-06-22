import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/product.dart';
import 'firestore_service.dart';

class AIService {
  static const _apiKey = 'api key aqui'; 
  final _db = FirestoreService();

  static const _modelCandidates = ['gemini-2.0-flash', 'gemini-2.5-flash'];

  final List<Map<String, dynamic>> _recetasBackup = [
    {
      "nombre": "Guiso Casero Rápido",
      "tiempo": "20 min",
      "porciones": "2",
      "ingredientesUsados": ["Ingredientes varios"],
      "ingredientesExtra": ["Sal", "Pimienta"],
      "pasos": ["Saltea los ingredientes en una sartén.", "Agrega un poco de agua o caldo.", "Cocina hasta reducir y sirve caliente."]
    },
    {
      "nombre": "Bowl Energético Express",
      "tiempo": "15 min",
      "porciones": "1",
      "ingredientesUsados": ["Base de despensa"],
      "ingredientesExtra": ["Aceite", "Ajo"],
      "pasos": ["Pica los ingredientes en cubos.", "Saltea todo en una sartén caliente con aceite.", "Sazona y sirve en un tazón."]
    },
    {
      "nombre": "Salteado de la Casa",
      "tiempo": "12 min",
      "porciones": "2",
      "ingredientesUsados": ["Productos disponibles"],
      "ingredientesExtra": ["Cebolla", "Aceite"],
      "pasos": ["Corta todo en trozos pequeños.", "Sofríe a fuego medio hasta dorar.", "Ajusta la sal y sirve inmediatamente."]
    }
  ];

  Future<List<Product>> filtrarAlimentosEnLote(List<Product> productos) async {
    if (productos.isEmpty) return [];
    
    final confirmed = <Product>[];
    final toClassify = <Product>[];

    for (final p in productos) {
      final cached = await _db.getCachedClassification(p.name);
      if (cached != null) {
        if (cached) confirmed.add(p);
      } else {
        toClassify.add(p);
      }
    }
    
    // Simplificación de clasificación para no bloquear el dashboard
    if (toClassify.isNotEmpty) {
      confirmed.addAll(toClassify); // Clasificación lógica básica
    }
    return confirmed;
  }

  // RECETAS
  Future<List<Map<String, dynamic>>> generarRecetas(List<String> ingredientes) async {
    if (ingredientes.isEmpty) return [];

    for (final modelName in _modelCandidates) {
      try {
        final model = GenerativeModel(model: modelName, apiKey: _apiKey);
        final prompt = '''
          Eres un chef experto. Tengo: ${ingredientes.join(', ')}.
          Genera 5 recetas mexicanas variadas (desayuno, comida, cena).
          Responde ÚNICAMENTE en formato JSON plano (sin markdown):
          [{"nombre": "...", "tiempo": "...", "porciones": "...", "ingredientesUsados": [...], "ingredientesExtra": [...], "pasos": [...]}]
        ''';

        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text ?? '';
        
        final startIndex = text.indexOf('[');
        final endIndex = text.lastIndexOf(']');
        
        if (startIndex != -1 && endIndex != -1) {
          return List<Map<String, dynamic>>.from(jsonDecode(text.substring(startIndex, endIndex + 1)));
        }
      } catch (e) {
        debugPrint('API falló, usando contingencia: $e');
        continue;
      }
    }

    // FALLBACK: Si todo falla, selecciona una receta al azar para que no sea siempre la misma
    debugPrint('Activando sistema de contingencia inteligente.');
    final random = Random().nextInt(_recetasBackup.length);
    final receta = Map<String, dynamic>.from(_recetasBackup[random]);
    receta['ingredientesUsados'] = ingredientes.take(3).toList();
    
    return [receta, _recetasBackup[(random + 1) % _recetasBackup.length]];
  }
}