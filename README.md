# Clouds

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
The app needs only Flutter.

```bash
make setup      # once: pub deps

make web        # Chrome on :8080
make ios        # ...or the iOS simulator (boots one if needed)
make android    # ...or the Android emulator (starts one if needed)
make device     # ...or a connected physical handset

make test       # both suites against the shared cloud-rule vectors
```

### Storage: on the device, for now

The app does not talk to the backend. Months and bills are saved on the device
with `shared_preferences` (`PaymentsLocalDataSource`, one JSON value under
`clouds.months.v1`), so it runs offline with nothing else started. The local
source mirrors the API's rules — unique periods, no clearing twice, and the
same `suggestCentavosPerCloud` ladder, ported to
`app/lib/features/payments/domain/usecases/`.

The API client, `PaymentsRemoteDataSource` and `PaymentsRepositoryImpl` are
still in the app, just not wired in. Swapping back is one line in `main.dart`.
Nothing syncs between the two, so data added on a device stays on it.

### Backend

Still here for work on the API. Needs Homebrew, Node and pnpm
(`brew install pnpm`).

```bash
make setup-api  # once: pnpm deps, backend/.env, Postgres 17 role + database
make api        # starts Postgres if needed, then the API on :3000
```

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

## Big clouds

Every five clouds draw as one big cloud (`group_clouds.dart`). It is display
only: the count, the caption, the darkness and both `CloudRule`s still work in
single clouds, so nothing about it crosses the API or the shared vectors.

Clearing into a big cloud splits it — it bursts, and the part still owed flies
out of it as small clouds. Adding past a multiple of five gathers the loose
small clouds into a new big one, which is not a clear: no bursts, no haptics
beyond the landing tap.

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

- **Very heavy months share spots.** Clouds stack in up to three layers of the
  month's capacity, all inside the sky. Past that, extra clouds double up on
  existing spots, so a month far over its estimate looks no busier than one at
  3× — the caption carries the real count.
- **No auth, no sync.** The app stores months on the device only; clearing
  still runs through the optimistic path, which rolls back if the save fails.
  Moving to the API later needs a one-time import of what devices hold.
- **`suggestCentavosPerCloud` is a heuristic** and will want tuning against
  real balances. It is one function, called in one place, deliberately.
- **Month switches snap.** Changing month swaps the sky's colours instantly
  rather than fading; the closing drawer covers most of it.

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
