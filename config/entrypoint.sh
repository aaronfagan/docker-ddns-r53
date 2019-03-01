#!/bin/bash
set -e

ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
echo "$TZ" > /etc/timezone && \
dpkg-reconfigure -f noninteractive tzdata > /dev/null 2>&1

unset VAR_ERROR
if [ -z "$AWS_KEY" ]; then echo 'ERROR: Required variable AWS_KEY is not set!'; export VAR_ERROR=1; fi
if [ -z "$AWS_SECRET" ]; then echo 'ERROR: Required variable AWS_SECRET is not set!'; export VAR_ERROR=1; fi
if [ -z "$AWS_REGION" ]; then echo 'ERROR: Required variable AWS_REGION is not set!'; export VAR_ERROR=1; fi
if [ -z "$R53_ZONE" ]; then echo 'ERROR: Required variable R53_ZONE is not set!'; export VAR_ERROR=1; fi
if [ -z "$R53_DOMAINS" ]; then echo 'ERROR: Required variable R53_DOMAINS is not set!'; export VAR_ERROR=1; fi
if [ -n "$VAR_ERROR" ]; then exit 1; fi

aws configure set aws_access_key_id $AWS_KEY
aws configure set aws_secret_access_key $AWS_SECRET
aws configure set default.region $AWS_REGION
aws configure set default.output $AWS_OUTPUT
cp -rfun /opt/config/ddns-r53.sh /root/ddns-r53.sh
chmod +x -R /root/ddns-r53.sh

echo "[$(date +'%F %T')] DDNS is running!"

R53_ZONE=$(echo $R53_ZONE | tr a-z A-Z)
R53_TYPE=$(echo $R53_TYPE | tr a-z A-Z)
R53_NS=$(echo $R53_NS | tr A-Z a-z)

for DOMAIN in $(echo $R53_DOMAINS | sed "s/,/ /g")
do
DOMAIN=$(echo $DOMAIN | tr A-Z a-z)
FILENAME="ddns-r53_${DOMAIN//./-}"
cat <<EOF >/etc/cron.d/$FILENAME
$CRON root /root/ddns-r53.sh --zone $R53_ZONE --domain $DOMAIN --type $R53_TYPE --ttl $R53_TTL --ns $R53_NS > /proc/1/fd/1
EOF
bash /root/ddns-r53.sh --zone $R53_ZONE --domain $DOMAIN --type $R53_TYPE --ttl $R53_TTL --ns $R53_NS > /proc/1/fd/1
done

service cron start > /dev/null 2>&1

# KEEP CONTAINER RUNNING
exec $(which tail) -f /dev/null
