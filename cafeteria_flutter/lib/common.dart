import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final db = FirebaseFirestore.instance;

const estados = {
  'recibido': 'Recibido por la tienda',
  'preparando': 'Preparando',
  'listo': '¡Listo para recoger!',
  'entregado': 'Entregado',
  'cancelado': 'Cancelado',
};
const flujo = ['recibido', 'preparando', 'listo', 'entregado'];

final cart = ValueNotifier<Map<String, int>>({});
Map<String, Map<String, dynamic>> menuCache = {};

String money(num n) => '\$${n.toStringAsFixed(2)}';

int _min(String t) {
  final p = t.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

bool estaAbierto(Map<String, dynamic> c) {
  if (c['manualClosed'] == true) return false;
  final n = TimeOfDay.now();
  final m = n.hour * 60 + n.minute;
  return m >= _min(c['open'] ?? '08:00') && m < _min(c['close'] ?? '17:00');
}

void snack(BuildContext c, String t) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t)));

class HorarioBanner extends StatelessWidget {
  const HorarioBanner({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot>(
        stream: db.doc('settings/horario').snapshots(),
        builder: (c, s) {
          final cfg = (s.data?.data() as Map<String, dynamic>?) ?? {};
          final open = estaAbierto(cfg);
          final txt = open
              ? '🟢 Abierto · pedidos hasta las ${cfg['close'] ?? '17:00'}'
              : (cfg['manualClosed'] == true
                  ? '🔴 Cerrado por hoy'
                  : '🔴 Cerrado · pedidos de ${cfg['open'] ?? '08:00'} a ${cfg['close'] ?? '17:00'}');
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (open ? Colors.green : Colors.red).withOpacity(.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(txt, style: const TextStyle(fontWeight: FontWeight.w600)),
          );
        },
      );
}

Widget foto(String? url, {double size = 56}) => ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url == null || url.isEmpty
          ? Container(width: size, height: size, color: Colors.brown.withOpacity(.12), child: const Icon(Icons.restaurant))
          : Image.network(url, width: size, height: size, fit: BoxFit.cover),
    );
