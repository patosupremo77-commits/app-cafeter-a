import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'common.dart';

class StaffHome extends StatefulWidget {
  const StaffHome({super.key});
  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  int i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('☕ Panel de cafetería'), actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ]),
        body: Column(children: [
          const HorarioBanner(),
          Expanded(child: [const KitchenPage(), const MenuAdminPage(), const HoursPage()][i]),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.soup_kitchen), label: 'Pedidos'),
            NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Menú'),
            NavigationDestination(icon: Icon(Icons.schedule), label: 'Horario'),
          ],
        ),
      );
}

class KitchenPage extends StatelessWidget {
  const KitchenPage({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
        stream: db.collection('orders').orderBy('createdAt', descending: true).limit(60).snapshots(),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final act = s.data!.docs.where((d) => ['recibido', 'preparando', 'listo'].contains(d['status'])).toList();
          if (act.isEmpty) return const Center(child: Text('Sin pedidos activos.'));
          return ListView(padding: const EdgeInsets.all(10), children: act.map((d) {
            final o = d.data() as Map<String, dynamic>;
            final st = o['status'] as String;
            final nx = flujo[flujo.indexOf(st) + 1];
            final etiqueta = {'preparando': 'Aceptar y preparar', 'listo': 'Marcar listo', 'entregado': 'Entregado'}[nx]!;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('#${d.id.substring(d.id.length - 4).toUpperCase()} · ${o['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text((o['items'] as List).map((x) => '${x['qty']}× ${x['name']}${x['type'] == 'tienda' ? ' 🛍️' : ''}').join('\n')),
                  Text('${money(o['total'] ?? 0)} · ${estados[st]}'),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    TextButton(onPressed: () => d.reference.update({'status': 'cancelado', 'motivo': 'Rechazado por la cafetería'}), child: const Text('Rechazar')),
                    FilledButton(onPressed: () => d.reference.update({'status': nx}), child: Text(etiqueta)),
                  ]),
                ]),
              ),
            );
          }).toList());
        },
      );
}

class MenuAdminPage extends StatelessWidget {
  const MenuAdminPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductForm())),
          icon: const Icon(Icons.add),
          label: const Text('Producto'),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: db.collection('menu').snapshots(),
          builder: (c, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            if (s.data!.docs.isEmpty) return const Center(child: Text('Menú vacío. Agrega el primer producto.'));
            return ListView(padding: const EdgeInsets.only(bottom: 80), children: s.data!.docs.map((d) {
              final p = d.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: foto(p['photoUrl']),
                  title: Text('${p['name']} · ${money(p['price'] ?? 0)}'),
                  subtitle: Text('${p['type'] == 'tienda' ? 'Tienda · existencias: ${p['stock'] ?? 0}' : 'Comida'} · ${p['available'] == false ? 'Oculto' : 'Visible'}'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductForm(id: d.id, data: p))),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: c,
                        builder: (x) => AlertDialog(title: const Text('¿Eliminar producto?'), actions: [
                          TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('No')),
                          TextButton(onPressed: () => Navigator.pop(x, true), child: const Text('Sí')),
                        ]),
                      );
                      if (ok == true) d.reference.delete();
                    },
                  ),
                ),
              );
            }).toList());
          },
        ),
      );
}

class ProductForm extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? data;
  const ProductForm({super.key, this.id, this.data});
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  late final n = TextEditingController(text: widget.data?['name'] ?? '');
  late final d = TextEditingController(text: widget.data?['description'] ?? '');
  late final p = TextEditingController(text: '${widget.data?['price'] ?? ''}');
  late final s = TextEditingController(text: '${widget.data?['stock'] ?? 0}');
  late String tipo = widget.data?['type'] ?? 'comida';
  late bool visible = widget.data?['available'] != false;
  String? fotoUrl;
  File? nuevaFoto;
  bool guardando = false;

  @override
  void initState() {
    super.initState();
    fotoUrl = widget.data?['photoUrl'];
  }

  Future<void> _elegir() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (x != null) setState(() => nuevaFoto = File(x.path));
  }

  Future<void> _guardar() async {
    if (n.text.trim().isEmpty) return snack(context, 'Falta el nombre.');
    setState(() => guardando = true);
    try {
      final ref = widget.id != null ? db.collection('menu').doc(widget.id) : db.collection('menu').doc();
      String? url = fotoUrl;
      if (nuevaFoto != null) {
        final sr = FirebaseStorage.instance.ref('menu_photos/${ref.id}.jpg');
        await sr.putFile(nuevaFoto!, SettableMetadata(contentType: 'image/jpeg'));
        url = await sr.getDownloadURL();
      }
      await ref.set({
        'name': n.text.trim(),
        'description': d.text.trim(),
        'price': double.tryParse(p.text) ?? 0,
        'type': tipo,
        'available': visible,
        'photoUrl': url, // la foto es opcional: puede ser null
        if (tipo == 'tienda') 'stock': int.tryParse(s.text) ?? 0,
      }, SetOptions(merge: true));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) snack(context, 'No se pudo guardar: $e');
      setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.id == null ? 'Nuevo producto' : 'Editar producto')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: nuevaFoto != null
                ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(nuevaFoto!, width: 140, height: 140, fit: BoxFit.cover))
                : foto(fotoUrl, size: 140),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton.icon(onPressed: _elegir, icon: const Icon(Icons.photo), label: const Text('Foto (opcional)')),
            if (nuevaFoto != null || (fotoUrl ?? '').isNotEmpty)
              TextButton(onPressed: () => setState(() { nuevaFoto = null; fotoUrl = null; }), child: const Text('Quitar')),
          ]),
          TextField(controller: n, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: d, decoration: const InputDecoration(labelText: 'Descripción')),
          TextField(controller: p, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio')),
          DropdownButtonFormField<String>(
            value: tipo,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(value: 'comida', child: Text('Comida (cocina)')),
              DropdownMenuItem(value: 'tienda', child: Text('Tienda (con existencias)')),
            ],
            onChanged: (v) => setState(() => tipo = v!),
          ),
          if (tipo == 'tienda') TextField(controller: s, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Existencias')),
          SwitchListTile(title: const Text('Visible para clientes'), value: visible, onChanged: (v) => setState(() => visible = v)),
          const SizedBox(height: 8),
          FilledButton(onPressed: guardando ? null : _guardar, child: Text(guardando ? 'Guardando…' : 'Guardar')),
        ]),
      );
}

class HoursPage extends StatefulWidget {
  const HoursPage({super.key});
  @override
  State<HoursPage> createState() => _HoursPageState();
}

class _HoursPageState extends State<HoursPage> {
  String open = '08:00', close = '17:00';
  bool cerrado = false, cargado = false;

  @override
  void initState() {
    super.initState();
    db.doc('settings/horario').get().then((s) {
      final c = s.data() ?? {};
      setState(() {
        open = c['open'] ?? open;
        close = c['close'] ?? close;
        cerrado = c['manualClosed'] == true;
        cargado = true;
      });
    });
  }

  Future<void> _hora(bool esApertura) async {
    final cur = (esApertura ? open : close).split(':');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(cur[0]), minute: int.parse(cur[1])));
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => esApertura ? open = v : close = v);
  }

  @override
  Widget build(BuildContext context) => !cargado
      ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(16), children: [
          ListTile(title: const Text('Abre'), trailing: Text(open), onTap: () => _hora(true)),
          ListTile(title: const Text('Cierra'), trailing: Text(close), onTap: () => _hora(false)),
          SwitchListTile(title: const Text('Cerrar pedidos por hoy'), value: cerrado, onChanged: (v) => setState(() => cerrado = v)),
          FilledButton(
            onPressed: () async {
              await db.doc('settings/horario').set({'open': open, 'close': close, 'manualClosed': cerrado});
              if (context.mounted) snack(context, 'Horario guardado.');
            },
            child: const Text('Guardar horario'),
          ),
        ]);
}
