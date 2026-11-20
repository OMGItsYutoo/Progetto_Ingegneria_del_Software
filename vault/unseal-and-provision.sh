#!/bin/sh
set -e

export VAULT_ADDR="http://vault:8200"

until vault status >/dev/null 2>&1 || [ $? -eq 2 ]; do
  sleep 1
done

# Richiede 2 Unseal Key interattivamente se Vault è Sealed
if vault status 2>&1 | grep -q "Sealed.*true"; then
  echo "=== VAULT SEALED: RICHIESTO QUORUM 2-SU-3 ==="
  for i in 1 2; do
    printf "Inserisci Unseal Key #%d (input nascosto): " "$i"
    stty -echo
    read -r SHARE
    stty echo
    printf "\n"
    vault operator unseal "$SHARE" >/dev/null
    unset SHARE
  done
  echo "Quorum raggiunto: Vault UNSEALED."
fi

# Autenticazione AppRole (privilegi minimi, nessun Root Token)
ROLE_ID=$(cat /vault/file/approle_role_id)
SECRET_ID=$(cat /vault/file/approle_secret_id)
CLIENT_TOKEN=$(vault write -field=token auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID")
export VAULT_TOKEN="$CLIENT_TOKEN"

# Iniezione password DB in RAM (/run/secrets)
vault kv get -field=db_password secret/ciuismeglchuan/db > /run/secrets/db_password
vault kv get -field=db_password secret/ciuismeglchuan/db > /run/secrets/spring.datasource.password
vault kv get -field=db_root_password secret/ciuismeglchuan/db > /run/secrets/db_root_password
chmod 644 /run/secrets/db_password /run/secrets/spring.datasource.password /run/secrets/db_root_password

# Emissione certificato server (RSA 3072, 180gg) -> solo fullchain.crt + server.key in /certs
CERT_JSON=$(vault write -format=json pki_int/issue/ciuismeglchuan-server \
  common_name="localhost" \
  alt_names="localhost" \
  ip_sans="127.0.0.1" \
  ttl="4320h")

printf '%b' "$(printf '%s' "$CERT_JSON" | sed -n 's/.*"certificate": "\([^"]*\)".*/\1/p')" > /tmp/server.crt
printf '%b' "$(printf '%s' "$CERT_JSON" | sed -n 's/.*"issuing_ca": "\([^"]*\)".*/\1/p')" > /tmp/intermediateCA.crt
cat /tmp/server.crt /tmp/intermediateCA.crt > /certs/fullchain.crt
printf '%b' "$(printf '%s' "$CERT_JSON" | sed -n 's/.*"private_key": "\([^"]*\)".*/\1/p')" > /certs/server.key
rm -f /tmp/server.crt /tmp/intermediateCA.crt

chmod 600 /certs/server.key
chmod 644 /certs/fullchain.crt

# Revoca immediata del token AppRole temporaneo
vault token revoke -self >/dev/null
echo "Segreti DB in RAM e certificati TLS pronti per ciuismeglchuan."

exec tail -f /dev/null