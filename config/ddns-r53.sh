#!/bin/bash

ZONE=""
DOMAIN=""
TYPE="A"
NS=""
TTL="3600"

usage() {
	echo "
Usage:
	./$(basename "$0") [options]

Options:
	--zone 		Your Route53 Zone ID. REQUIRED.
	--domain 	The domain name to update. REQUIRED.
	--type 		The DNS record type to update. DEFAULT = $TYPE.
	--ttl 		The TTL to set on the record, when udpating. DEFAULT = $TTL.
	--ns 		The name server to check records against.

Example:
	./$(basename "$0") \\
	--zone 123456789 \\
	--domain www.example.com \\
	--type A \\
	--ttl 1800 \\
	--ns ns1.example.com
	"
	exit $1
}

while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		--zone)
			ZONE="${2:-$ZONE}"
			shift
			shift
		;;
		--domain)
			DOMAIN="${2:-$DOMAIN}"
			shift
			shift
		;;
		--type)
			TYPE="${2:-$TYPE}"
			shift
			shift
		;;
		--ttl)
			TTL="${2:-$TTL}"
			shift
			shift
		;;
		--ns)
			NS="${2:-$NS}"
			shift
			shift
		;;
		--help)
			usage
		;;
		*) 
			INVALID+=("$1")
			shift
			echo -e "\033[0;31mERROR:\033[0;37m Invalid arguement: $INVALID\033[0m"
			usage
		;;
	esac
done

IP=$(curl https://checkip.amazonaws.com --silent)
if [ -n "$NS" ]
then
	DNS=$(dig $DOMAIN @$NS +short)
	if [ "$?" = "10" ]
	then
		DNS=$(dig $DOMAIN +short)
	fi
else
	DNS=$(dig $DOMAIN +short)
fi

JSON=$(cat <<EOF
{
	"Comment": "[$(date +'%F %T')] Dynamic DNS Update",
	"Changes": [
		{
			"Action": "UPSERT",
			"ResourceRecordSet": {
				"Name": "$(echo $DOMAIN | tr A-Z a-z)",
				"Type": "$(echo $TYPE | tr a-z A-Z)",
				"TTL": $TTL,
				"ResourceRecords": [
					{
						"Value": "$IP"
					}
				]
			}
		}
	]
}
EOF
)

if [ -z "$ZONE" ] || [ -z "$DOMAIN" ]
then
	if [ -z "$ZONE" ]; then echo -e "\033[0;31mERROR:\033[0;37m --zone arguement is required.\033[0m"; fi
	if [ -z "$DOMAIN" ]; then echo -e "\033[0;31mERROR:\033[0;37m --domain arguement is required.\033[0m"; fi
	usage
else
	if [ "$IP" = "$DNS" ]
	then
		echo "[$(date +'%F %T')] $(echo $DOMAIN | tr A-Z a-z) - Update not required."
	else
		echo -n "[$(date +'%F %T')] $(echo $DOMAIN | tr A-Z a-z) - Updating..."
		echo $JSON > ${0%.*}.json
		aws route53 change-resource-record-sets --hosted-zone-id $ZONE --change-batch file://${0%.*}.json &> ${0%.*}.log
		grep 'error' ${0%.*}.log > /dev/null 2>&1
		if [ $? != 0 ]; then printf "success!\n"; else printf "failed! $(grep 'error' ${0%.*}.log)\n"; fi
		#rm -f ${0%.*}.json ${0%.*}.log
	fi
fi
