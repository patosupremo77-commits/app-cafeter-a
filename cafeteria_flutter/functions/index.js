const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

// Al crear un pedido: valida productos, toma los precios reales del menú,
// descuenta existencias de Tienda. Si no alcanza, cancela el pedido con motivo.
exports.alCrearPedido = onDocumentCreated('orders/{id}', async (event) => {
  const ref = event.data.ref;
  const o = event.data.data();
  try {
    let result;
    await db.runTransaction(async (t) => {
      const snaps = await Promise.all(o.items.map((i) => t.get(db.doc('menu/' + i.id))));
      const items = [];
      let total = 0;
      snaps.forEach((s, k) => {
        const it = o.items[k];
        const qty = Math.max(1, Math.floor(Number(it.qty) || 1));
        if (!s.exists || s.data().available === false) throw new Error('No disponible: ' + it.name);
        const p = s.data();
        if (p.type === 'tienda' && (p.stock || 0) < qty) throw new Error('Sin existencias: ' + p.name);
        items.push({ id: s.id, name: p.name, price: p.price, qty, type: p.type });
        total += p.price * qty;
      });
      snaps.forEach((s, k) => {
        if (items[k].type === 'tienda') t.update(s.ref, { stock: s.data().stock - items[k].qty });
      });
      result = { items, total, stockDescontado: true };
    });
    await ref.update(result);
  } catch (err) {
    await ref.update({ status: 'cancelado', motivo: String(err.message || err) });
  }
});

// Al cambiar el estado: devuelve existencias si se cancela y avisa al cliente.
exports.alCambiarEstado = onDocumentUpdated('orders/{id}', async (event) => {
  const a = event.data.before.data();
  const b = event.data.after.data();
  if (a.status === b.status) return;

  if (b.status === 'cancelado' && b.stockDescontado) {
    const batch = db.batch();
    b.items.filter((i) => i.type === 'tienda').forEach((i) =>
      batch.update(db.doc('menu/' + i.id), { stock: admin.firestore.FieldValue.increment(i.qty) }));
    await batch.commit();
  }

  const textos = {
    preparando: ['Tu pedido se está preparando', 'La cocina ya lo está haciendo.'],
    listo: ['¡Tu pedido está listo!', 'Pasa a recogerlo a la cafetería.'],
    cancelado: ['Pedido cancelado', b.motivo || 'Tu pedido fue cancelado.'],
  };
  const msg = textos[b.status];
  if (!msg) return;
  const u = await db.doc('users/' + b.uid).get();
  const token = u.exists && u.data().fcmToken;
  if (token) {
    await admin.messaging().send({ token, notification: { title: msg[0], body: msg[1] } }).catch(() => {});
  }
});
