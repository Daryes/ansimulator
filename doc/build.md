# Ansimulator

---
## Ansimulator image building

The images from Docker hub are already complete, but some elements can be fine-tuned if desired : 
* updating the Debian or Rocky version
* activating the use of a package proxy for APT and DNF/YUM
* changing the ansible user UID (currently set to 421)
* changing ansible-core version

All the docker-compose, dockerfile and other script files are located under the directory `.ci/`  

### building the images

After changing the desired configuration, the images can be built with the following command : 
(Notice : if running under WSL2, you need to activate systemd support first)

```
make ansible-simul-docker-build
```

This step will take some minutes to create the 2 images for the Debian and Centos containers used by the simulator.
Both Debian and Rocky Linux official images will be used and retrieved from dockerhub.
When the images have been created, using this step is not required anymore.

To alleviate any trouble for accessing the directories, the ansible user in the containers will reuse the owner UID of the Makefile directory.
As such, it is not recommended to have Root as the owner of the ansimulator files.


### Updating the reference versions for the system images

The name and tag for the images are located in the `.ci/docker-compose.ansimulator.env` file.

The simulator is controlled by the file `.ci/docker-compose.ansimulator.env`  
It contains most of the updatable settings.

When changing the sources images for Debian or Rocky, or setting the proxy for the system packages, the image must be rebuilt after.  
It is recommended to change also the `IMAGE_DEBIAN_CI` to prevent overwriting the custom images by a pull from docker hub.


### Changing Ansible version

The ansible version is located in the Dockerfile, which is under `.ci/docker-ansimulator-template/`
It is the same parameter for both Debian and Centos (Rocky) images.

The full configuration is not as usual, some elements like the module versions to deploy are still in the Dockerfile.
But due to the number of packages to install and configure, which are necessary to simulate a complete server, most of the commands are splitted under multiple directories, one per theme.
Each contains an install.sh file, with all the commands, and additional configuration files.

For example, to simply change the version to install for ansible, just the Dockerfile is enough, at the ansible section.
But if you want to fine-tune some system packages or the installation of ansible, look under `.ci/docker-ansimulator-template/system/`  or `...template/ansible/` directory.

Please note using python 3.9 on rhel/centos/rocky/alma release 8 raise multiple problems due to missing package variants for python 3.9.
As such, switching from ansible 2.9 to ansible 2.15 will requires to change the distribution release 8 to release 9.

To resume, to change ansible version from 2.9 to 2.15, you need to set the new version in the Dockerfile, and change in the docker-compose.ansimulator.env the IMAGE_CENTOS_REF_VERSION from 8.x to 9.x


---
## Licence

Author: HAL - CC-BY-4.0

