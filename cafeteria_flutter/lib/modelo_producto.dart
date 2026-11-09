class Producto {
  // Atributos tipados
  String id;
  String nombre;
  double precio;
  int stock;

  // Constructor de la clase
  Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.stock,
  });

  // Método para reducir stock
  void reducirStock() {
    if (stock > 0) {
      stock--;
    }
  }

  // Método para obtener los detalles del producto
  String obtenerDetalles() {
    return 'Producto: $nombre - Precio: \$$precio - Stock: $stock';
  }

  // Método solicitado para aplicar descuento
  void aplicarDescuento(double porcentaje) {
    if (porcentaje > 0 && porcentaje <= 100) {
      precio -= precio * (porcentaje / 100);
    }
  }
}