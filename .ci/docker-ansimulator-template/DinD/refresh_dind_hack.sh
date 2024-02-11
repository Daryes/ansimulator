#!/bin/bash
# retrieve the dind required ressources
#
# informations: 
# https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/
# https://hub.docker.com/_/docker/


# source: https://github.com/docker/docker/blob/master/hack/dind / alt : https://github.com/moby/moby/blob/master/hack/dind

DIND_COMMIT=d58df1fc6c866447ce2cd129af10e5b507705624/hack/dind

wget -O dind "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind"
[ $? -ne 0 ] && exit 1

chmod +x dind

echo "Done"
