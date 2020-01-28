# Dynamic DNS with Route 53
This image is an always-on solution to automatically update a Route 53 record set with your host IP address, at repeating intervals. Uses the AWS CLI, cron, and a shell script that checks if updates are required, and if so, executes them. If a domain does not already exist in your record set, it will be automatically created.

## Environment Variables
Variables without default are required.

**`AWS_ACCESS_KEY_ID`**
- Your IAM user key.

**`AWS_SECRET_ACCESS_KEY`**
- Your IAM user secret.

**`AWS_DEFAULT_REGION`**
- The AWS region your Route 53 hosted zone is in.

**`CRON`**
- **Default:** `0 * * * *` (Every hour)
- Standard cron format. How often to run the DNS update check.

**`R53_ZONE`**
- The ID of the target hosted zone in Route 53.

**`R53_DOMAINS`**
- The target domain name(s) to update.
- Comma separated list.

**`R53_TYPE`**
- **Default:** `A`
- The DNS record type for all target domain name(s).

**`R53_TTL`**
- **Default:** `3600`
- The TTL to set on the target domain.

**`R53_NS`**
- **Default:** Your ISP's DNS.
- The name server to check records against.


## IAM Policy (Example)
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:GetChange",
                "route53:ListHostedZonesByName"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": [
                "arn:aws:route53:::hostedzone/YOUR_HOSTED_ZONE_ID"
            ]
        }
    ]
}
```

# Contributors
* Aaron Fagan - [Github](https://github.com/aaronfagan), [Website](https://www.aaronfagan.ca/)
