FROM ubuntu:18.04

ENV CRON="0 * * * *"
ENV R53_TYPE="A"
ENV R53_TTL="3600"

RUN apt-get update && \
	apt-get install -y \
		awscli \
		cron \
		curl \
		dnsutils \
		nano \
		software-properties-common
		
COPY ./config /opt/config
COPY ./config/entrypoint.sh /sbin/entrypoint.sh

RUN chmod 755 /sbin/entrypoint.sh

ENTRYPOINT ["/sbin/entrypoint.sh"]

CMD ["/usr/bin/bash"]
