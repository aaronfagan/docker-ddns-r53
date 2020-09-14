#!/bin/bash
set -e

VARS_REQUIRED=(
    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    AWS_DEFAULT_REGION
    R53_ZONE
    R53_DOMAINS
    TZ
)

for VAR in "${VARS_REQUIRED[@]}"; do
    if [ -z "${!VAR}" ]; then
    	echo "ERROR: Required variable \"${VAR}\" is not set!";
    	VAR_ERROR=true;
    fi
done
if [ "${VAR_ERROR}" ]; then exit 1; fi

ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
echo "${TZ}" > /etc/timezone && \
dpkg-reconfigure -f noninteractive tzdata > /dev/null 2>&1

[ "${AWS_ACCESS_KEY_ID}" ] && aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID}
[ "${AWS_SECRET_ACCESS_KEY}" ] && aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY}
aws configure set default.region ${AWS_DEFAULT_REGION}
aws configure set default.output json

R53_ZONE=$(echo ${R53_ZONE} | tr a-z A-Z)
R53_TYPE=$(echo ${R53_TYPE} | tr a-z A-Z)
R53_NS=$(echo ${R53_NS} | tr A-Z a-z)

for DOMAIN in $(echo ${R53_DOMAINS} | sed -e "s/,/ /g" -e "s/  / /g"); do
	DOMAIN=$(echo ${DOMAIN} | tr A-Z a-z)
	FILENAME="ddns-r53-${DOMAIN//./-}"
	echo "${CRON} root /root/src/ddns-r53.sh --zone '${R53_ZONE}' --domain '${DOMAIN}' --type '${R53_TYPE}' --ttl '${R53_TTL}' --ns '${R53_NS}' > /proc/1/fd/1" > /etc/cron.d/${FILENAME}
done

service cron start > /dev/null 2>&1

echo "[$(date +'%F %T')] DDNS is running!"

# KEEP CONTAINER RUNNING
exec $(which tail) -f /dev/null
