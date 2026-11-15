# CLAUDE.md — Hogar App

Cliente Flutter (iOS, Android y web) de la API **Hogar** (repo `Sechuam/hogar`): hogares compartidos,
gastos comunes con reparto, balances y pagos sugeridos, tareas de casa y plan FREE/PREMIUM.
La app **no mueve dinero**: registra pagos hechos por fuera y muestra quién debe a quién.

Proyecto de portfolio: se valora código limpio, tests reales y decisiones justificadas
(`docs/DECISIONS.md`).

## Stack

| Pieza | Elección |
|---|---|
| Flutter | 3.50 (Material 3 vía `package:material_ui`) |
| Estado | Riverpod 3 (`Provider`, `FutureProvider.family`, `AsyncNotifier`); sin generación de código |
| Navegación | go_router con `redirect` según la sesión |
| HTTP | Dio, envuelto en `ApiClient` (auth, refresh, errores) |
| Dinero | `decimal` — **nunca `double`** para importes |
| Tokens | refresh token en `flutter_secure_storage`; access token solo en memoria |
| Tests | `flutter_test`; widget tests contra una API falsa (`test/support/fake_api.dart`, A-006) |

## Arquitectura

```
lib/
├── main.dart             # ProviderScope + HogarApp
├── app/                  # router, tema, HogarApp
├── core/
│   ├── api/              # ApiClient (Dio), ApiException (ProblemDetail), Json
│   ├── auth/             # TokenStore (refresh token persistido)
│   ├── money/            # Money: parseo y formato con Decimal
│   └── ui/               # widgets y formato compartidos (fechas, errores, vacíos)
└── features/<feature>/
    ├── data/             # modelos inmutables con fromJson + repositorio (única capa que llama a ApiClient)
    └── presentation/     # pantallas y widgets; solo hablan con providers/repositorios
```

Features: `auth` (repositorio y `SessionController`), `households` (hogares, miembros, invitaciones, plan), `expenses`, `balances`
(balances y liquidaciones), `tasks`.

### Reglas
- Las pantallas **no** usan `ApiClient` ni Dio: usan el repositorio de su feature vía provider.
  Así los widget tests sustituyen el repositorio entero.
- Modelos: clases inmutables con `fromJson`; los nombres de campo son los del contrato OpenAPI.
- Importes: `Decimal` al leer (`Money.fromJson`) y **texto** al enviar (`"42.18"`, la API lo admite).
- Fechas de negocio: `DateTime` solo con fecha, enviada como `yyyy-MM-dd` (`Dates.toApi`).
- Errores: todo error HTTP se convierte en `ApiException` con el `code` estable de la API; la UI
  muestra el `detail` del servidor (ya está en español) y los `errors[]` por campo en el formulario.
- 401 → un único refresh compartido entre peticiones concurrentes (el refresh token rota y reusar uno
  viejo revoca la sesión) y reintento una vez; si el refresh falla, se cierra la sesión.
- Textos de la UI en español; código e identificadores en inglés.

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
# API en local (repo hogar): CORS_ALLOWED_ORIGINS=http://localhost:5000 docker compose up -d --build
flutter run -d chrome --web-port 5000                       # web contra http://localhost:8080
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080  # emulador Android
```

## Git
- Rama `main` siempre verde (`flutter analyze` + `flutter test`, también en CI).
- Conventional Commits con el tipo en inglés y descripción en español.
