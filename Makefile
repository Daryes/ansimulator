.PHONY: no_targets__ all list help
.DEFAULT_GOAL=help
list: ## Show all the existing targets of this Makefile
	@sh -c "$(MAKE) -p no_targets__ 2>/dev/null | awk -F':' '/^[a-zA-Z0-9][^\$$#\/\\t=]*:([^=]|$$)/ {split(\$$1,A,/ /);for(i in A)print A[i]}' | grep -v '__\$$' | sort -u"

help: ## Show the targets and their description (this screen)
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


# Global settings -----------------------------------
# Mini-doc:
# - mandatory TAB for indentation
# - declare delayed variable : var=value  or var=va lu es  - quotes are litteral with make, they are not interpreted
# - declare immediate variable : var:=value
# - use variables    : var2=${var}  or  var2=$(var)
# - retrieve command stdout : var=$$( command args )
# - variable declaration with default value : var ?=default_value
# - hide a line from the output : @command   or @# commentary

SHELL=/bin/bash -o pipefail

DIFF ?=--diff

ANSIBLE_SIMUL_DOCKERFILE_ROOTDIR=.ci/docker-ansimulator-template
ANSIBLE_SIMUL_COMPOSE=.ci/docker-compose.ansimulator.yml
ANSIBLE_SIMUL_COMPOSE_ENV=.ci/docker-compose.ansimulator.env
ANSIBLE_SIMUL_REPO_ON_SERVER=/opt/repo/tests/ansible
ANSIBLE_SIMUL_INVENTORY_ON_SERVER=${ANSIBLE_SIMUL_REPO_ON_SERVER}/inventory
ANSIBLE_SIMUL_INVENTORY_EXEC=ansible-playbook ${DIFF} -i ${ANSIBLE_SIMUL_INVENTORY_ON_SERVER}  ${ANSIBLE_SIMUL_REPO_ON_SERVER}

ANSIBLE_MASTER_CONTAINER=ci-ansible-master
ANSIBLE_MASTER_INVENTORY_GROUP_ALL=domain

# using $$var make their expansion delayed when they are used in the build: target
DOCKER_BUILD_CMD_COMMON_ARGS=--progress plain  \
	--build-arg IMAGE_DEBIAN_NAME=$$IMAGE_DEBIAN_REF_NAME  --build-arg IMAGE_DEBIAN_VERSION=$$IMAGE_DEBIAN_REF_VERSION \
	--build-arg IMAGE_CENTOS_NAME=$$IMAGE_CENTOS_REF_NAME  --build-arg IMAGE_CENTOS_VERSION=$$IMAGE_CENTOS_REF_VERSION \
	--build-arg ANSIBLE_USER_UID=$$ANSIBLE_USER_UID \
	--build-arg PKG_APT_PROXY="$${PKG_APT_PROXY:-}" --build-arg PKG_YUM_PROXY="$${PKG_YUM_PROXY:-}"  \
	${ANSIBLE_SIMUL_DOCKERFILE_ROOTDIR}/

ANSIBLE_SIMUL_COMPOSE_CMD=docker-compose -f ${ANSIBLE_SIMUL_COMPOSE}  --env-file ${ANSIBLE_SIMUL_COMPOSE_ENV}
DOCKER_EXEC_ANSIBLE_CMD=docker exec -it --user ansible ${ANSIBLE_MASTER_CONTAINER} /bin/bash


ansible-simul-docker-build: ## build the ansible simulator docker images with ssh support - required one time before any compose command
	@# the version is retrieved from the compose.env
	@# the images are pulled instead of being stored into the builder cache which is volatile
	set -eux ;\
		source ${ANSIBLE_SIMUL_COMPOSE_ENV} ;\
		ANSIBLE_USER_UID=$$( stat --format "%u" . );\
		docker pull $$IMAGE_DEBIAN_REF_NAME:$$IMAGE_DEBIAN_REF_VERSION  ;\
		docker pull $$IMAGE_CENTOS_REF_NAME:$$IMAGE_CENTOS_REF_VERSION  ;\
		docker build -t $$IMAGE_CENTOS_CI --build-arg TARGET_DIST=redhat ${DOCKER_BUILD_CMD_COMMON_ARGS} ;\
		docker build -t $$IMAGE_DEBIAN_CI --build-arg TARGET_DIST=debian ${DOCKER_BUILD_CMD_COMMON_ARGS}

ansible-simul-up: ansible-simul-start
ansible-simul-start: ## start the ansible test enviroment using compose
	@# validate the configuration before start
	${ANSIBLE_SIMUL_COMPOSE_CMD} config -q
	${ANSIBLE_SIMUL_COMPOSE_CMD} up -d

ansible-simul-down: ansible-simul-stop
ansible-simul-stop: ## stop the docker containers using compose
	@${ANSIBLE_SIMUL_COMPOSE_CMD} down
	@source ${ANSIBLE_SIMUL_COMPOSE_ENV} && \
		docker volume ls -q | grep -q "$$DOCKER_HOST_DOCKER_DATA_VOLUME" && \
		docker volume rm $$DOCKER_HOST_DOCKER_DATA_VOLUME || true

ansible-simul-status: ## status of the docker containers using compose
	${ANSIBLE_SIMUL_COMPOSE_CMD} ps


ansible-simul-connect: ## connect to the local ansible master container
	@# the error 130 happens on a normal logout when an error occured before or ctrl-c was pressed
	@${DOCKER_EXEC_ANSIBLE_CMD} -l; if [ $$? -eq 130 ]; then exit 0; fi

ansible-simul-validate: ## verify the communication from ansible master to the other containers using ssh
	@${DOCKER_EXEC_ANSIBLE_CMD} -i -c "source ~/.bashrc; echo "" > ~/.ssh/known_hosts; exit 2>/dev/null"
	@${DOCKER_EXEC_ANSIBLE_CMD} -i -c "ansible --one-line -i ${ANSIBLE_SIMUL_INVENTORY_ON_SERVER} -m ping ${ANSIBLE_MASTER_INVENTORY_GROUP_ALL}"


ansible-tools-compat-v2_14-update-roles:  ## update roles for ansible-core 2.14+ deprecations
	@# remove all existing '  warn:' arguments which are not supported anymore on the modules 'command' and 'shell'
	@${DOCKER_EXEC_ANSIBLE_CMD} -c "egrep -ri '^ *  warn: .*' /etc/ansible/roles/*/{handlers,tasks,vars}/ | cut -d ':' -f1 |sort -u |xargs --no-run-if-empty sed -i '/^ *  warn: .*/d'"
	@echo "Roles updated"


ansible-syntax-1-yamllint: ## run yamllint on the ansible roles
	@${DOCKER_EXEC_ANSIBLE_CMD} -c "yamllint -v; cd /etc/ansible && yamllint -c /opt/repo/.ci/yamllint  roles/"

ansible-syntax-2-ansiblelint: ## run ansible-lint on the ansible playbooks
	@# set the command between ' ' and still double the $ to prevent any interpretation from make
	${DOCKER_EXEC_ANSIBLE_CMD} -c 'ansible-lint --version; export LINT_CONF=ansible-lint; [ -z "$${ANSIBLE_VERSION##2.9*}" ] && LINT_CONF=$${LINT_CONF}-v2.9 ; cd /etc/ansible && ansible-lint --show-relpath -c /opt/repo/.ci/$$LINT_CONF  roles/* '


ansible-syntax-3-playbook-check: ## run ansible-playbook syntax check
	@${DOCKER_EXEC_ANSIBLE_CMD} -c "cd /etc/ansible && ansible-playbook --syntax-check -i ${ANSIBLE_SIMUL_INVENTORY_ON_SERVER}  *.yml"


ansible-unit-1-playbook-certificates: ## ansible role unit test: certificate-generate_ca + certificate-push-trusted + certificate-generate
	${DOCKER_EXEC_ANSIBLE_CMD} -c "${ANSIBLE_SIMUL_INVENTORY_EXEC}/playbook-test-certificate-generate_ca-push-generate.yml"

ansible-unit-2-playbook-docker: ## ansible role unit test: sys-docker
	${DOCKER_EXEC_ANSIBLE_CMD} -c "${ANSIBLE_SIMUL_INVENTORY_EXEC}/playbook-test-docker.yml"

ansible-unit-3-playbook-db: ## ansible role unit test: db-mysql & db-postgresql
	${DOCKER_EXEC_ANSIBLE_CMD} -c "${ANSIBLE_SIMUL_INVENTORY_EXEC}/playbook-test-db.yml"

ansible-unit-4-playbook-web-nginx-apache: ## ansible roles unit test: web-nginx & web-apache
	${DOCKER_EXEC_ANSIBLE_CMD} -c "${ANSIBLE_SIMUL_INVENTORY_EXEC}/playbook-test-web.yml"

ansible-unit-5-playbook-monitoring: ## ansible role unit test: monitoring-prometheus* & monitoring-grafana
	${DOCKER_EXEC_ANSIBLE_CMD} -c "${ANSIBLE_SIMUL_INVENTORY_EXEC}/playbook-test-monitoring.yml --flush-cache"

ansible-unit-5b-playbook-monitoring-container: ## ansible role unit test: monitoring-cadvisor for prometheus
	${DOCKER_EXEC_ANSIBLE_CMD} -c "${ANSIBLE_SIMUL_INVENTORY_EXEC}/playbook-test-monitoring-container.yml"

ansible-unit-6-playbook-java: ## ansible role unit test: sys-java
	${DOCKER_EXEC_ANSIBLE_CMD} -c "${ANSIBLE_SIMUL_INVENTORY_EXEC}/playbook-test-java.yml"

ansible-unit-7-playbook-dns-server: ## ansible role unit test: dns-bind
	${DOCKER_EXEC_ANSIBLE_CMD} -c "${ANSIBLE_SIMUL_INVENTORY_EXEC}/playbook-test-dns-server.yml"

ansible-unit-9-playbook-serial-over-hostgroups: ## ansible role unit test: _serial_over_hostgroups
	${DOCKER_EXEC_ANSIBLE_CMD} -c "${ANSIBLE_SIMUL_INVENTORY_EXEC}/playbook-test-serial_over_hostgroups.yml"

ansible-unit-b-playbook-mail-relay: ## ansible roles unit test: mail-postfix_relay
	${DOCKER_EXEC_ANSIBLE_CMD} -c "${ANSIBLE_SIMUL_INVENTORY_EXEC}/playbook-test-mail.yml"

