#!/bin/bash
set -e

ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
echo "$TZ" > /etc/timezone && \
dpkg-reconfigure -f noninteractive tzdata > /dev/null 2>&1

VARS_REQUIRED=(
    AWS_KEY
    AWS_SECRET
    AWS_REGION
    R53_ZONE
    R53_DOMAINS
)

for VAR in "${VARS_REQUIRED[@]}"; do
    if [ -z "${!VAR}" ]; then
    	echo "ERROR: Required variable \"${VAR}\" is not set!";
    	VAR_ERROR=true;
    fi
done
if [ "${VAR_ERROR}" ]; then exit 1; fi

aws configure set aws_access_key_id ${AWS_KEY}
aws configure set aws_secret_access_key ${AWS_SECRET}
aws configure set default.region ${AWS_REGION}
aws configure set default.output json
cp -rfun /opt/config/ddns-r53.sh /root/ddns-r53.sh
chmod +x -R /root/ddns-r53.sh

R53_ZONE=$(echo ${R53_ZONE} | tr a-z A-Z)
R53_TYPE=$(echo ${R53_TYPE} | tr a-z A-Z)
R53_NS=$(echo ${R53_NS} | tr A-Z a-z)

for DOMAIN in $(echo ${R53_DOMAINS} | sed -e "s/,/ /g" -e "s/  / /g"); do
	DOMAIN=$(echo ${DOMAIN} | tr A-Z a-z)
	FILENAME="ddns-${DOMAIN//./-}"
	echo "${CRON} root /root/ddns-r53.sh --zone ${R53_ZONE} --domain ${DOMAIN} --type ${R53_TYPE} --ttl ${R53_TTL} --ns ${R53_NS} > /proc/1/fd/1" > /etc/cron.d/${FILENAME}
done

service cron start > /dev/null 2>&1

echo "[$(date +'%F %T')] DDNS is running!"

for DOMAIN in $(echo ${R53_DOMAINS} | sed -e "s/,/ /g" -e "s/  / /g"); do
    bash /root/ddns-r53.sh --zone ${R53_ZONE} --domain ${DOMAIN} --type ${R53_TYPE} --ttl ${R53_TTL} --ns ${R53_NS} > /proc/1/fd/1
done

# KEEP CONTAINER RUNNING
exec $(which tail) -f /dev/null
