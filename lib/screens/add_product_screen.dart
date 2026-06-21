import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/firestore_service.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;
  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _firestoreService = FirestoreService();

  String _category = 'Abarrotes';
  double _quantity = 1;
  double _minStock = 1;
  DateTime? _expiryDate;
  bool _isLoading = false;

  static const _primaryColor = Color(0xFF4DB6AC);
  static const _dark = Color(0xFF263238);

  static const _categories = [
    'Abarrotes',
    'Lácteos',
    'Frutas y Verduras',
    'Carnes',
    'Bebidas',
    'Congelados',
    'Panadería',
    'Otros',
  ];

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.product!;
      _nameController.text = p.name;
      _category =
          _categories.contains(p.category) ? p.category : 'Abarrotes';
      _quantity = p.quantity;
      _minStock = p.minStock;
      _expiryDate = p.expiryDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _snack('El nombre del producto es requerido');
      return;
    }
    setState(() => _isLoading = true);

    final product = Product(
      id: widget.product?.id,
      name: name,
      price: widget.product?.price ?? 0,
      category: _category,
      quantity: _quantity,
      minStock: _minStock,
      expiryDate: _expiryDate,
    );

    try {
      if (_isEditing) {
        await _firestoreService.updateProduct(product);
      } else {
        await _firestoreService.saveProducts([product]);
      }
      // FIX: mounted check antes de usar context tras await
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _snack('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    // guardamos el navigator antes del await
    final nav = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar producto'),
        content:
            Text('¿Eliminar "${widget.product!.name}" del inventario?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && widget.product?.id != null) {
      await _firestoreService.deleteProduct(widget.product!.id!);
      // FIX: usamos nav guardado (no context tras async gap)
      if (mounted) nav.pop();
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate:
          _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: _primaryColor),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) setState(() => _expiryDate = date);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _dec(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: _dark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Editar Producto' : 'Nuevo Producto',
          style: const TextStyle(
              color: _dark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Eliminar',
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Área de foto
            GestureDetector(
              onTap: () {},
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 38, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('Subir foto o',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 13)),
                    Text('Escanear código de barras',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _Label('Nombre del Producto'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: _dec('Ej: Arroz'),
            ),
            const SizedBox(height: 20),

            _Label('Categoría'),
            const SizedBox(height: 8),
            // FIX: reemplaza DropdownButtonFormField (value deprecado en FormField)
            // por DropdownButton en Container estilizado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                onChanged: (v) =>
                    setState(() => _category = v ?? _category),
                items: _categories
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c,
                            style:
                                const TextStyle(color: _dark))))
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),

            _Label('Cantidad Actual'),
            const SizedBox(height: 10),
            _Counter(
                value: _quantity,
                onChanged: (v) => setState(() => _quantity = v)),
            const SizedBox(height: 20),

            _Label('Stock Mínimo'),
            const SizedBox(height: 10),
            _Counter(
                value: _minStock,
                onChanged: (v) => setState(() => _minStock = v)),
            const SizedBox(height: 20),

            _Label('Fecha de Caducidad'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: Colors.grey),
                    const SizedBox(width: 10),
                    Text(
                      _expiryDate == null
                          ? 'Opcional'
                          : '${_expiryDate!.day.toString().padLeft(2, '0')}/'
                              '${_expiryDate!.month.toString().padLeft(2, '0')}/'
                              '${_expiryDate!.year}',
                      style: TextStyle(
                          color: _expiryDate == null
                              ? Colors.grey
                              : _dark,
                          fontSize: 14),
                    ),
                    if (_expiryDate != null) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _expiryDate = null),
                        child: const Icon(Icons.clear,
                            size: 18, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        _isEditing
                            ? 'Actualizar en Despensa'
                            : 'Guardar en Despensa',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Color(0xFF263238)),
      );
}

class _Counter extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _Counter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Btn(
            icon: Icons.remove,
            onTap: () {
              if (value > 0) onChanged(value - 1);
            }),
        const SizedBox(width: 12),
        Container(
          width: 64,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade50,
          ),
          child: Text(
            value.toInt().toString(),
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        _Btn(icon: Icons.add, onTap: () => onChanged(value + 1)),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF4DB6AC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
