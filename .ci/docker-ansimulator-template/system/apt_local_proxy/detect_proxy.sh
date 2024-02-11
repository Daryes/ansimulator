#!/bin/bash
#
# https://www.blog-libre.org/2016/01/09/installation-et-configuration-de-apt-cacher-ng/
# Detecte si le proxy est disponible et affiche le resultat 
# pour Acquire::http::Proxy-Auto-Detect du fichier /etc/apt/apt.conf.d/01proxy-aptng
#
# 2016/01/09	(AHZ) creation
#

# Requiers netcat & APT v1.5+ pour permettre l'usage de https avec Proxy-Auto-Detect dans la conf apt

### Variables ###
declare -A PROXY_PROTO PROXY_IP PROXY_PORT

# Proxy http - apt-cacher-ng
PROXY_PROTO[http]=http
PROXY_IP[http]=deb-cache.domain.tld
PROXY_PORT[http]=3142

# Proxy https - option si different
PROXY_PROTO[https]=http
PROXY_IP[https]=deb-cache.domain.tld
PROXY_PORT[https]=3142

# proto par defaut
ARG_PROTO="http"

#----------------------------------------------------------
# extraction du protocole depuis le param recu
[ ! -z "$1" ] && echo "$1" | grep -q '://' && ARG_PROTO=$( echo "$1" | sed -nr 's,^(.*://).*,\1,p' | cut -d ':' -f1 )

### Detection du proxy et affichage sur la sortie standard ###
nc -zw1 ${PROXY_IP["$ARG_PROTO"]}  ${PROXY_PORT["$ARG_PROTO"]} && echo ${PROXY_PROTO["$ARG_PROTO"]}://${PROXY_IP["$ARG_PROTO"]}:${PROXY_PORT["$ARG_PROTO"]}/ || echo DIRECT


