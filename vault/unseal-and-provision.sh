#!/bin/sh
set -e

export VAULT_ADDR="http://vault:8200"

until vault status >/dev/null 2>&1 || [ $? -eq 2 ]; do
  sleep 1
done

# Attende che 2 membri del team sblocchino Vault (quorum 2-su-3)
while vault status 2>&1 | grep -q "Sealed.*true"; do
  echo "Vault è SEALED: in attesa del quorum 2-su-3 (esegui 'docker exec -it ciuismeglchuan-vault vault operator unseal' 2 volte)..."
  sleep 3
done

echo "Vault UNSEALED! Avvio provisioning con AppRole..."

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

CERT_PEM=$(printf '%s\n' "$CERT_JSON" | awk -F'"' '/"certificate":/ {print $4}')
CA_PEM=$(printf '%s\n' "$CERT_JSON" | awk -F'"' '/"issuing_ca":/ {print $4}')
KEY_PEM=$(printf '%s\n' "$CERT_JSON" | awk -F'"' '/"private_key":/ {print $4}')

printf '%b\n%b\n' "$CERT_PEM" "$CA_PEM" | sed '/^$/d' > /certs/fullchain.crt
printf '%b\n' "$KEY_PEM" | sed '/^$/d' > /certs/server.key

chmod 600 /certs/server.key
chmod 644 /certs/fullchain.crt

# Revoca immediata del token AppRole temporaneo
vault token revoke -self >/dev/null
echo "Segreti DB in RAM e certificati TLS pronti per ciuismeglchuan."

# Mantiene montato il volume tmpfs in RAM
exec tail -f /dev/null