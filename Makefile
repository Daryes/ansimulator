.PHONY: no_targets__ all list help
.DEFAULT_GOAL=help
list: ## Show all the existing targets of this Makefile
	@sh -c "$(MAKE) -p no_targets__ 2>/dev/null | awk -F':' '/^[a-zA-Z0-9][^\$$#\/\\t=]*:([^=]|$$)/ {split(\$$1,A,/ /);for(i in A)print A[i]}' | egrep -v '(__\$$|^Makefile.*)' | sort -u"

help: ## Show the targets and their description (this screen)
	@grep --no-filename -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort -h | awk 'BEGIN {FS = ": .*?## "}; {printf "\033[36m%-40s\033[0m %s\n", $$1, $$2}'


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


# moved to an include file
include Makefile.conf


# build, start and stop targets ---------------------
ansible-simul-docker-build: ## build the ansible simulator docker images with ssh support - required one time when not using the docker hub images
	@# the version is retrieved from the compose.env
	@# the images are pulled instead of being stored into the builder cache which is volatile
	set -eux ;\
		source ${ANSIBLE_SIMUL_COMPOSE_ENV} ;\
		ANSIBLE_USER_UID=$$( stat --format "%u" . ) ;\
		if [ -z "$$ANSIBLE_USER_UID" ] || [ $$ANSIBLE_USER_UID -eq 0 ]; then ANSIBLE_USER_UID=421; fi ;\
		docker pull $$IMAGE_DEBIAN_REF_NAME:$$IMAGE_DEBIAN_REF_VERSION  ;\
		docker pull $$IMAGE_CENTOS_REF_NAME:$$IMAGE_CENTOS_REF_VERSION  ;\
		DOCKER_BUILDKIT=${DOCKER_BUILD_CMD_USE_BUILDKIT}  docker build -t $$IMAGE_CENTOS_CI --build-arg TARGET_DIST=redhat ${DOCKER_BUILD_CMD_COMMON_ARGS} ;\
		DOCKER_BUILDKIT=${DOCKER_BUILD_CMD_USE_BUILDKIT}  docker build -t $$IMAGE_DEBIAN_CI --build-arg TARGET_DIST=debian ${DOCKER_BUILD_CMD_COMMON_ARGS}


ansible-simul-docker-pull: ## pull the ansible simulator images from docker hub
	${ANSIBLE_SIMUL_COMPOSE_CMD} pull


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
	@# the error 130 happens on a normal logout when an error occured in the shell or when ctrl-c was pressed
	@${DOCKER_EXEC_ANSIBLE_INTERACTIVE} -l; if [ $$? -eq 130 ]; then exit 0; fi


ansible-simul-validate: ## verify the communication from ansible master to the other containers using ssh
	@${DOCKER_EXEC_ANSIBLE_CMD} -i -c "source ~/.bashrc; echo "" > ~/.ssh/known_hosts; exit 2>/dev/null"
	@${DOCKER_EXEC_ANSIBLE_CMD} -i -c "ansible --version; ANSIBLE_SSH_RETRIES=3 ansible --one-line -i ${ANSIBLE_SIMUL_INVENTORY_ON_SERVER} -m ping ${ANSIBLE_MASTER_INVENTORY_GROUP_ALL}"


ansible-tools-compat-v2_14-update-roles:  ## update roles for ansible-core 2.14+ deprecations
	@# remove all existing '  warn:' arguments which are not supported anymore on the modules 'command' and 'shell'
	@${DOCKER_EXEC_ANSIBLE_CMD} -c "egrep -ri '^ *  warn: .*' /etc/ansible/roles/*/{handlers,tasks,vars}/ | cut -d ':' -f1 |sort -u |xargs --no-run-if-empty sed -i '/^ *  warn: .*/d'"
	@echo "Roles updated"


# includes ------------------------------------------

-include Makefile.test-static
-include Makefile.test-unit


# Must be at the end
-include Makefile.override

# vim: noexpandtab filetype=make
