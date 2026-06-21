import '../models/product.dart';

class TicketParser {
  static List<Product> parseText(String rawText) {
    List<Product> products = [];
    final lines = rawText.split('\n').map((l) => l.trim()).toList();

    List<String> productNames = [];
    List<double> prices = [];

    final priceRegex = RegExp(r'\$?\s?\d{1,3}(?:[.,]\d{3})*[.,]\d{2}');
    final noiseRegex = RegExp(r'DESPENSA|FRESCOS|ELECTRONICA|HOGAR|CANT|ARTICULO|SORIANA|SUBTOTAL|TOTAL|IVA|PAGO', caseSensitive: false);

    for (var line in lines) {
      if (line.isEmpty) continue;

      // Intentar extraer precio
      if (priceRegex.hasMatch(line) && !line.contains(RegExp(r'SUBTOTAL|TOTAL|IVA'))) {
        String cleanPrice = line.replaceAll(RegExp(r'[^\d.]'), '');
        double val = double.tryParse(cleanPrice) ?? 0.0;
        if (val > 0) prices.add(val);
      } 
      else if (!noiseRegex.hasMatch(line) && line.length > 3 && !RegExp(r'^\d+$').hasMatch(line)) {
        productNames.add(line);
      }
    }

    int count = productNames.length < prices.length ? productNames.length : prices.length;
    for (int i = 0; i < count; i++) {
      products.add(Product(name: productNames[i], price: prices[i]));
    }

    return products;
  }
}