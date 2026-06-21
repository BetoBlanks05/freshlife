import '../models/product.dart';

class TicketParser {
  static List<Product> parseText(String rawText) {
    final lines = rawText.split('\n').map((l) => l.trim()).toList();

    final List<String> productNames = [];
    final List<double> prices = [];

    // Detecta precios con formato de moneda mexicana
    final priceRegex = RegExp(r'\$?\s?\d{1,3}(?:[.,]\d{3})*[.,]\d{2}');
    // Descarta líneas de encabezado/totales
    final noiseRegex = RegExp(
      r'DESPENSA|FRESCOS|ELECTRONICA|HOGAR|CANT|ARTICULO|SORIANA|WALMART|CHEDRAUI|SUBTOTAL|TOTAL|IVA|PAGO|CAMBIO|EFECTIVO|TARJETA|TICKET|FOLIO|CAJA|RFC|GRACIAS',
      caseSensitive: false,
    );

    for (var line in lines) {
      if (line.isEmpty) continue;

      // Extraer precio (ignora líneas de subtotal/total)
      if (priceRegex.hasMatch(line) &&
          !line.toUpperCase().contains('SUBTOTAL') &&
          !line.toUpperCase().contains('TOTAL') &&
          !line.toUpperCase().contains('IVA')) {
        final match = priceRegex.firstMatch(line);
        if (match != null) {
          String cleanPrice = match.group(0)!.replaceAll(RegExp(r'[^\d]'), '');
          if (cleanPrice.length > 2) {
            final intPart = cleanPrice.substring(0, cleanPrice.length - 2);
            final decPart = cleanPrice.substring(cleanPrice.length - 2);
            double? val = double.tryParse('$intPart.$decPart');
            if (val != null && val > 0) prices.add(val);
          }
        }
      }
      // Extraer nombre del producto
      else if (!noiseRegex.hasMatch(line) &&
          line.length > 3 &&
          !RegExp(r'^\d+$').hasMatch(line) &&
          !RegExp(r'^[\d\s.,$]+$').hasMatch(line)) {
        productNames.add(line);
      }
    }

    // Alinear listas (protección contra desfase)
    final count = productNames.length < prices.length
        ? productNames.length
        : prices.length;

    return [
      for (int i = 0; i < count; i++)
        Product(name: productNames[i], price: prices[i]),
    ];
  }
}
