# Cartera

Aplicación Rails de conciliación entre **facturas** (emitidas a deudores) y
**movimientos bancarios** (pagos recibidos). Detecta qué movimientos pagan qué
factura, confirma automáticamente los matches seguros y deja los ambiguos para
revisión humana.

## Stack

- Ruby 3.2.3, Rails 8.1.3, PostgreSQL
- Sin frontend JavaScript: UI en ERB + CSS plano (`app/assets/stylesheets/application.css`)
- Tests con Minitest (integración + servicios), RuboCop para estilo

## Deploy

La app está desplegada en **Render**: <https://pruebapruff.onrender.com>

- Configuración declarativa en `render.yaml` (PostgreSQL free + web service).
- El deploy se dispara automáticamente al pushear a `main`.
- Credenciales demo: `demo@pruff.cl` / `password123`.
- Nota: el plan free se duerme tras 15 min sin uso; la primera visita tras el
  reinicio tarda ~1 min en responder.

## Puesta en marcha

```bash
bundle install
bin/rails db:create db:migrate
bin/rails db:seed        # crea demo@pruff.cl / password123
bin/rails server
```

Inicia sesión con `demo@pruff.cl` / `password123`.

### Correr tests y linter

```bash
bin/rails test
bin/rubocop
```

## Funcionalidad

- **Importación**: sube `facturas.csv` y `movimientos.csv` desde *Importar → Nueva importación*. Los datos solo se cargan por la UI; no vienen incluidos en el repo.
- **Dashboard**: saldo por cobrar, vencido/por vencer, movimientos sin conciliar, gráfico de antigüedad de la deuda, y panel "Requiere atención" con atajos.
- **Facturas / Movimientos**: listados paginados con filtros (substring, `ILIKE`), estado financiero (pendiente / parcialmente pagada / vencida / pagada) y estado de conciliación.
- **Conciliación**: candidatos sugeridos por el matcher (aprobar/rechazar), y movimientos sin conciliar. Al decidir, la trazabilidad queda a nombre del usuario.
- **Trazabilidad**: timeline por factura/movimiento reconstruido desde `AuditEvent` + hechos derivados (actor humano cuando hay decisión).

## Motor de conciliación

El matcher (`app/services/matcher.rb`) produce tres niveles por movimiento:

- **CONFIRMADO** — el folio de la factura aparece en la referencia/descripción del movimiento (extraído con `Normalizers.folio`, delimitado, sin falso-positivos por substring) **y** la fecha del movimiento es cronológicamente válida (`fecha_mov >= fecha_emision`). Se aplica automáticamente.
- **SUGERIDO** — hay evidencia sin folio (monto exacto único, pago parcial, múltiples candidatos). Requiere decisión humana en Conciliación.
- **SIN MATCH** — sin candidatos razonables.

Principio de producto: **precisión > recall**; es mejor dejar un movimiento sin conciliar que asignarlo mal.

Notas:

- El monto **no** se exige para confirmar: una factura UF pagada en CLP es un match válido. La protección contra sobrepago vive en `PaymentApplication#approve!`.
- Las facturas **UF** se convierten a CLP con un valor fijo del dataset (`Invoice::UF_VALUE = 39_500.0`). Los montos de aplicación siempre se persisten en CLP.
- `Matcher.run` no reprocesa movimientos que ya tienen aplicaciones (para re-correr con la lógica nueva: borra `payment_applications` y `audit_events`, luego ejecuta `Matcher.run`).

## Estructura clave

- `app/services/matcher.rb` — motor de conciliación.
- `app/services/portfolio_calculator.rb` — métricas de cartera derivadas (saldo, aging, deuda por deudor).
- `app/services/invoice_timeline.rb` — timeline por factura/movimiento.
- `app/models/invoice.rb` / `app/models/movement.rb` — estados financieros y de conciliación.
- `app/models/normalizers.rb` — normalización de RUT, montos, fechas, folios.
- `app/models/payment_application.rb` — `approve!`/`reject!` con guardas de sobrepago y auditoría.
- `test/services/matcher_test.rb` — reglas de confirmación, UF y pagos parciales.

## Decisiones de diseño

Ver `DECISIONS.md` para el registro completo de decisiones técnicas y de producto.