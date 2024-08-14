# Ansimulator


## Description

Ansimulator allows to simulate using containers a complete infrastructure with an ansible controller and multiple test servers.  
It has been structured to be used locally on your computer, under WSL, or on a server, and in a CI.

The ansible container has an access to the subdirectory `./ansible/` containing all roles and playbooks.  
Depending of docker versions, this directory can be a symlink, and will work as desired.  
A `test` directory is provided, with both a custom inventory and testing playbooks.

All containers can be reached using ssh, and have the necessary requirements allowing to have both systemd and Docker running together.  
Docker must be installed in the containers, and is supported on any Debian version, but only on Centos/Rocky/Alma 9+  
When terminated, the containers will be cleaned completely


---
## Documentation

Available topics :
* Usage (next section)
* [Requirements](doc/requirements.md)
* [Configuration](doc/config.md)
* [Appendix & faq](doc/appendix.md)


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


**IMPORTANT :**  

> You need to create a directory or simlink in the simulator root dir (aside the Makefile) named `ansible`

This directory will be mounted in the controller container as `/etc/ansible`  
It must contains at least the `ansible.cfg` file.  
If it is a simlink, it can be directed to your real ansible directory. 


**Regarding the Makefile ansible-unit- targets :**  

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

make help
# use sudo if your user is not a member of the docker group
make ansible-simul-docker-build
make ansible-simul-start
make ...
```


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
Most errors on validate means the containers are not started, or a problem occured with the generated ssh key, in the volume `ansible_simulator_sshkey`  
Other specific errors about `cd: /etc/ansible/: Permission denied` or `Ansible: Permission denied:` is related to the ansible directory used for the tests or the ansimulator structure missing a 755 mode on the directories. They must be world readable to be used from the containers.  


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
## Licence

Author: HAL - CC-BY-4.0

