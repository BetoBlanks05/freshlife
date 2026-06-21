import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/product.dart';

class AIService {
  final _model = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: 'Aqui va la api ley de gemini',
  );

  /// Verifica si UN producto es alimento (usado como fallback individual)
  Future<bool> esComida(String nombreProducto) async {
    final prompt =
        'Responde solo "true" o "false" (sin comillas ni espacios): '
        '¿"$nombreProducto" es un alimento o ingrediente comestible?';
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim().toLowerCase() ?? 'false';
      return text.startsWith('true');
    } catch (e) {
      debugPrint('AIService.esComida error: $e');
      return false;
    }
  }

  /// Filtra una lista entera en UNA sola llamada
  Future<List<Product>> filtrarAlimentosEnLote(List<Product> productos) async {
    if (productos.isEmpty) return [];

    final nombres = productos.map((p) => p.name).toList();
    final prompt = '''
Analiza esta lista de productos y determina cuáles son alimentos o ingredientes comestibles.
Lista: ${jsonEncode(nombres)}

Devuelve ÚNICAMENTE un arreglo JSON de booleanos (true=alimento, false=no alimento), en el mismo orden.
Ejemplo de salida: [true, false, true]
No incluyas explicaciones, solo el arreglo JSON.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      String text = response.text?.trim() ?? '[]';

      text = text.replaceAll(RegExp(r'```(?:json)?\s*|\s*```'), '').trim();

      final List<dynamic> bools = jsonDecode(text);
      return [
        for (int i = 0; i < bools.length && i < productos.length; i++)
          if (bools[i] == true) productos[i],
      ];
    } catch (e) {
      debugPrint('AIService.filtrarAlimentosEnLote error: $e');
      return [];
    }
  }
}
