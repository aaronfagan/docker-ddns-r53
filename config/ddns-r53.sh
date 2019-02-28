#!/bin/bash

ZONE=""
DOMAIN=""
RECORD="A"
NS=""
TTL="300"

usage() {
	echo "
Usage:
	./$(basename "$0") [options]

Options:
	--zone 		Your Route53 Zone ID. REQUIRED.
	--domain 	The domain name to update. REQUIRED.
	--ns 		The name server to check records against.
	--ttl 		The TTL to set on the record, when udpating. DEFAULT = $TTL.

Example:
	./$(basename "$0") \\
	--zone 123456789 \\
	--domain www.example.com \\
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
		--ns)
			NS="${2:-$NS}"
			shift
			shift
		;;
		--ttl)
			TTL="${2:-$TTL}"
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
	"Comment": "Dynamic DNS Update",
	"Changes": [
		{
			"Action": "UPSERT",
			"ResourceRecordSet": {
				"Name": "$DOMAIN",
				"Type": "A",
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
	if [ -z "$ZONE" ]; then echo -e "\033[0;31mERROR:\033[0;37m --zone is required.\033[0m"; fi
	if [ -z "$DOMAIN" ]; then echo -e "\033[0;31mERROR:\033[0;37m --domain is required.\033[0m"; fi
	usage
else
	if [ "$IP" = "$DNS" ]
	then
		echo "[$(date +'%F %T')] "$DOMAIN" - Update not required."
	else
		echo -n "[$(date +'%F %T')] "$DOMAIN" - Updating..."
		echo $JSON > ${0%.*}.json
		aws route53 change-resource-record-sets --hosted-zone-id $ZONE --change-batch file://${0%.*}.json &> ${0%.*}.log
		ERROR=`cat ${0%.*}.log`
		rm -f ${0%.*}.json ${0%.*}.log
		echo "done!"
	fi
fi
