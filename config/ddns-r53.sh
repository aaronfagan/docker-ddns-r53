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
			exit 0
		;;
		*) 
			INVALID+=("$1")
			shift
			echo -e "\033[0;31mERROR:\033[0;37m Invalid arguement: $INVALID\033[0m"
			usage
			exit 0
		;;
	esac
done

ZONE=$(echo $ZONE | tr a-z A-Z)
DOMAIN=$(echo $DOMAIN | tr A-Z a-z)
TYPE=$(echo $TYPE | tr a-z A-Z)
NS=$(echo $NS | tr A-Z a-z)

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
				"Name": "$DOMAIN",
				"Type": "$TYPE",
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
	if [ -z "$ZONE" ]; then echo -ne "\033[0;31mERROR:\033[0;37m --zone arguement is required.\033[0m\n"; fi
	if [ -z "$DOMAIN" ]; then echo -ne "\033[0;31mERROR:\033[0;37m --domain arguement is required.\033[0m\n"; fi
	usage
	exit 0
else
	if [ "$IP" = "$DNS" ]
	then
		echo -ne "\033[0;37m[$(date +'%F %T')] $(echo $DOMAIN | tr A-Z a-z) - Update not required.\033[0m\n"
		exit 0
	else
		DIRNAME="./ddns-r53"
		FILENAME="${DIRNAME}/${DOMAIN//./-}_$(date +'%Y-%m-%d_%H-%M-%S_%N')"
		echo -ne "\033[0;37m[$(date +'%F %T')] $(echo $DOMAIN | tr A-Z a-z) - Updating..."
		echo $JSON > $FILENAME.json
		aws route53 change-resource-record-sets --hosted-zone-id $ZONE --change-batch file://$FILENAME.json &> $FILENAME.log
		grep 'error' $FILENAME.log > /dev/null 2>&1
		if [ $? != 0 ]
		then 
			echo -ne "success!\033[0m\n"
			rm -rf $DIRNAME
			exit 0
		else
			echo -ne "failed! $(grep 'error' ${0%.*}.log)\033[0m\n"
			rm -rf $DIRNAME
			exit 1
		fi
	fi
fi
