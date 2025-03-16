#!/bin/bash
# Ansible managed: do not edit directly - /server/ansible/conf/roles/init-server_config/templates//etc/apt/detect_proxy.sh.j2 - on hephaistos
#
# Original idea : https://www.blog-libre.org/2016/01/09/installation-et-configuration-de-apt-cacher-ng/
# Detect if the proxy server is available
#
# 2016/01/09	(AHZ) creation
#

# Usage : detect_proxy.sh <http|https>
# The proxy ip (or dns) and port are statically defined in the .conf file
# Most of the errors with still output the "DIRECT" message to allow apt to continue working


# Requirements: netcat-openbsd + APT v1.5+ (for https usage with Proxy-Auto-Detect parameter for apt)
# The following file is also required : "/etc/apt/apt.conf.d/01proxy-aptng"
# With this content :
#   Acquire::http::Proxy-Auto-Detect "/etc/apt/detect_proxy.sh";
#   Acquire::https::Proxy-Auto-Detect "/etc/apt/detect_proxy.sh";


### Variables ###
declare -A PROXY_PROTO PROXY_IP PROXY_PORT

# default protocol
ARG_PROTO="http"

# common error message suffix
MSG_ERR_SUFFIX="- the proxy will be bypassed"


# config file location
CONFIG_FILE_LOC1="${0/.sh*/.conf}"
CONFIG_FILE_LOC2="/etc/default/apt-detect-proxy.conf"


# load the config file
if [ -r "${CONFIG_FILE_LOC1}" ]; then
  source "${CONFIG_FILE_LOC1}"  || exit 2

elif [ -r ${CONFIG_FILE_LOC2} ]; then
  source "${CONFIG_FILE_LOC2}"  || exit 2

else
  echo "WARNING: the configuration file was not found in ${CONFIG_FILE_LOC1} or ${CONFIG_FILE_LOC2} $MSG_ERR_SUFFIX" >&2
  echo DIRECT
  exit 0
fi


# Proxy http - apt-cacher-ng
# separated protocols to allow different settings
PROXY_PROTO[http]="${PROXY_PROTO_HTTP}"
PROXY_IP[http]="${PROXY_IP_HTTP}"
PROXY_PORT[http]="${PROXY_PORT_HTTP}"

PROXY_PROTO[https]="${PROXY_PROTO_HTTPS:-PROXY_PROTO_HTTP}"
PROXY_IP[https]="${PROXY_IP_HTTPS:-PROXY_IP_HTTP}"
PROXY_PORT[https]="${PROXY_PORT_HTTPS:-PROXY_PORT_HTTP}"


# some bashism - should be after the validations
# extract proto from the received arguments and convert it in lowercase
ARG_PROTO="${1,,}"
# remove any "://*" from the parameter
ARG_PROTO="${ARG_PROTO%://*}"


#----------------------------------------------------------
# requirements and parameter validations
# they must not be blocking, return "DIRECT" in case of an error
if ! command -v nc &>/dev/null; then echo "WARNING: ${0} requires netcat-openbsd $MSG_ERR_SUFFIX" >&2; echo DIRECT; exit 0; fi
if [[ $# -eq 0  || ( "$ARG_PROTO" != "http"  &&  "$ARG_PROTO" != "https" ) ]]; then echo -e "WARNING: ${0} called with an unsupported parameter $MSG_ERR_SUFFIX\nSyntax: $0 http|https " >&2; echo DIRECT; exit 0; fi


# detect the proxy availability and ouput the final command: either the proxy full url or DIRECT when not available
if nc -zw1 ${PROXY_IP[$ARG_PROTO]}  ${PROXY_PORT[$ARG_PROTO]}; then
  echo "${PROXY_PROTO[$ARG_PROTO]}://${PROXY_IP[$ARG_PROTO]}:${PROXY_PORT[$ARG_PROTO]}/"

else
  echo "WARNING: the proxy '${PROXY_IP[$ARG_PROTO]}  ${PROXY_PORT[$ARG_PROTO]}' for $ARG_PROTO is not reachable $MSG_ERR_SUFFIX" >&2
  echo DIRECT
  exit 0
fi

