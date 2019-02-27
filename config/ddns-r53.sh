#!/bin/bash

usage() {
	echo "
Usage:
	./$(basename "$0") [options]

Options:
	--zone 		ROUTE53_ZONE_ID (Required).
	--domain 	DOMAIN_NAME (Required).
	--ns 		NAME_SERVER (Optional).
	--ttl 		NUMBER (Optional, Default = $TTL).

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
