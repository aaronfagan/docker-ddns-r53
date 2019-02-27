#!/bin/bash

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

ZONE=""
DOMAIN=""
RECORD="A"
NS=""
TTL="300"
ERROR=false

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
			usage 0
		;;
		*) 
			INVALID+=("$1")
			shift
			echo -e "\nInvalid arguement: $INVALID"
			usage 1
		;;
	esac
done

[ -z "$ZONE" ] && echo "ERROR: --zone is required." && ERROR=true;
[ -z "$DOMAIN" ] && echo "ERROR: --domain is required." && ERROR=true;
if [ "$ERROR" = true ]; then
   exit 1;
fi

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
	echo -e "\033[0;31m*** ERROR ***\033[0;37m Required arguements are missing.\033[0m"
	usage 1
else
	if [ "$IP" = "$DNS" ]
	then
		echo "Update not required."
	else
		echo -n "Updating..."
		echo $JSON > ${0%.*}.json
		aws route53 change-resource-record-sets --hosted-zone-id $ZONE --change-batch file://${0%.*}.json &> ${0%.*}.log
		ERROR=`cat ${0%.*}.log`
		rm -f ${0%.*}.json ${0%.*}.log
		echo "done!"
		if [[ "$ERROR" =~ "error" ]]
		then
			echo -en "\033[0;31m*** ERROR ***\033[0;37m"$ERROR"\033[0m\n"
			exit 1
		fi
	fi
fi
