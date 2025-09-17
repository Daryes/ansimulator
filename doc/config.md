# Ansimulator

---
## Ansimulator configuration

The docker-compose .env file is located under the directory `.ci/`  
The makefile.conf file is located at the root of the ansimulator.


### Environment configuration

The simulator is controlled by the file `.ci/docker-compose.ansimulator.env`  

In this file are defined : 
* the Debian and Centos source images and version used to build the simulator

* the generated image names for the simulator

* the number of containers for each distribution. Currently set to 3 for centos, 1 for debian.  
  It is possible to change the amount of instance, or set one to `0` to disable the usage of a distribution.  
  The [linux] group in the host file `tests/ansible/inventory/hosts` from the inventory must be updated accordingly.  

* the listen IP for compose, which can allow to connect remotely to installed services on the containers.  
  The default setting restrict it to localhost.

* support for yum and apt proxy URL.  
  If set, they will be hardcoded into the images. You must rebuild them to change the proxy addresses

Aside the proxy setting, any change here will be applied after a -stop / -start.


### Connecting to a service running on a container

Standard case : connecting from your computer to a service using any http browser.  
The current configuration allows to connect to any service running in the containers on the port 80 or 443 only.  
ou'll need to update the .ci/docker-compose.ansimulator.env file and change the `DOCKER_HOST_IP` to the value `0.0.0.0`  
Please note the containers will be reachable by anybody. If you are on WSL, having 127.0.0.1 should be valid for your computer.  

In addition, the mapped port on docker side will be at random, due to using the docker's "deploy" module.  
First, verify in the hosts file on which container your service is installed. (or the reverse proxy service, if used).  
Then, with `docker ps` write down the port mapped on this container to `->80/tcp` or `443/tcp` depending of your configuration, which might be in the 31000-33000 range.  
You can then connect to your service with : `http(s)://<my_host_ip_or_name>:<external_docker_port>`

A last thing : depending of the configuration, a service might expect a specific name. In such case, edit in the playbook or the inventory the external url parameter.  
For example:
* grafana : while a configuration for a reverse proxy exists for the same container, the test configuration for grafana is listening on 0.0.0.0.  
  So either changing `grafana_server_name` to your hostname (the nginx playbook must be executed)  
  or `grafana_listen_port` to 80 in the inventory file `tests/ansible/inventory/group_vars/monitoring-server/grafana` will allow a direct connection after executing the monitoring playbook another time.
  
* rundeck : no reverse proxy is defined, the configuration has a preset similar to the initial values.  
  Change in the playbook `tests/ansible/playbook-test-rundeck.yml` the parameter `rundeck_url_full` to the correct hostname and port and re-execute the playbook.


### Volume structure

The following volume will be created or mounted :
* on the ansible controller :
  * ./ansible/ : mounted as /etc/ansible, RO or RW (default) depending of the setting in the .env file  
  * ./ : mounted as /opt/repo, RO
  * ./tests/ansible : mounted as /opt/ansible, RW. Contains the test playbooks and inventory.

* on all containers :
  * ansible_simulator_sshkey (volume) : mounted as /home/ansible/.ssh, RW. This allows ansible to connect on all other containers using ssh. 
  * ansible_simulator_temp_docker_vol (volume) : mounted as /var/lib/docker, RW.  
    Using Docker in Docker requires such volume.  
    Please note this volume is deleted by the makefile when using the target ansible-simul-stop.


The custom inventory is placed under `tests/ansible/inventory`, which will be available as `/opt/ansible` on the ansible controller.


### Roles compatibility between ansible v2.9 and v2.14+

If you're using the ansible-role repository, the roles are fully compatible between both versions.  
Still, as one deprecated argument for the "command" and "shell" modules has been completely blocked since ansible 2.14+, the roles cannot be executed immediately.  
If the desired version is not ansible v2.9, execute the command : `make ansible-tools-compat-v2_14-update-roles`  
It will simply chain a grep on the `warn: false` argument in the files, then apply sed to delete the lines. 

While this command requires a running ansimulator (any version), it can be copied from the makefile and applied manually on the roles.

Notice: the syntax variant on a single line is not supported, like : `shell: <my command and args>  warn=false `


---
## Licence

Author: HAL - CC-BY-4.0

