#!/usr/bin/env bash
set -e

HEALTH_FILE="/tmp/last-run"

set_env_var() {
  local var="$1"
  local file_var="${var}_FILE"

  # Load from file if present (takes precedence)
  if [[ -n "${!file_var:-}" ]]; then
    if [[ ! -r "${!file_var}" ]]; then
      echo "Error: ${file_var} is set but file is not readable" >&2
      exit 1
    fi
    export "$var"="$(tr -d '\r\n' < "${!file_var}")"
  fi

  # Final validation
  if [[ -z "${!var:-}" ]]; then
    echo "Error: $var is not set" >&2
    exit 1
  fi
}

force_update() {
    if [ "${FORCE_UPDATE}" == "true" ]; then
        echo --force-update
    fi
}

# Function to check SSL certificate expiry
check_ssl_expiry() {
    # Use timeout to prevent hanging in case of connection issues
    timeout 5 echo | openssl s_client -servername "${IPMI_DOMAIN}" -connect "${IPMI_DOMAIN}":443 2>/dev/null | \
        openssl x509 -noout -checkend 2592000
    return $?
}

set_env_var "IPMI_USERNAME"
set_env_var "IPMI_PASSWORD"
set_env_var "IPMI_DOMAIN"
set_env_var "LE_EMAIL"

PASSWORD_DISPLAY="******"
[[ -z "${IPMI_PASSWORD}" ]] && PASSWORD_DISPLAY="<empty>"

if ! [ -z ${DEBUG+x} ]; then
	set -x
fi

if [ -z ${FORCE_UPDATE+x} ]; then
        FORCE_UPDATE="false"
fi

# Check certificate expiry or force_update flag
if ! check_ssl_expiry || [ "${FORCE_UPDATE}" == "true" ]; then
    echo "Certificate is expiring within 30 days or FORCE_UPDATE is true. Renewing the certificate..."
else
    echo "Certificate is valid and FORCE_UPDATE is false. No need to renew."
    date +%s > "$HEALTH_FILE"
    exit 0
fi

# Sign the request and obtain a certificate
if [ -f ".lego/certificates/${IPMI_DOMAIN}.crt" ]; then
    /lego --key-type rsa2048 --server "${LE_SERVER-https://acme-v02.api.letsencrypt.org/directory}" \
          --email "${LE_EMAIL}" --dns "${DNS_PROVIDER:-route53}" --accept-tos --domains "${IPMI_DOMAIN}" renew
else
    /lego --key-type rsa2048 --server "${LE_SERVER-https://acme-v02.api.letsencrypt.org/directory}" \
          --email "${LE_EMAIL}" --dns "${DNS_PROVIDER:-route53}" --accept-tos --domains "${IPMI_DOMAIN}" run
fi

{ set +x; } 2>/dev/null
printf '%s ' \
    python3 supermicro-ipmi-updater.py --ipmi-url "https://${IPMI_DOMAIN}" \
    --cert-file ".lego/certificates/${IPMI_DOMAIN}.crt" --key-file ".lego/certificates/${IPMI_DOMAIN}.key" \
    --username "${IPMI_USERNAME}" --password "${PASSWORD_DISPLAY}" \
    --model "${MODEL:-X11}" "$(force_update)"
echo

python3 supermicro-ipmi-updater.py --ipmi-url "https://${IPMI_DOMAIN}" \
    --cert-file ".lego/certificates/${IPMI_DOMAIN}.crt" --key-file ".lego/certificates/${IPMI_DOMAIN}.key" \
    --username "${IPMI_USERNAME}" --password "${IPMI_PASSWORD}" \
    --model "${MODEL:-X11}" "$(force_update)"
set -x

date +%s > "$HEALTH_FILE"
