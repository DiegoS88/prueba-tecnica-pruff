# Decisiones de diseño

Registro de las decisiones técnicas y de producto tomadas durante el desarrollo,
con el razonamiento detrás de cada una.

## Conciliación

### Regla de confirmación: folio + cronología (sin exigir monto)

**Decisión:** un movimiento se **confirma** automáticamente cuando el folio de la
factura aparece en la referencia o descripción del movimiento (normalizado y
delimitado) **y** `fecha_mov >= fecha_emision`. El monto no se exige.

**Por qué:** en la data real, una factura UF pagada en CLP es un match válido
pero los montos no coinciden numéricamente. Exigir igualdad de monto o moneda
perdía matches correctos (26 facturas UF confirmadas contra movimientos CLP).
La protección contra sobrepago (que sí depende del monto) vive en
`PaymentApplication#approve!`, no en el matcher.

### Extracción de folio con límites de palabra

**Decisión:** `Normalizers.folio` extrae `\b(\d{4,8})\b` del texto.

**Por qué:** los folios son siempre de 6 dígitos. Sin límites de palabra, un
folio corto podría matchear dentro de un número más largo (p. ej. `12345`
contiene `2345`). Con `\b` se evitan esos falsos positivos; dos colisiones
reales del dataset (`REF9103256` → `103256`, `REF2102777` → `102777`) no
matchean porque el número completo no corresponde a ningún folio.

### Precisión > recall

**Decisión:** si no hay folio, el matcher solo **sugiere** candidatos (monto
exacto único, pago parcial, múltiples candidatos) y nunca confirma.

**Por qué:** es más barato que un humano revise una sugerencia que corregir un
pago mal aplicado. La ambigüedad se representa de forma natural: un movimiento
con varios candidatos queda visible en Conciliación.

### Monedas: UF convertida a CLP con valor fijo

**Decisión:** `Invoice::UF_VALUE = 39_500.0`; toda factura UF se convierte a
CLP multiplicando por ese factor. Los montos de aplicación siempre se persisten
en CLP.

**Por qué:** todas las operaciones UF→CLP del dataset usan exactamente 39.500
(verificado: pagos completos 39.500, abonos 1/2 y 2/2 a 19.750, pago parcial
21,3% a 8.409,79 — en todos los casos la UF implícita es 39.500). Los estados
financieros y de conciliación se calculan sobre `monto_clp` para no mezclar
monedas (una factura UF pagada quedaba "parcialmente conciliada" por comparar
UF con CLP).

### `Matcher.run` no reprocesa movimientos resueltos

**Decisión:** `Matcher.run` salta los movimientos que ya tienen aplicaciones
(`next if movement.payment_applications.exists?`).

**Por qué:** idempotencia entre corridas. Consecuencia: al cambiar la lógica,
hay que borrar `payment_applications` y `audit_events` y re-correr para
re-evaluar con la nueva regla.

## Producto

### Dos definiciones de "sin conciliar"

- **Sin ninguna aplicación** (Conciliación): movimientos que el matcher no pudo
  asociar a nada.
- **Monto no cubierto por confirmados** (Dashboard / filtro): incluye movimientos
  con sugerencias pendientes.

La segunda no cambia con sugerencias, por diseño: el saldo solo se considera
cubierto cuando hay una confirmación, no una propuesta.

### Estados de factura filtrables = estados del badge

**Decisión:** el filtro de estado en Facturas filtra por `estado_financiero`
exacto (pendiente / vencida / pagada) y no por "tiene saldo".

**Por qué:** antes "Pendientes" incluía también las vencidas con saldo, lo que
confundía al usuario (filtraba pendientes y veía badges de vencida).

### Filtros de texto por substring

**Decisión:** todos los inputs de texto filtran con `ILIKE '%…%'` (folios, RUT,
referencias, n° de movimiento).

**Por qué:** el match exacto obligaba a conocer el valor completo; el substring
hace los listados explorables.

## Trazabilidad

### Timeline sin duplicados

**Decisión:** el timeline de una entidad excluye los `AuditEvent` de tipo
`payment_application_*`; las aplicaciones se muestran como hechos derivados con
su estado y actor.

**Por qué:** el matcher registra un audit event (`payment_application_suggested`,
actor sistema) y el timeline además derivaba `aplicacion_suggested` — la misma
sugerencia aparecía dos veces. Al confirmar aparecía un tercer evento
`movimiento_conciliado`. Un solo evento por aplicación.

### Actor humano en las decisiones

**Decisión:** `PaymentApplication#approve!`/`reject!` reciben `decided_by`;
el timeline usa `decided_by.email_address` en vez de "sistema".

**Por qué:** la decisión de conciliar es del usuario; la trazabilidad debe
reflejar quién la tomó.

## UI

### Gráficos sin JavaScript

**Decisión:** el gráfico de antigüedad de la deuda es CSS puro (barras
horizontales), no una librería JS.

**Por qué:** la app no tiene bundler JS (sin importmap/turbo de terceros);
un gráfico con divs y porcentajes de ancho es suficiente y sin dependencias.

### Tabla vacía conserva filtros

**Decisión:** cuando un filtro no devuelve resultados, la tabla se muestra con
sus filtros y el mensaje en una fila vacía, en vez de ocultar la tabla.

**Por qué:** ocultar la tabla escondía también los filtros y el botón "Limpiar",
obligando a volver atrás.

### Links de entidad como chips

**Decisión:** los links a shows (folio, n° de movimiento) usan la clase `.link`
(chip con fondo gris), sin subrayado ni color morado al visitar.

**Por qué:** el estilo de hyperlink por defecto resultaba poco prolijo y el
color de visitado (morado) era confuso.

## Pendientes (opcional)

- **Deploy**: subir a Neon (PostgreSQL) + Render (app). No realizado.
- **Snapshot diario**: el snapshot de cartera (`PortfolioSnapshot`) se captura
  en cada visita al dashboard; falta un job programado (cron) para capturas
  diarias deterministas.