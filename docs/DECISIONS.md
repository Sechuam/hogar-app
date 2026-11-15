# Decisiones — Hogar App

Formato ADR corto. Las decisiones del backend están en el repo `hogar` (`docs/DECISIONS.md`, D-001…).

## A-001 · Flutter para iOS, Android y web — Aceptada
**Decisión:** una sola base de código en Flutter. **Alternativas:** React Native + Expo (TypeScript),
Kotlin Multiplatform (cercano a Java pero más costoso de montar en iOS), SwiftUI (solo iOS).
**Consecuencias:** la web sirve para desarrollar y probar sin simulador; la API necesita CORS para ella
(D-069 del backend).

## A-002 · Riverpod sin generación de código, go_router y Dio — Aceptada
Riverpod da inyección de dependencias testeable (los widget tests sustituyen el cliente HTTP con
`overrides`) y estados asíncronos (`AsyncValue`) sin `setState` repartido. Sin `riverpod_generator` ni
`freezed`: menos magia y nada de `build_runner` en un proyecto pequeño; los modelos son clases a mano.
go_router declara rutas y redirige según la sesión. Dio por sus interceptores y su adaptador sustituible
en tests.

## A-003 · Importes con Decimal, enviados como texto — Aceptada
**Contexto:** la API usa `BigDecimal` con 2 decimales y acepta el número entre comillas (`"42.18"`).
**Decisión:** el cliente nunca opera con `double`: el texto que teclea el usuario se valida y se convierte
en `Decimal`, y se envía como texto. Al leer, `jsonDecode` ya entrega `double`; se convierte a `Decimal`
desde su representación más corta, exacta para importes de hasta 15 cifras significativas (billones de
euros con céntimos). **Alternativa:** un decodificador JSON propio que conserve el texto del número —
complejidad sin beneficio real a esta escala.

## A-004 · Refresh token en almacenamiento seguro, access token en memoria — Aceptada
El refresh token (30 días, rotatorio) va en Keychain/Keystore vía `flutter_secure_storage`; el access
token (15 min) solo en memoria y se renueva al arrancar o ante un 401. Un único refresh en vuelo se
comparte entre peticiones concurrentes: con tokens rotatorios, dos refresh paralelos con el mismo token
harían que el backend detecte reutilización y revoque la sesión.
**Consecuencia en web:** el almacenamiento "seguro" de la web es el del navegador; aceptable para
desarrollo, y la API no usa cookies (sin CSRF).

## A-005 · Alcance de la primera versión — Aceptada
Incluye: registro y login con email, hogares (crear, unirse con código, invitar), plan y uso, gastos
(listar, crear, borrar), balances con pagos sugeridos y registro del pago, tareas (listar, crear,
completar). Fuera por ahora: login con Google (necesita client IDs de cada plataforma), ingresos y
reparto proporcional desde la app, facturas (cámara y ficheros), edición de gastos y notificaciones.

## A-006 · Tests de widgets contra una API falsa — Aceptada
**Contexto:** los widgets dependen de providers que llaman a repositorios que llaman al `ApiClient`.
**Decisión:** en los tests solo se sustituye `apiClientProvider` por un cliente cuyo adaptador HTTP
responde por ruta (`FakeApi`). Pantalla, providers, repositorios, mapeo JSON y manejo de errores son los
reales, y se comprueba el cuerpo exacto enviado (p. ej. `"amount": "42.50"`). **Alternativa:** mocks de
cada repositorio con mocktail — más rápidos de escribir, pero no detectan errores de mapeo como un
`fromJson` que rompe con la respuesta real.

## A-007 · Volver a la ruta pedida tras recuperar la sesión — Aceptada
En web, recargar `/#/households/<id>` pasa por `/splash` mientras se renueva la sesión. La redirección
guarda la ruta en `?from=` y vuelve a ella; solo se aceptan rutas internas (empiezan por `/`, no por
`//`, ni son `/splash` o `/login`) para que un enlace manipulado no saque de la app.
