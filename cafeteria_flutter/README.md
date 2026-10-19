# App de pedidos – Cafetería Universitaria (Flutter + Firebase)

## Qué usa
- Flutter (iPhone + Android con un solo código)
- Firebase Authentication (correo y contraseña)
- Cloud Firestore (menu, orders, settings, staff, users)
- Firebase Storage (fotos opcionales de productos)
- Cloud Functions (descuento automático de existencias, validación de precios, notificaciones)
- Firebase Cloud Messaging (notificaciones push)

## Puesta en marcha
1. Instala Flutter (flutter.dev) y Node.js 20. Instala la CLI: `npm i -g firebase-tools` y `dart pub global activate flutterfire_cli`.
2. Crea un proyecto en console.firebase.google.com. Activa:
   - Authentication → método "Correo/contraseña"
   - Firestore Database
   - Storage
   - Cambia el plan a Blaze (las Cloud Functions lo exigen; el uso pequeño suele costar casi nada).
3. En esta carpeta: `flutter create .` (genera android/ e ios/ sin tocar lib/), luego `flutterfire configure` (crea lib/firebase_options.dart).
4. `flutter pub get`
5. Publica reglas y funciones: `cd functions && npm install && cd ..` y luego `firebase deploy --only firestore:rules,storage,functions`
6. Da de alta al personal de cafetería: en la consola de Firestore crea el documento `staff/<UID del usuario>` (basta un campo cualquiera, por ejemplo `activo: true`). El UID aparece en Authentication → Usuarios. Todo usuario sin ese documento es cliente.
7. `flutter run` para probar. Para publicar: `flutter build apk` (Android) o `flutter build ipa` (iPhone, requiere Mac y cuenta de Apple Developer).
8. iPhone: para notificaciones activa Push Notifications y sube tu clave APNs en Firebase → Configuración del proyecto → Cloud Messaging.

## Pendientes recomendados
- La Cloud Function aún no valida el horario en el servidor (solo lo hace la app).
- Índices: si Firestore pide un índice, el error trae un enlace para crearlo con un clic.
- Las versiones de los paquetes en pubspec.yaml pueden requerir actualización.
