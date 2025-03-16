#!/bin/bash
# retrieve the dind required ressources
#
# informations: 
# https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/
# https://hub.docker.com/_/docker/  => DinD


# source: https://github.com/docker/docker/tree/master/hack/dind
# alt :   https://github.com/moby/moby/blob/master/hack/dind
DIND_COMMIT=a2a6bf51fae014453a8f60058270a3a052e0e529
DIND_URL="https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind"

if command -v wget; then
    wget -O dind "${DIND_URL}"
    [ $? -ne 0 ] && exit 1

else
    curl "${DIND_URL}" --output dind
    [ $? -ne 0 ] && exit 1
fi

echo "Done"

