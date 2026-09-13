# Cloud Payments — one-command dev workflows.
#
# The only thing that really differs between the run targets is API_BASE_URL.
# A browser and an iOS simulator share this machine's loopback; an Android
# emulator does not (10.0.2.2 is its alias for the host); a physical handset
# needs this machine's LAN address. Encoding that here means nobody has to
# remember which is which.

APP      := app
BACKEND  := backend
PG       := postgresql@17
PGBIN    := /opt/homebrew/opt/$(PG)/bin
WEB_PORT := 8080

HOST_API := http://localhost:3000
EMU_API  := http://10.0.2.2:3000
# Lazy (=, not :=) so the LAN lookup only runs for the target that needs it.
LAN_IP    = $(shell ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
LAN_API   = http://$(LAN_IP):3000

.PHONY: help setup db db-stop db-shell api web ios android device test test-app test-api doctor

help:
	@echo "Cloud Payments"
	@echo ""
	@echo "  make setup      one-time: deps for both sides, .env, database"
	@echo ""
	@echo "  make db         start Postgres (background service)"
	@echo "  make api        start the NestJS API on :3000  [run this first]"
	@echo ""
	@echo "  make web        run the Flutter app in Chrome on :$(WEB_PORT)"
	@echo "  make ios        run on the iOS simulator"
	@echo "  make android    run on the Android emulator"
	@echo "  make device     run on a physical handset over the LAN"
	@echo ""
	@echo "  make test       run both test suites"
	@echo "  make doctor     check the toolchain"
	@echo ""
	@echo "The API must be running before the app; the app loads months on boot."

# ---------------------------------------------------------------- setup

setup:
	cd $(BACKEND) && pnpm install
	cd $(BACKEND) && [ -f .env ] || cp .env.example .env
	cd $(APP) && flutter pub get
	@$(MAKE) db
	@$(PGBIN)/psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'" | grep -q 1 \
	  || $(PGBIN)/psql -d postgres -c "CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'postgres';"
	@$(PGBIN)/psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='cloud_payments'" | grep -q 1 \
	  || $(PGBIN)/createdb -O postgres cloud_payments
	@echo ""
	@echo "Ready. Run 'make api' in one terminal, then 'make web' in another."

# ---------------------------------------------------------------- database

db:
	@brew services start $(PG) >/dev/null
	@for i in $$(seq 1 30); do \
	  $(PGBIN)/pg_isready -h localhost -p 5432 >/dev/null 2>&1 && break; sleep 1; \
	done
	@$(PGBIN)/pg_isready -h localhost -p 5432

db-stop:
	brew services stop $(PG)

db-shell:
	$(PGBIN)/psql postgres://postgres:postgres@localhost:5432/cloud_payments

# ---------------------------------------------------------------- backend

# Depends on db: TypeORM synchronize:true builds the schema on connect, so a
# cold machine still comes up with one command.
api: db
	cd $(BACKEND) && pnpm start:dev

# ---------------------------------------------------------------- app

web:
	cd $(APP) && flutter run -d chrome --web-port=$(WEB_PORT) \
	  --dart-define=API_BASE_URL=$(HOST_API)

ios:
	@open -a Simulator
	cd $(APP) && flutter run -d ios --dart-define=API_BASE_URL=$(HOST_API)

android:
	cd $(APP) && flutter run -d android --dart-define=API_BASE_URL=$(EMU_API)

device:
	@test -n "$(LAN_IP)" || { echo "No LAN address on en0/en1 — are you on Wi-Fi?"; exit 1; }
	@echo "Handset will reach this machine at $(LAN_API)"
	@echo "Both devices must be on the same network."
	cd $(APP) && flutter run --dart-define=API_BASE_URL=$(LAN_API)

# ---------------------------------------------------------------- tests

test: test-api test-app

test-api:
	cd $(BACKEND) && pnpm test

test-app:
	cd $(APP) && flutter test

doctor:
	cd $(APP) && flutter doctor
	@echo "--- devices ---"
	@cd $(APP) && flutter devices
