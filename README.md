# Ansimulator


## Description

Ansimulator allows to simulate using containers  a complete infrastructure contaning an ansible controller and multiple test servers.  
It has been structured to allow being used locally on your computer, under WSL, or on a server, and in a CI.

The ansible container has an acces to the subdirectory `./ansible/` containing all roles and playbooks.  
Depending of docker versions, this directory can be a symlink, and will work as desired.  
A `test` directory is provided, with both a custom inventory and testing playbooks.

All containers can be reached using ssh, and have the necessary requirements allowing to have both systemd and Docker running together.  
Docker must be installed in the containers, and is supported on any Debian version, but only on Centos/Rocky/Alma 9+  
When terminated, the containers will be cleaned completely


---
## Requirements

On the system, the following modules must be present:  
* docker => https://docs.docker.com/get-docker/  
  WSL2 is supported => https://docs.docker.com/desktop/windows/wsl/
  
* docker-compose v2.x => https://github.com/docker/compose  

* the possibility to retrieve images from hub.docker.com (both Debian and Rocky Linux)

* The system package `make`

* (optional) Your main user set as a member of the docker group to alleviate the usage of the `sudo` command.  
  Create the docker group : `sudo groupadd docker`  
  Add your user to this group : `sudo usermod --append --groups docker <user>`  
  
* If WSL2 is the current environment, either a recent version supporting systemd natively, or report to the systemd appendix about the script `setup_support_systemd.sh`

Ansible itself is installed in the container, it is not required to install it locally.


---
## Usage

All actions are controlled using the `Makefile`.  
To list all the targets and their help, at the simulator root, simply use the command :
```
make
```

The usual usage sequence using `make` is :  
* ansible-simul-start
* ansible-simul-validate
* and either `ansible-simul-connect` or running some of the `ansible-unit-*` target.  

Then `ansible-simul-stop` when done to shut down the containers.


To launch manually a playbook, follow this sequence : 
```
ansible-simul-connect
ansible-playbook -i /opt/repo/tests/ansible/inventory  /opt/repo/tests/ansible/<test playbook>.yml
```

**IMPORTANT:** 
The simulator by itself will not do much, you need to create a directory or simlink in the simulator root dir (aside the Makefile) named `ansible`  
If it is a simlink, it can be directed to your real ansible directory. It must contains at least the `ansible.cfg` file.  
This directory will be mounted in the controller container as `/etc/ansible`

To use the multiple `ansible-unit-*` target, clone the ansible-roles repository, and make sure the final directory is named (or linked to) `ansible`


### First run

For a first installation, execute :                                                               
(Notice : if running under WSL2, you need to activate systemd support first)
```
make ansible-simul-docker-build
```  
This step will take some minutes to create the 2 images for the Debian and Centos containers used by the simulator.  
Both Debian and Rocky Linux official images will be used and retrieved from dockerhub.  
When the images have been created, using this step is not required anymore.


### Starting the simulator and common usage

To start the containers :
```
make ansible-simul-start

# only for the first time
make ansible-simul-validate
```
Any error on validate means the containers are not started, or a problem occured with the generated ssh key, in the volume `ansible_simulator_sshkey`  


To connect to the ansible controller :
```
make ansible-simul-connect
```

Any started container can be reached from the ansible container using the container name.  
For example, to connect to ci-test-debian-1, simply use : `ssh ci-test-debian-1`  

Notice : aside the ansible container, all other containers will only show the docker generated ID for their hostname.  
This is a limitation of the deploy module from Docker, and cannot actually be changed.

### Executing the tests

Use the `make` command to list the possible targets.  
All the tests can be executed with :
```
ansible-unit-<desired target>
```
It is highly possible the tab key for completion is usable with Make.


The ansible's `--diff` mode activated by default in the Makefile can be disabled with :
```
ansible-unit-<target>  DIFF=""
```
Notice: you can use DIFF to pass other arguments to ansible.


### Stop the simulator

This will stop and remove the containers, cleaning everything which was installed on them.
```
make ansible-simul-stop
```
This will also delete the docker volume `ci_ansible_simulator_temp_docker_vol` to prevent an unwanted growth in disk usage.


---
## Ansimulator configuration

All the images and docker-compose files are located under the directory `.ci/`  


### Environment configuration

The simulator is controlled by the file `.ci/docker-compose.ansimulator.env`  

In this file are defined : 
* the Debian and Centos source images and version used to build the simulator

* the generated image names for the simulator

* the number of containers for each distribution. Currently set to 4 for centos, 1 for debian.  
  It is possible to change the amount of instance, or set one to `0` to disable the usage of a distribution.  
  The [linux] group in the inventory file `tests/ansible/inventory/hosts` must be updated accordingly.  

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

In addition, the mapped port on docker side will be at random, due to using docker deploy.  
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
  * ./ansible : mounted as /etc/ansible, RO or RW (default) depending of the setting
  * ./ : mounted as /opt/repo, RO
  * ./tests/ansible : mounted as /opt/ansible, RW. Contains the test playbooks and inventory.

* on all containers :
  * ansible_simulator_sshkey (volume) : mounted as /home/ansible/.ssh, RW. This allows ansible to connect on all other containers using ssh. 
  * ansible_simulator_temp_docker_vol (volume) : mounted as /var/lib/docker, RW.  
    Using Docker in Docker requires such volume.  
    Please note this volume is deleted by the makefile when using the target ansible-simul-stop.


The custom inventory is placed under `tests/ansible/inventory`, which will be available as `/opt/ansible` on the ansible controller.


### Updating the images and changing Ansible version

The name and tag for the images are located in the `.ci/docker-compose.ansimulator.env` file.

The Dockerfile is located under `.ci/docker-ansimulator-template/`  
It is the same for both Debian and Centos (Rocky) images.

The full configuration is not as usual, some elements like the module versions to deploy are still in the Dockerfile.  
But due to the number of packages to install and configure, which are necessary to simulate a complete server, most of the commands are splitted under multiple directories, one per theme.  
Each contains an install.sh file, with all the commands, and additional configuration files.  

For example, to simply change the version to install for ansible, just the Dockerfile is enough, at the ansible section.  
But if you want to fine-tune some system packages or the installation of ansible, look under `.ci/docker-ansimulator-template/system/`  or `...template/ansible/` directory.  

Please note using python 3.9 on rhel/centos/rocky/alma release 8 raise multiple problems due to missing package variants for python 3.9.  
As such, switching from ansible 2.9 to ansible 2.15 will requires to change the distribution release 8 to release 9.  
Such restruction will be present, while less noticeable, for any distribution using a global python version different from the default one.

To resume, to change ansible version from 2.9 to 2.15, you need to set the new version in the Dockerfile, and change in the docker-compose.ansimulator.env the IMAGE_CENTOS_REF_VERSION from 8.x to 9.x


### Roles compatibility between ansible v2.9 and v2.15

The roles are fully compatible between both versions.  
Still, as one deprecated argument for the "command" and "shell" modules has been completely blocked since ansible 2.14+, the roles cannot be executed immediately.  
If the desired version is not ansible v2.9, execute the command : `make ansible-tools-compat-v2_14-update-roles`  
It will simply chain a grep on the `warn: false` argument in the files, then apply sed to delete the lines. 
The variant `shell: <my command and args>  warn=false` is not supported.

While this command requires a running ansimulator (any version), it can be copied from the makefile and applied manually on the roles.

Notice: the syntax variant on a single line is not supported, like : `shell: <my command and args>  warn=false `


---
## Appendix

### Systemd in WSL

Since October 2022, systemd is natively supported by WSL2 (v 0.67.6). The related documentation is available at [Microsoft site](https://learn.microsoft.com/en-us/windows/wsl/systemd)

As an alternative, the following script is available with the simulator :
```
# generate systemd logical environment
sudo .ci/wsl/setup_support_systemd.sh
```
It must be launched each time WSL is started, so add it to your .profile.

As such, you can find a sudoers file example under `etc-sudoers.d-docker.template`, which must be replicated under `/etc/sudoers.d/docker`  (use `visudo`).  
Adjust the integrated path to the setup_host_systemd.sh script.

Then, add the following lines in your `.profile` : 
```
# launch docker
if ! service docker status >/dev/null; then sudo service docker start; fi

# systemd simulation for docker images
sudo /path/to/.ci/wsl/setup_host_systemd.sh
```
This will allow you to have both docker and systemd started in WSL2 each time it has been stopped.


### Docker in docker

DinD is supported on Debian (all recent versions), but for RHEL/Centos, the 9 release is mandatory due to a missing library preventing Docker to start in a container on lower releases.  

Also, this file `tests/ansible/inventory/group_vars/sys-docker` must be updated to prevent any network conflict :   
change the parameter `docker_config_default_address_pools => base` and set a network range which your computer is not using.  
This range will be used by docker for its internal networks in the containers.  
Using a network in "10.x.0.0/16" or "192.168.0.0/16" is suggested, as long as it differs from those used by your own networks.  

To summarize : 
* computer : x.x.x.x
* wsl : 172.x.x.x.
* docker : 172.x.x.x (default - can create some conflicts)
* docker in docker : must differ from all others.


### Errors when building an image

Aside some real mistake, it is usually caused by a DNS error (it's always DNS).  
In fact, this is mostly due to a conflict between the host IP (or WSL), and the network range used by Docker.  
If you're using WSL, just restarting it will be enough for a temporary fix : `wsl --shutdown`

A more definitive solution is to edit the file `/etc/docker/daemon.json` on your host (or WSL) with those lines :  
(adapt to use an unused network range)
```
{
  "bip": "192.168.200.1/24"
}
```

This is the configuration for the [default bridge network](https://docs.docker.com/network/drivers/bridge/) created by Docker.  

When updated, restart docker (or WSL).


### Using Centos or Debian for the ansible controller

This cannot be set using a variable and must be changed directly in the compose file.  
Edit the file `.ci/docker-compose.ansimulator.yml`
```
services:
  ansible-master:
    <<: *img-debian
```
Replace `img-debian` with `img-centos` or the opposite.  
Then, a make -stop / -start is enough, as both Centos and Debian simulator images have Ansible installed on them.  
The Ansible controller is in fact one of the containers with extra settings on docker side.


---
## Licence

Author: HAL - CC-BY-4.0

