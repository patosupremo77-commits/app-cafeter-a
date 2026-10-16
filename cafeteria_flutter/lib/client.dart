import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'common.dart';

class ClientHome extends StatefulWidget {
  const ClientHome({super.key});
  @override
  State<ClientHome> createState() => _ClientHomeState();
}

class _ClientHomeState extends State<ClientHome> {
  int i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('☕ Cafetería'), actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ]),
        body: Column(children: [
          const HorarioBanner(),
          Expanded(child: [const MenuPage(), const CartPage(), const MyOrdersPage()][i]),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Menú'),
            NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Carrito'),
            NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Mis pedidos'),
          ],
        ),
      );
}

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  void _add(BuildContext c, Map<String, dynamic> p) {
    final n = (cart.value[p['id']] ?? 0) + 1;
    if (p['type'] == 'tienda' && n > (p['stock'] ?? 0)) return snack(c, 'No hay más existencias.');
    cart.value = {...cart.value, p['id']: n};
    snack(c, '${p['name']} agregado');
  }

  Widget _lista(BuildContext c, String tipo) {
    final items = menuCache.values.where((p) => p['type'] == tipo).toList();
    if (items.isEmpty) return const Center(child: Text('Aún no hay productos aquí.'));
    return ListView(
      children: items.map((p) {
        final agotado = tipo == 'tienda' && (p['stock'] ?? 0) <= 0;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: foto(p['photoUrl']),
            title: Text(p['name'] ?? ''),
            subtitle: Text([
              if ((p['description'] ?? '').toString().isNotEmpty) p['description'],
              if (tipo == 'tienda') (agotado ? 'Agotado' : 'Quedan ${p['stock']}'),
            ].join('\n')),
            isThreeLine: tipo == 'tienda' && (p['description'] ?? '').toString().isNotEmpty,
            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(money(p['price'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 28, child: TextButton(onPressed: agotado ? null : () => _add(c, p), child: const Text('Agregar'))),
            ]),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
        stream: db.collection('menu').where('available', isEqualTo: true).snapshots(),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          menuCache = {for (final d in s.data!.docs) d.id: {...(d.data() as Map<String, dynamic>), 'id': d.id}};
          return DefaultTabController(
            length: 2,
            child: Column(children: [
              const TabBar(tabs: [Tab(text: 'Comida'), Tab(text: 'Tienda')]),
              Expanded(child: TabBarView(children: [_lista(c, 'comida'), _lista(c, 'tienda')])),
            ]),
          );
        },
      );
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late final nombre = TextEditingController(text: FirebaseAuth.instance.currentUser?.displayName ?? '');
  bool enviando = false;

  Future<void> _pedir(List<Map<String, dynamic>> items) async {
    if (nombre.text.trim().isEmpty) return snack(context, 'Escribe un nombre para el pedido.');
    setState(() => enviando = true);
    try {
      final cfg = (await db.doc('settings/horario').get()).data() ?? {};
      if (!estaAbierto(cfg)) throw 'La cafetería está cerrada.';
      await db.collection('orders').add({
        'uid': FirebaseAuth.instance.currentUser!.uid,
        'name': nombre.text.trim(),
        'items': items,
        'total': items.fold<num>(0, (a, x) => a + x['price'] * x['qty']),
        'status': 'recibido',
        'source': 'app',
        'createdAt': FieldValue.serverTimestamp(),
      });
      cart.value = {};
      if (mounted) snack(context, 'Pedido enviado. Síguelo en "Mis pedidos".');
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
    if (mounted) setState(() => enviando = false);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Map<String, int>>(
        valueListenable: cart,
        builder: (c, m, _) {
          final items = <Map<String, dynamic>>[
            for (final e in m.entries)
              if (menuCache[e.key] != null)
                {'id': e.key, 'name': menuCache[e.key]!['name'], 'price': menuCache[e.key]!['price'], 'qty': e.value, 'type': menuCache[e.key]!['type']}
          ];
          if (items.isEmpty) return const Center(child: Text('Tu carrito está vacío.'));
          final total = items.fold<num>(0, (a, x) => a + x['price'] * x['qty']);
          return ListView(padding: const EdgeInsets.all(10), children: [
            for (final x in items)
              Card(
                child: ListTile(
                  title: Text(x['name']),
                  subtitle: Text(money(x['price'])),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.remove), onPressed: () {
                      final n = x['qty'] - 1;
                      final nm = {...m};
                      n <= 0 ? nm.remove(x['id']) : nm[x['id']] = n;
                      cart.value = nm;
                    }),
                    Text('${x['qty']}'),
                    IconButton(icon: const Icon(Icons.add), onPressed: () => cart.value = {...m, x['id']: x['qty'] + 1}),
                  ]),
                ),
              ),
            TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre para el pedido')),
            const SizedBox(height: 12),
            Text('Total: ${money(total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Pago al recoger en la cafetería.'),
            const SizedBox(height: 8),
            FilledButton(onPressed: enviando ? null : () => _pedir(items), child: const Text('Hacer pedido')),
          ]);
        },
      );
}

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
        stream: db.collection('orders').where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid).snapshots(),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final docs = s.data!.docs.toList()
            ..sort((a, b) {
              final x = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 1 << 50;
              final y = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 1 << 50;
              return y.compareTo(x);
            });
          if (docs.isEmpty) return const Center(child: Text('Todavía no has hecho pedidos.'));
          return ListView(padding: const EdgeInsets.all(10), children: docs.map((d) {
            final o = d.data() as Map<String, dynamic>;
            final st = o['status'] as String;
            final i = flujo.indexOf(st);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('#${d.id.substring(d.id.length - 4).toUpperCase()} · ${o['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text((o['items'] as List).map((x) => '${x['qty']}× ${x['name']}').join(', ')),
                  Text(money(o['total'] ?? 0)),
                  const SizedBox(height: 8),
                  if (st != 'cancelado') LinearProgressIndicator(value: (i + 1) / flujo.length),
                  const SizedBox(height: 6),
                  Text(estados[st] ?? st, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (o['motivo'] != null) Text('${o['motivo']}'),
                  if (st == 'recibido')
                    TextButton(onPressed: () => d.reference.update({'status': 'cancelado'}), child: const Text('Cancelar pedido')),
                ]),
              ),
            );
          }).toList());
        },
      );
}
