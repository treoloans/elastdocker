.DEFAULT_GOAL:=help

EXTENSIONS=./extensions/
APM_EXTENSION=${EXTENSIONS}/apm-server/

COMPOSE_ALL_FILES := -f docker-compose.yml -f docker-compose.monitor.yml -f ${APM_EXTENSION}/apm-server-compose.yml
COMPOSE_MONITORING := -f docker-compose.yml -f docker-compose.monitor.yml
COMPOSE_EXTENSIONS := -f docker-compose.yml -f ${APM_EXTENSION}/apm-server-compose.yml
COMPOSE_NODES := -f docker-compose.yml -f docker-compose.nodes.yml
ELK_SERVICES   := elasticsearch logstash kibana
ELK_MONITORING := elasticsearch-exporter logstash-exporter filebeat-cluster-logs
ELK_EXTENSIONS  := apm-server
ELK_NODES := elasticsearch-1 elasticsearch-2
ELK_MAIN_SERVICES := ${ELK_SERVICES} ${ELK_MONITORING} ${ELK_EXTENSIONS}
ELK_ALL_SERVICES := ${ELK_MAIN_SERVICES} ${ELK_NODES}
# --------------------------

# load .env so that Docker Swarm Commands has .env values too. (https://github.com/moby/moby/issues/29133)
include .env
export

# --------------------------
.PHONY: setup keystore certs all elk monitoring extensions build down stop restart rm logs

keystore:		## Setup Elasticsearch Keystore, by initializing passwords, and add credentials defined in `keystore.sh`.
	docker-compose -f docker-compose.setup.yml run --rm keystore

certs:		    ## Generate Elasticsearch SSL Certs.
	docker-compose -f docker-compose.setup.yml run --rm certs

setup:		    ## Generate Elasticsearch SSL Certs and Keystore.
	@make certs
	@make keystore

all:		    ## Start Elk and all its component (ELK, Monitoring, and Extensions).
	docker-compose ${COMPOSE_ALL_FILES} up -d --build ${ELK_MAIN_SERVICES}

elk:		    ## Start ELK.
	docker-compose up -d --build

monitoring:		## Start ELK Monitoring.
	@docker-compose ${COMPOSE_MONITORING} up -d --build ${ELK_MONITORING}

extensions:		    ## Start ELK Extensions (apm-server).
	@docker-compose ${COMPOSE_EXTENSIONS} up -d --build ${ELK_EXTENSIONS}

nodes:		    ## Start Two Extra Elasticsearch Nodes
	@docker-compose ${COMPOSE_NODES} up -d --build ${ELK_NODES}

build:			## Build ELK and all its extra components.
	@docker-compose ${COMPOSE_ALL_FILES} build ${ELK_ALL_SERVICES}

down:			## Down ELK and all its extra components.
	@docker-compose ${COMPOSE_ALL_FILES} down

stop:			## Stop ELK and all its extra components.
	@docker-compose ${COMPOSE_ALL_FILES} stop ${ELK_ALL_SERVICES}

restart:		## Restart ELK and all its extra components.
	@docker-compose ${COMPOSE_ALL_FILES} restart ${ELK_ALL_SERVICES}

rm:				## Remove ELK and all its extra components containers.
	@docker-compose $(COMPOSE_ALL_FILES) rm -f ${ELK_ALL_SERVICES}

logs:			## Tail all logs with -n 1000.
	@docker-compose $(COMPOSE_ALL_FILES) logs --follow --tail=1000 ${ELK_ALL_SERVICES}

images:			## Show all Images of ELK and all its extra components.
	@docker-compose $(COMPOSE_ALL_FILES) images ${ELK_ALL_SERVICES}

prune:			## Remove ELK Containers and Delete Volume Data
	@make swarm-rm || echo ""
	@make stop && make rm
	@docker volume prune -f

swarm-deploy-elk:
	@make build
	docker stack deploy -c docker-compose.yml elastic

swarm-deploy-monitoring:
	@make build
	@docker stack deploy -c docker-compose.yml -c docker-compose.monitor.yml elastic

swarm-deploy-extensions:
	@make build
	@docker stack deploy -c docker-compose.yml -c ${APM_EXTENSION}/apm-server-compose.yml elastic

swarm-rm:
	docker stack rm elastic


help:       	## Show this help.
	@echo "Make Application Docker Images and Containers using Docker-Compose files in 'docker' Dir."
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m (default: help)\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
