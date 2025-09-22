# Ansimulator


## Description

Ansimulator allows to simulate using containers a complete infrastructure with an ansible controller and multiple test servers.  
It has been structured to be used locally on your computer, under WSL, or on a server, and in a CI.

The ansible container has an access to the subdirectory `./ansible/` containing all roles and playbooks.  
Depending of docker versions, this directory can be a symlink, and will work as desired.  
A `test` directory is provided, with both a custom inventory and testing playbooks.

All containers can be reached using ssh, and have the necessary requirements allowing to have both systemd and Docker running together.  
Docker can be installed in the containers and will be fully usable. This is supported on any Debian version, but Centos/Rocky/Alma will requires at least 9+.  

When terminated, the containers will be cleaned completely.


---
## Documentation

Available topics :
* Usage (next section)
* [Changelog](https://github.com/Daryes/ansimulator/tags) - available in the tag descriptions.
* [Requirements](doc/requirements.md) (dedicated page)
* [Configuration](doc/config.md) (dedicated page)
* [Building the images](doc/build.md) (dedicated page)
* [Appendix & faq](doc/appendix.md) (dedicated page)


---
## Usage

All actions are controlled using the `Makefile`.  
To list all the targets and their help, at the simulator root directory, simply use the command : `make`  
An integrated help is available for each command.


To start the simulator, the usual usage sequence using `make` is :  
* `make ansible-simul-start`
* `make ansible-simul-validate`
* and either `make ansible-simul-connect` or running some of the `make test-unit-*` target.  

Then `make ansible-simul-stop` when done to shut down the containers.

NOTICE: given the commands will make use of docker and docker-compose, the current user must either be in the `docker` group,  
or have sudoers rights. In such case, then use `sudo` in front of the `make` commands.


To launch manually a playbook, follow this sequence : 
```
make ansible-simul-connect
ansible-playbook -i /opt/repo/tests/ansible/inventory  /opt/repo/tests/ansible/<test playbook>.yml
```


**IMPORTANT :**  

> You need to create a directory or simlink in the simulator root dir (aside the Makefile) named `ansible`

This directory will be mounted in the controller container as `/etc/ansible`  
It must contains at least the `ansible.cfg` file.  
If it is a simlink, it can be directed to your real ansible directory. 


### Regarding the Makefile test-unit- targets  

They are designed to work with the [ansible-roles](https://github.com/Daryes/ansible-roles) repository.  

You can study them, or try them directly. For this, clone the ansible-roles repository in a separate directory,  
then create a symlink in the simulator root named `ansible` targeting the ansible-roles root directory.  
To put it simply :  
```
cd myworkdir/
git clone https://github.com/Daryes/ansimulator.git
git clone https://github.com/Daryes/ansible-roles.git
cd ansimulator
ln -s $( readlink -f ../ansible-roles ) ansible

# notice : if you plan to connect remotely on the service,
# you need to edit the file '.ci/docker-compose.ansimulator.env' and change the listen IP

# list the available commands
make help

# use sudo if your user is not a member of the docker group
make ansible-simul-docker-pull
make ansible-simul-start
make ansible-simul-validate
make ...
```

Notice: the provided inventory uses `-` in the group names on purpose, ensuring explicit access to them and prevent any variable conflict.  
Ansible will raise a non-blocking warning about it, which can be hidden by adding this line to the ansible.cfg file,  [defaults] section : `force_valid_group_names = ignore`


## First run

For a first installation, execute :                                                               
(Notice : if running under WSL2, you need to activate systemd support first)
```
make ansible-simul-docker-pull
```  
It will retrieve from dockerhub the 2 images for the Debian and Centos containers used by the simulator.  

Notice : If you want to change the ansible user UID, or add the use of a proxy for APT and DNF/YUM, you need to rebuild the images.  
See the dedicated documentation page for this.


## Starting the simulator and common usage

To start the containers :
```
make ansible-simul-start

make ansible-simul-validate
```
Most errors on validate means the containers are not started, or a problem occured with the generated ssh key, in the volume `ansible_simulator_sshkey`  
Other specific errors about `cd: /etc/ansible/: Permission denied` or `Ansible: Permission denied:` is related to the directory access.  
Either the ansible directory with the roles used for the tests, or the ansimulator structure is missing a 755 mode on the directories. They must be world readable to be used from the containers.  


To connect to the ansible controller :
```
make ansible-simul-connect
```

Any started container can be reached from the ansible container using the container name.  
For example, to connect to ci-test-debian-1, simply use : `ssh ci-test-debian-1`  

Notice : aside the ansible container, all other containers will only show the docker generated ID for their hostname.  
This is a limitation of the deploy module from Docker, and cannot actually be changed.


## Executing the tests

Use the `make` command to list the possible targets.  
All the tests can be executed with :
```
make test-unit-<desired target>
```
It is highly possible the tab key for completion is usable with Make.


The ansible's `--diff` mode is activated by default in the Makefile, and can be disabled with :
```
make test-unit-<target>  OPTS=""
```

Notice: you can use the OPTS parameter to pass other arguments to ansible.  
If you still need diff itself, use it like this : `make <target...> OPTS="--diff --tag ..."`


## Stop the simulator

This will stop and remove the containers, cleaning everything which was installed on them.
```
make ansible-simul-stop
```
This will also delete the docker volume `ci_ansible_simulator_temp_docker_vol`


---
## Licence

Author: HAL - CC-BY-4.0  
Thanks to C.C-E for the Makefile list / help trick

