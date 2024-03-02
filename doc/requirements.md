# Ansimulator

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
## Licence

Author: HAL - CC-BY-4.0

