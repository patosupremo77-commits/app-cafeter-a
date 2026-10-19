import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart'; // lo genera: flutterfire configure
import 'common.dart';
import 'client.dart';
import 'staff.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Cafetería Universitaria',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFFB4561B), useMaterial3: true),
        darkTheme: ThemeData(colorSchemeSeed: const Color(0xFFB4561B), brightness: Brightness.dark, useMaterial3: true),
        home: const Gate(),
      );
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  Future<bool>? _f;
  String? _uid;

  Future<bool> _cargar(User u) async {
    final s = await db.collection('staff').doc(u.uid).get();
    try {
      await FirebaseMessaging.instance.requestPermission();
      final t = await FirebaseMessaging.instance.getToken();
      await db.collection('users').doc(u.uid).set({'fcmToken': t, 'email': u.email}, SetOptions(merge: true));
    } catch (_) {}
    return s.exists;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) return const _Cargando();
          final u = s.data;
          if (u == null) {
            _uid = null;
            return const LoginPage();
          }
          if (_uid != u.uid) {
            _uid = u.uid;
            _f = _cargar(u);
          }
          return FutureBuilder<bool>(
            future: _f,
            builder: (c, d) {
              if (!d.hasData) return const _Cargando();
              return d.data! ? const StaffHome() : const ClientHome();
            },
          );
        },
      );
}

class _Cargando extends StatelessWidget {
  const _Cargando();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final nombre = TextEditingController(), correo = TextEditingController(), clave = TextEditingController();
  bool registro = false, ocupado = false;

  Future<void> _enviar() async {
    setState(() => ocupado = true);
    try {
      final a = FirebaseAuth.instance;
      if (registro) {
        if (nombre.text.trim().isEmpty) throw 'Escribe tu nombre.';
        final cr = await a.createUserWithEmailAndPassword(email: correo.text.trim(), password: clave.text);
        await cr.user!.updateDisplayName(nombre.text.trim());
      } else {
        await a.signInWithEmailAndPassword(email: correo.text.trim(), password: clave.text);
      }
    } catch (e) {
      if (mounted) snack(context, e is FirebaseAuthException ? (e.message ?? 'Error de acceso') : '$e');
    }
    if (mounted) setState(() => ocupado = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(children: [
                  const Text('☕ Cafetería Universitaria', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  if (registro) TextField(controller: nombre, decoration: const InputDecoration(labelText: 'Nombre')),
                  TextField(controller: correo, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Correo')),
                  TextField(controller: clave, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: ocupado ? null : _enviar, child: Text(registro ? 'Crear cuenta' : 'Entrar')),
                  TextButton(onPressed: () => setState(() => registro = !registro), child: Text(registro ? 'Ya tengo cuenta' : 'Crear cuenta nueva')),
                ]),
              ),
            ),
          ),
        ),
      );
}
