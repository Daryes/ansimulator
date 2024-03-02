# Ansimulator

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

