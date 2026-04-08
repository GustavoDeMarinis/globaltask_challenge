APP_NAME=mccap
DOCKER_COMPOSE=docker compose
ENV_FILE=.env

include $(ENV_FILE)
export $(shell sed 's/=.*//' $(ENV_FILE))

.PHONY: setup run test migrate reset lint down dialyzer check-env

check-env:
	@test -f .env || (echo "ERROR: .env file not found. Copy .env.example to .env and configure it." && exit 1)
	@git ls-files --error-unmatch .env 2>/dev/null && echo "ERROR: .env is tracked by git! Run: git rm --cached .env" && exit 1 || true
	@echo ".env exists and is not tracked by git [OK]"

setup: check-env
	$(DOCKER_COMPOSE) up -d
	@echo "Waiting for PostgreSQL to be ready..."
	@until docker compose exec -T postgres pg_isready -U $(POSTGRES_USER) > /dev/null 2>&1; do sleep 1; done
	@echo "PostgreSQL is ready [OK]"
	mix setup

run:
	mix phx.server

test:
	MIX_ENV=test mix test

migrate:
	mix ecto.migrate

reset:
	mix ecto.reset

lint:
	mix format
	mix credo --strict

down:
	$(DOCKER_COMPOSE) down

dialyzer:
	mix dialyzer