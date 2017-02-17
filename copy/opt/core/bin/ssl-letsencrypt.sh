#!/usr/bin/env bash
# This script will generate a let's encrypt ssl certificate if possible.
# It's a simple wrapper script for the official certbot client, because
# we maybe need the webserver feature to receive a validation.

# Defaults
CN=$(hostname)
EMAIL=$(mdata-get mail_adminaddr 2>/dev/null)

# Ignore python warnings by default in this script
export PYTHONWARNINGS="ignore"

# Help function
function help() {
	echo "${0} [-c common name] [-m mail address]"
	exit 1
}

# Option parameters
while getopts ":c:m:" opt; do
	case "${opt}" in
		c) CN=${OPTARG} ;;
		m) EMAIL=${OPTARG} ;;
		*) help ;;
	esac
done

# Setup account email address to mail_adminaddr if exists
if [[ ! -z ${EMAIL} ]]; then
	EMAIL="--email ${EMAIL}"
else
	EMAIL='--register-unsafely-without-email'
fi

# Run initial certbot command to create account and certificate
if ! certbot certonly \
	--standalone \
	--agree-tos \
	--quiet \
	--text \
	--non-interactive \
	${EMAIL} \
	--domains ${CN}; then
	# Exit on error and ignore crons
	exit 1
fi

# Create empty hook scripts by default
touch /opt/local/etc/letsencrypt/{pre,post,renew}-hook.sh
chmod 700 /opt/local/etc/letsencrypt/*-hook.sh

# Create cronjob to automatically check or renew the certificate two
# times a day
CRON='0 0,12 * * * /opt/local/bin/certbot renew --text --non-interactive --quiet --pre-hook "/opt/local/etc/letsencrypt/pre-hook.sh" --post-hook "/opt/local/etc/letsencrypt/post-hook.sh" --renew-hook "/opt/local/etc/letsencrypt/renew-hook.sh"'
(crontab -l 2>/dev/null || true; echo "$CRON" ) | sort | uniq | crontab