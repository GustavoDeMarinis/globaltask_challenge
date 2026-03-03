APP_NAME=globaltask
DOCKER_COMPOSE=docker compose --profile dev
ENV_FILE=.env

include $(ENV_FILE)
export $(shell sed 's/=.*//' $(ENV_FILE))

.PHONY: setup run test migrate reset lint down

setup:
	$(DOCKER_COMPOSE) up -d
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