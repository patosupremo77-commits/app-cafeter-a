class Producto {
  // Atributos tipados principales basados en el diagrama
  String idProducto;
  String nombre;
  double precio;
  bool disponible;

  // Constructor de la clase
  Producto({
    required this.idProducto,
    required this.nombre,
    required this.precio,
    required this.disponible,
  });

  // Método requerido: aplicarDescuento que resta el descuento al precio actual
  void aplicarDescuento(double porcentaje) {
    if (porcentaje > 0 && porcentaje <= 100) {
      double descuento = precio * (porcentaje / 100);
      precio -= descuento;
    }
  }

  // Método adicional del diagrama de clases
  void actualizarDisponibilidad(bool estado) {
    disponible = estado;
  }
}