# Cloud Payments

Clearing monthly repayments, drawn as clouds burning off a sun.
Every N centavos outstanding is one cloud; clearing a payment evaporates the
matching clouds and the sun brightens.

```
cloud-payments/
├── shared/cloud-rule.vectors.json   contract both implementations are pinned to
├── backend/                         NestJS + TypeORM + Postgres
└── app/                             Flutter, feature-first Clean Architecture
```

## Running it

Everything goes through the root `Makefile` (`make help` lists targets).
Requires Homebrew, Node, pnpm (`brew install pnpm`), and Flutter.

```bash
make setup      # once: pnpm + pub deps, backend/.env, Postgres 17 role + database

make api        # terminal 1 — starts Postgres if needed, then the API on :3000
make web        # terminal 2 — Chrome on :8080
make ios        # ...or the iOS simulator
make android    # ...or a running Android emulator
make device     # ...or a physical handset on the same Wi-Fi

make test       # both suites against the shared cloud-rule vectors
```

The run targets differ only in `API_BASE_URL`: web and the iOS simulator use
`localhost`, the Android emulator uses `10.0.2.2` (its alias for the host), and
a physical handset uses this machine's LAN IP. Start the API before the app,
because the app loads months on boot.

`synchronize: true` is on for the prototype, so the schema is built on connect.
Switch to migrations before anything real lands. `make db-shell` opens psql.

## The one rule that matters

`CloudRule` exists twice — Dart in `app/lib/features/sky/domain/entities/`,
TypeScript in `backend/src/sky/domain/`. That is deliberate. The sky has to
react the instant a payment clears, offline, with no round trip, so the client
needs the rule locally; but once an external feed can create payments the
server needs it too, or two clients disagree about the same month.

Duplicated rules drift, so both test suites read
`shared/cloud-rule.vectors.json`. Change the rule in one language and the other
repo's CI goes red. Add a vector before you add a behaviour.

Two invariants inside it:

- **Money is integer centavos, everywhere.** Dart `double` and JS `number` are
  the same IEEE-754 type. A balance that is truly ₱2,000 can arrive as
  `1999.9999999998` and silently render two clouds instead of three.
- **Cloud count is derived, never persisted.** Store `cloudCount: 4` on a row
  and the first external correction to the amount leaves the two disagreeing
  forever.

## Why the denominator is frozen

`centavosPerCloud` is chosen once, at month creation
(`backend/src/months/domain/suggest-denomination.ts`), then stored on the month
row. It must never float with the live balance: if it did, adding a bill
mid-month could rescale the sky and *reduce* the cloud count, or make clearing
a payment remove fewer clouds than the modal just promised.

Overflow is handled by shrinking rather than capping. `scaleFor` preserves
total painted area (`sqrt(maxClouds / n)`), so twenty clouds cover the same sky
as twelve and a heavy month reads as finer grain instead of a number to parse.
The floor is 0.42 — below that they look like lint.

## Why the sky is one painter

Forty clouds as forty `AnimatedPositioned` widgets means forty
`AnimationController`s, forty elements rebuilding each frame, and a stagger
that desyncs the moment a frame runs long. Instead: one `Ticker` in
`SkyController`, one `CustomPainter` subscribed to it via `repaint:`, and zero
widget rebuilds during an animation.

`drawAtlas` is the usual next suggestion and it is wrong here — `RSTransform`
only carries uniform scale, so it cannot express the 1.06×/0.90× squash that
makes the evaporate exit land. Forty `drawPath` calls are nowhere near a
bottleneck anyway.

## Known rough edges

- **Rollback animation.** A failed clear puts clouds back with the pop-in used
  for new bills — cheerful, in a moment that should feel like a setback. Wants
  a dedicated "condense" curve: evaporate played backwards, slower.
- **Overflow placement.** Clouds past `maxClouds` spiral outward and get
  clipped by the sky bounds. Fine up to roughly 2× capacity, visibly thin past
  that.
- **No auth, no offline queue.** Every mutation assumes connectivity; the
  optimistic path rolls back rather than retrying.
- **`suggestCentavosPerCloud` is a heuristic** and will want tuning against
  real balances. It is one function, called in one place, deliberately.
- **Month creation isn't wired into the UI.** The drawer selects existing
  months only; `POST /months` exists but nothing calls it.

## API

```
GET   /months                                  list, with payments
GET   /months/:id                              one month
POST  /months                                  create (suggests a denominator)
PATCH /months/:id/rule                         change denominator — redraws the sky
GET   /months/:id/sky                          derived cloud count + scale
POST  /months/:id/payments                     add a bill
POST  /months/:id/payments/:pid/clear          clear, returns payment + fresh sky
```

`POST /payments` accepts an optional `externalRef`. Supply it from any external
feed — the partial unique index on that column is what stops a replayed webhook
from creating a duplicate bill and silently giving the user clouds they don't
owe.
