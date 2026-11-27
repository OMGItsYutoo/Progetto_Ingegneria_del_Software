#!/bin/sh
set -e

export VAULT_ADDR="http://127.0.0.1:8200"

echo "=== 1. INIZIALIZZAZIONE SHAMIR (3 SHARES, SOGLIA 2) ==="
INIT_OUT=$(vault operator init -key-shares=3 -key-threshold=2)

KEY1=$(printf '%s\n' "$INIT_OUT" | grep 'Unseal Key 1:' | awk '{print $NF}')
KEY2=$(printf '%s\n' "$INIT_OUT" | grep 'Unseal Key 2:' | awk '{print $NF}')
KEY3=$(printf '%s\n' "$INIT_OUT" | grep 'Unseal Key 3:' | awk '{print $NF}')
ROOT_TOKEN=$(printf '%s\n' "$INIT_OUT" | grep 'Initial Root Token:' | awk '{print $NF}')

echo ""
echo "Distribuite subito queste 3 chiavi (una a testa, NON salvatele nel repo):"
echo "  Membro 1 -> $KEY1"
echo "  Membro 2 -> $KEY2"
echo "  Membro 3 -> $KEY3"
echo ""

# Unseal temporaneo per configurare PKI, KV e AppRole
vault operator unseal "$KEY1" >/dev/null
vault operator unseal "$KEY2" >/dev/null
vault login "$ROOT_TOKEN" >/dev/null

echo "=== 2. CONFIGURAZIONE KV v2 (CREDENZIALI DB CIUISMEGLCHUAN) ==="
vault secrets enable -path=secret kv-v2
DB_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
DB_ROOT_PASS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24)
vault kv put secret/ciuismeglchuan/db \
  db_password="$DB_PASS" \
  db_root_password="$DB_ROOT_PASS"

echo "=== 3. CONFIGURAZIONE PKI (ROOT 4096 -> INTERMEDIATE 4096 -> LEAF 3072) ==="
vault secrets enable pki
vault secrets tune -max-lease-ttl=87600h pki
vault write -field=certificate pki/root/generate/internal \
  common_name="Ciuismeglchuan Root CA" \
  organization="CiuismeglchuanProject" \
  country="IT" \
  key_type="rsa" \
  key_bits=4096 \
  ttl=87600h > /vault/file/rootCA.crt

vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=26280h pki_int
vault write -field=csr pki_int/intermediate/generate/internal \
  common_name="Ciuismeglchuan Intermediate CA" \
  organization="CiuismeglchuanProject" \
  country="IT" \
  key_type="rsa" \
  key_bits=4096 > /tmp/pki_int.csr

vault write -field=certificate pki/root/sign-intermediate \
  csr=@/tmp/pki_int.csr \
  format=pem_bundle \
  ttl=26280h > /tmp/intermediate.cert.pem

vault write pki_int/intermediate/set-signed certificate=@/tmp/intermediate.cert.pem
rm -f /tmp/pki_int.csr /tmp/intermediate.cert.pem

vault write pki_int/roles/ciuismeglchuan-server \
  allowed_domains="${DOMAIN_NAME}" \
  allow_localhost=true \
  allow_ip_sans=true \
  key_type="rsa" \
  key_bits=3072 \
  max_ttl="4320h" \
  server_flag=true \
  client_flag=false

echo "=== 4. CREAZIONE POLICY E APPROLE (LEAST PRIVILEGE) ==="
cat << 'POLICY' | vault policy write runtime-provisioner -
path "secret/data/ciuismeglchuan/db" {
  capabilities = ["read"]
}
path "pki_int/issue/ciuismeglchuan-server" {
  capabilities = ["create", "update"]
}
POLICY

vault auth enable approle
vault write auth/approle/role/provisioner \
  token_policies="runtime-provisioner" \
  token_ttl="10m" \
  token_max_ttl="15m"

ROLE_ID=$(vault read -field=role_id auth/approle/role/provisioner/role-id)
SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/provisioner/secret-id)

printf '%s' "$ROLE_ID" > /vault/file/approle_role_id
printf '%s' "$SECRET_ID" > /vault/file/approle_secret_id
chmod 600 /vault/file/approle_role_id /vault/file/approle_secret_id

echo "=== 5. REVOCA DEL ROOT TOKEN ==="
vault token revoke -self
echo "Cerimonia completata. Root Token revocato."