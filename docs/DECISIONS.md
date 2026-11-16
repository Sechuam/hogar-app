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
completar). Fuera por ahora: login con Google (necesita client IDs de cada plataforma), facturas (cámara y ficheros), edición de gastos y notificaciones. Las facturas llegaron después (A-010).

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

## A-008 · Ingresos: los propios en detalle, los demás solo en el resumen — Aceptada
**Contexto:** la API deja listar los ingresos de todo el hogar (transparencia del reparto).
**Decisión:** la app muestra en detalle solo los ingresos propios (`userId` = yo) y, de los demás, el
total del mes y su porcentaje (`/incomes/summary`), que es lo que usa el reparto proporcional. Ver la
nómina concreta de un compañero de piso aporta poco y resulta invasivo. **Consecuencia:** si un hogar
quisiera ver el detalle de todos, basta con quitar el filtro; la API ya lo permite.

## A-009 · Sistema visual propio sobre Material 3 — Aceptada
**Contexto:** con el tema por defecto cada pantalla resolvía a su manera colores, espaciados e importes.
**Decisión:** un tema (`core/ui/theme.dart`) con superficies tonales en vez de sombras, formas
redondeadas comunes y colores semánticos para el dinero (`MoneyColors`: a favor y en contra, ajustados
a claro y oscuro), más componentes compartidos (`core/ui/widgets.dart`): avatar con color estable por
persona, importe con cifras tabulares, cabecera de sección, tarjeta destacada y ancho máximo de 720 px
para tablet y web. Sin fuentes descargadas: se usa la tipografía del sistema (sin dependencias ni
peticiones externas). **Consecuencia:** las pantallas solo combinan piezas; cambiar el aspecto de la app
es tocar un fichero.

## A-010 · Facturas: plugins detrás de una interfaz y errores dentro de la ficha — Aceptada
**Contexto:** adjuntar una factura necesita elegir un fichero y, al verla, entregarla al sistema;
ambas cosas dependen de la plataforma (diálogo nativo, hoja de compartir, descarga en web).
**Decisión:** `file_picker` para elegir y `share_plus` para abrir (en móvil, la hoja de compartir con
"Abrir con…" y "Guardar en Archivos"; en web, descarga), ambos detrás de `InvoiceFiles`, que los tests
sustituyen. Las imágenes se previsualizan en la propia app; los PDF van directos al sistema (sin visor
PDF propio, que añadiría una dependencia pesada). La app comprueba el límite de 10 MB antes de subir,
pero el tipo lo decide la API por el contenido. La factura se consulta al abrir la ficha del gasto
(`/invoice/metadata`) y no en la lista, que haría una petición por gasto. Los errores se muestran en la
ficha y no en un SnackBar, que quedaría tapado por la hoja modal. **Consecuencia:** para marcar en la
lista qué gastos tienen factura, la API añadió `hasInvoice` a `ExpenseResponse` (un icono en cada fila,
sin peticiones extra).

## A-011 · Movimiento y gráficos propios, sin librerías — Aceptada
**Contexto:** la app era correcta pero plana: un círculo girando al cargar, cifras que aparecían de
golpe y totales sin desglose visual.
**Decisión:** piezas propias en `core/ui`: `Motion` (duraciones y curva comunes; respeta "reducir
movimiento" del sistema), `Appear` (entrada escalonada de listas), `AnimatedAmount` (el importe cuenta
hasta su valor), `SkeletonList` (esqueleto con brillo en la primera carga) y, en `charts.dart`,
`SegmentBar` (reparto por categorías), `DivergingBar` (saldos a favor y en contra) y `StatTile`. No se
usa una librería de gráficos: son barras sencillas y una dependencia más pesaría más que el código.
Reglas: el dinero se anima en céntimos enteros (nunca `double`); los retrasos van dentro de la propia
animación (`Interval`), no en temporizadores, para no dejar trabajo pendiente si el widget desaparece;
y un estado animado se reinicia cuando el dato cambia aunque el widget sea el mismo (una tarea
periódica completada vuelve con el mismo id y la fecha siguiente). Los botones flotantes viven en el
`Scaffold` del hogar y cambian con la pestaña, para que el SnackBar los desplace en vez de taparlos.
Completar una tarea puntual ofrece "Deshacer" (`/reopen`); una periódica no, porque ya ha generado la
siguiente. **Consecuencia:** el aspecto sigue dependiendo solo de `core/ui`; los gráficos son
decorativos y los importes exactos se muestran siempre en texto.
