# Hogar · app

Cliente Flutter de [Hogar](https://github.com/Sechuam/hogar), una API para parejas y compañeros de
piso: gastos comunes con reparto, saldos y "quién debe a quién", y tareas de casa. La app **no mueve
dinero**: solo registra y calcula.

| Pieza | Elección |
|---|---|
| Framework | Flutter 3.50 (Android, iOS y web) |
| Estado / DI | Riverpod 3, sin generación de código |
| Navegación | go_router, con redirección según la sesión |
| HTTP | Dio, con renovación de sesión compartida ante 401 |
| Dinero | `Decimal`; nunca `double`. Se envía a la API como texto (`"42.50"`) |
| Tests | `flutter_test`; widgets probados contra una API falsa (sin mocks de repositorios) |

## Qué hace

- Registro e inicio de sesión con email; la sesión se recupera al arrancar.
- Hogares: crear, unirse con un código de invitación, invitar y salir.
- Plan FREE/PREMIUM con el uso frente a sus límites (miembros, espacio, historial visible).
- Gastos: listar, crear y borrar; avisos de la API sobre el reparto.
- Ingresos: los propios (puntuales o recurrentes) y el reparto de cada mes entre los miembros; el
  propietario elige si los gastos se reparten a partes iguales o según ingresos.
- Saldos y pagos sugeridos para quedar en paz; "Registrar" anota el pago tras confirmarlo.
- Tareas: pendientes, crear (con periodicidad y asignado) y completar.

Fuera de esta versión: login con Google, facturas y edición de gastos ([A-005](docs/DECISIONS.md)).

## Arrancar

Necesita la API en marcha (ver el README del backend). Para la versión web, la API debe permitir el
origen de la app:

```bash
# en el repo del backend
CORS_ALLOWED_ORIGINS=http://localhost:5000 docker compose up --build
```

```bash
flutter pub get
flutter run -d chrome --web-port 5000
```

Otra URL de API: `--dart-define=API_BASE_URL=https://api.ejemplo.test`. En el emulador de Android,
`localhost` es el propio emulador: usa `--dart-define=API_BASE_URL=http://10.0.2.2:8080`.

## Tests

```bash
flutter analyze
flutter test
```

- `test/core`: cliente HTTP (un único refresh entre 401 concurrentes, sesión caducada, errores
  ProblemDetail) y dinero.
- `test/app`: redirecciones del router (incluida la vuelta a la ruta pedida tras restaurar la sesión).
- `test/features`: pantallas reales con providers y repositorios reales; solo se sustituye el
  `ApiClient` por uno con un adaptador HTTP falso (`test/support/fake_api.dart`), y se comprueba
  el cuerpo exacto de lo que se envía.

## Estructura

```
lib/
├── app/            # MaterialApp y rutas
├── core/           # api/ (cliente, errores), auth/ (tokens), money/, ui/ (vistas comunes)
└── features/<f>/   # data/ (modelos, repositorio, providers) y presentation/ (pantallas)
```

Decisiones de diseño en [docs/DECISIONS.md](docs/DECISIONS.md).
