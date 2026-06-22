import 'package:flutter/foundation.dart';
import '../models/product.dart';

/// Parser para tickets de supermercados mexicanos.
///
/// Estrategia en 3 intentos:
///  A) Misma línea: "LECHE LALA 1L  22.90"  (Soriana, Walmart, Chedraui)
///  B) Líneas alternas: nombre / precio separados
///  C) Raw: devuelve todo lo que parezca nombre para que la IA decida
class TicketParser {
  // Ruido — líneas a ignorar completamente
  static final _noiseRe = RegExp(
    r'DESPENSA|FRESCOS|ELECTR[OÓ]NICA|HOGAR|SORIANA|WALMART|CHEDRAUI|'
    r'OXXO|BODEGA|AURRERA|LA COMER|COMERCIAL|MEXICANA|SUPER|TIENDA|'
    r'SUBTOTAL|TOTAL|IVA|PAGO|CAMBIO|EFECTIVO|TARJETA|VISA|MASTER|'
    r'TICKET|FOLIO|CAJA|RFC|GRACIAS|FACTURA|CAJERO|VENDEDOR|'
    r'FECHA|HORA|CANT\b|DESCRIPCI[OÓ]N|PRECIO|IMPORTE|'
    r'ARTICULOS|ART[IÍ]CULOS|BIENVENIDO|V[IÍ]SITENOS|'
    r'AHORRO|DESCUENTO|CUPON|PUNTOS|BONIFICACI|AHORRA|PRECIO NORMAL|'
    r'^\*{3,}|^-{3,}|^={3,}',
    caseSensitive: false,
  );

  // Precio al final de línea — PERMISIVO:
  // Acepta "22.90", "22,90", "$22.90", "22.90 A", "22.90*"
  // No requiere espacio antes del número (OCR puede pegarlo)
  static final _priceEndRe =
      RegExp(r'(\d{1,5}[.,]\d{2})\s*[A-Za-z*%]?\s*$');

  // Precio standalone en toda la línea
  static final _priceOnlyRe = RegExp(
      r'^\$?\s*\d{1,5}[.,]\d{2}\s*$');

  // Línea de solo números / símbolos (sin letras → no es producto)
  static final _noLetterRe =
      RegExp(r'^[^A-Za-záéíóúñÁÉÍÓÚÑ]+$');

  // Prefijo de cantidad al inicio: "1 ", "2 "
  static final _qtyPrefixRe = RegExp(r'^\d{1,2}\s+');

  // Clave interna de artículo: 4-8 dígitos al inicio seguidos de espacio
  static final _skuPrefixRe = RegExp(r'^\d{4,8}\s+');

  // ─────────────────────────────────────────────────────────────
  static List<Product> parseText(String rawText) {
    debugPrint('\n════ TICKET RAW OCR ════════════════════');
    debugPrint(rawText);
    debugPrint('════════════════════════════════════════\n');

    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Intento A: nombre + precio en misma línea
    final a = _parseFormatA(lines);
    if (a.isNotEmpty) {
      debugPrint('Parser → Formato A: ${a.length} productos\n');
      return a;
    }

    // Intento B: líneas alternas
    final b = _parseFormatB(lines);
    if (b.isNotEmpty) {
      debugPrint('Parser → Formato B: ${b.length} productos\n');
      return b;
    }

    // Intento C: raw — devuelve solo nombres, precio 0
    // Permite que la IA clasifique aunque no haya precios claros
    final c = _parseRawNames(lines);
    debugPrint('Parser → Formato C (raw names): ${c.length} productos\n');
    return c;
  }

  // ── FORMATO A: precio al final de la misma línea ─────────────
  static List<Product> _parseFormatA(List<String> lines) {
    final products = <Product>[];

    for (final line in lines) {
      if (_noiseRe.hasMatch(line)) continue;
      if (_noLetterRe.hasMatch(line)) continue;

      final match = _priceEndRe.firstMatch(line);
      if (match == null) continue;

      final rawPrice = match.group(1)!.replaceAll(',', '.');
      final price = double.tryParse(rawPrice);
      if (price == null || price <= 0 || price >= 10000) continue;

      // Nombre = todo antes del precio
      String name = line.substring(0, match.start).trim();
      name = name.replaceFirst(_qtyPrefixRe, '').trim();
      name = name.replaceFirst(_skuPrefixRe, '').trim();

      if (_validName(name)) {
        products.add(Product(name: name, price: price));
        debugPrint('  [A] "${name}" → \$$price');
      }
    }

    return products;
  }

  // ── FORMATO B: nombres y precios en líneas alternas ──────────
  static List<Product> _parseFormatB(List<String> lines) {
    final names  = <String>[];
    final prices = <double>[];

    for (final line in lines) {
      if (_noiseRe.hasMatch(line)) continue;

      // Línea solo precio
      if (_priceOnlyRe.hasMatch(line) ||
          _noLetterRe.hasMatch(line)) {
        final m = _priceEndRe.firstMatch(line);
        if (m != null) {
          final val =
              double.tryParse(m.group(1)!.replaceAll(',', '.'));
          if (val != null && val > 0 && val < 10000) {
            prices.add(val);
          }
        }
        continue;
      }

      // Línea con precio al final (puede estar mezclada)
      final endMatch = _priceEndRe.firstMatch(line);
      if (endMatch != null) {
        final val = double.tryParse(
            endMatch.group(1)!.replaceAll(',', '.'));
        if (val != null && val > 0 && val < 10000) {
          String name =
              line.substring(0, endMatch.start).trim();
          name = name.replaceFirst(_qtyPrefixRe, '').trim();
          name = name.replaceFirst(_skuPrefixRe, '').trim();
          if (_validName(name)) {
            names.add(name);
            prices.add(val);
            debugPrint('  [B mix] "${name}" → \$$val');
          }
        }
        continue;
      }

      // Posible nombre puro
      String clean = line.replaceFirst(_qtyPrefixRe, '').trim();
      clean = clean.replaceFirst(_skuPrefixRe, '').trim();
      if (_validName(clean)) {
        names.add(clean);
        debugPrint('  [B name] "${clean}"');
      }
    }

    final count = names.length < prices.length
        ? names.length
        : prices.length;
    return [
      for (int i = 0; i < count; i++)
        Product(name: names[i], price: prices[i]),
    ];
  }

  // ── FORMATO C: extrae solo nombres (precio = 0) ───────────────
  // Último recurso: si el ticket no tiene precios reconocibles,
  // devuelve todos los nombres posibles con precio 0 para que
  // la IA los clasifique y el usuario los revise.
  static List<Product> _parseRawNames(List<String> lines) {
    final names = <String>[];

    for (final line in lines) {
      if (_noiseRe.hasMatch(line)) continue;
      if (_noLetterRe.hasMatch(line)) continue;

      String clean = line.replaceFirst(_qtyPrefixRe, '').trim();
      clean = clean.replaceFirst(_skuPrefixRe, '').trim();
      // Quita números y símbolos al final para limpiar nombre
      clean = clean
          .replaceAll(RegExp(r'[\d.,\$*%]+\s*$'), '')
          .trim();

      if (_validName(clean) && !names.contains(clean)) {
        names.add(clean);
        debugPrint('  [C] "${clean}"');
      }
    }

    return names.map((n) => Product(name: n, price: 0)).toList();
  }

  // ── Validación de nombre ──────────────────────────────────────
  static bool _validName(String s) {
    if (s.length < 3 || s.length > 60) return false;
    if (_noiseRe.hasMatch(s)) return false;
    if (_noLetterRe.hasMatch(s)) return false;
    if (!RegExp(r'[A-Za-záéíóúñÁÉÍÓÚÑ]').hasMatch(s)) return false;
    // Evita líneas que sean solo números con letras sueltas (ej: "1 A B")
    final letterCount =
        RegExp(r'[A-Za-záéíóúñÁÉÍÓÚÑ]').allMatches(s).length;
    return letterCount >= 2;
  }
}
