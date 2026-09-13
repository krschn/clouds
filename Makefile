# Clouds — one-command dev workflows.
#
# The app keeps its months on the device (SharedPreferences), so the run
# targets need nothing else running. The backend targets are still here for
# work on the API; the app is not wired to it for now.

APP      := app
BACKEND  := backend
PG       := postgresql@17
PGBIN    := /opt/homebrew/opt/$(PG)/bin
WEB_PORT := 8080

.PHONY: help setup setup-api db db-stop db-shell api web ios android device test test-app test-api doctor

help:
	@echo "Clouds"
	@echo ""
	@echo "  make setup      one-time: Flutter deps"
	@echo ""
	@echo "  make web        run the Flutter app in Chrome on :$(WEB_PORT)"
	@echo "  make ios        run on the iOS simulator (boots one if needed)"
	@echo "  make android    run on the Android emulator (starts one if needed)"
	@echo "  make device     run on a connected physical handset"
	@echo ""
	@echo "  make test       run both test suites"
	@echo "  make doctor     check the toolchain"
	@echo ""
	@echo "Backend (not needed to run the app):"
	@echo "  make setup-api  one-time: pnpm deps, .env, Postgres role + database"
	@echo "  make db         start Postgres (background service)"
	@echo "  make api        start the NestJS API on :3000"
	@echo ""
	@echo "Months are saved on the device, so the app works offline."

# ---------------------------------------------------------------- setup

setup:
	cd $(APP) && flutter pub get

setup-api:
	cd $(BACKEND) && pnpm install
	cd $(BACKEND) && [ -f .env ] || cp .env.example .env
	@$(MAKE) db
	@$(PGBIN)/psql -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='postgres'" | grep -q 1 \
	  || $(PGBIN)/psql -d postgres -c "CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'postgres';"
	@$(PGBIN)/psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='cloud_payments'" | grep -q 1 \
	  || $(PGBIN)/createdb -O postgres cloud_payments
	@echo ""
	@echo "Ready. Run 'make api' to start the API."

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
	cd $(APP) && flutter run -d chrome --web-port=$(WEB_PORT)

# `flutter run -d ios` / `-d android` match nothing: -d takes a device name or
# id, not a platform. device.sh resolves the id and boots a device if needed.
ios:
	@id=$$(bash scripts/device.sh ios) && echo "Running on $$id" && \
	  cd $(APP) && flutter run -d "$$id"

android:
	@id=$$(bash scripts/device.sh android) && echo "Running on $$id" && \
	  cd $(APP) && flutter run -d "$$id"

device:
	cd $(APP) && flutter run

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
