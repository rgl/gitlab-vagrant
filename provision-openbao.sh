#!/bin/bash
set -euxo pipefail


gitlab_domain="$1"
domain="$2"


# wait for a specific openbao state.
# see https://openbao.org/api-docs/system/health/
function wait-for-state {
    local desired_state="$1"
    local openbao_health_check_url="$VAULT_ADDR/v1/sys/health"
    while true; do
        local status_code="$(
            (wget \
                -qO- \
                --server-response \
                --spider \
                --tries=1 \
                "$openbao_health_check_url" \
                2>&1 || true) \
                | awk '/^  HTTP/{print $2}')"
        case "$status_code" in
            "$desired_state")
                return 0
                ;;
            *)
                sleep 5
                ;;
        esac
    done
}


# install dependencies.
apt-get install -y httpie jq


# install openbao.
# see https://developer.hashicorp.com/vault/docs/concepts/production-hardening
# see https://openbao.org/docs/internals/security/
# see https://github.com/openbao/openbao
# renovate: datasource=github-releases depName=openbao/openbao
openbao_version='2.4.1'
url="https://github.com/openbao/openbao/releases/download/v$openbao_version/bao_${openbao_version}_linux_amd64.deb"
p="$(basename "$url")"
wget -qO "$p" "$url"
dpkg -i "$p"
rm -rf "$p"
bao -v

# configure the service to auto-unseal openbao.
install -d /etc/systemd/system/openbao.service.d
cat >/etc/systemd/system/openbao.service.d/override.conf <<'EOF'
[Service]
ExecStartPost=
ExecStartPost=+/opt/openbao/auto-unseal/unseal
EOF
systemctl daemon-reload

# configure.
export VAULT_ADDR="https://$domain:8200"
echo export VAULT_ADDR="https://$domain:8200" >>~/.bash_login
install -o openbao -g openbao -m 770 -d /etc/openbao
install -o root -g openbao -m 710 -d /opt/openbao
install -o openbao -g openbao -m 700 -d /opt/openbao/data
install -o root -g openbao -m 750 -d /opt/openbao/tls
install -o root -g openbao -m 440 /vagrant/tmp/gitlab-ca/$domain-crt.pem /opt/openbao/tls
install -o root -g openbao -m 440 /vagrant/tmp/gitlab-ca/$domain-key.pem /opt/openbao/tls
cat >/etc/openbao/openbao.hcl <<EOF
cluster_name = "gitlab"

ui = true

# one of: trace, debug, info, warning, error.
log_level = "trace"

storage "file" {
    path = "/opt/openbao/data"
}

listener "tcp" {
    address = "0.0.0.0:8200"
    cluster_address = "0.0.0.0:8201"
    tls_disable = false
    tls_cert_file = "/opt/openbao/tls/$domain-crt.pem"
    tls_key_file = "/opt/openbao/tls/$domain-key.pem"
    telemetry {
        unauthenticated_metrics_access = true
    }
}

# enable auditing to stdout (use journalctl -u openbao to see it).
audit "file" "stdout" {
  options {
    file_path = "stdout"
    log_raw = "true"
  }
}

api_addr = "https://$domain:8200"
cluster_addr = "https://$domain:8201"

# enable the telemetry endpoint.
# access it at https://$domain:8200/v1/sys/metrics?format=prometheus
# see https://openbao.org/docs/configuration/telemetry/
# see https://openbao.org/docs/configuration/listener/tcp/#telemetry-parameters
telemetry {
   disable_hostname = true
   prometheus_retention_time = "24h"
}
EOF
chown root:openbao /etc/openbao/openbao.hcl
chmod 440 /etc/openbao/openbao.hcl
install -o root -g root -m 700 -d /opt/openbao/auto-unseal
install -o root -g root -m 500 /dev/null /opt/openbao/auto-unseal/unseal
echo '#!/bin/bash' >/opt/openbao/auto-unseal/unseal

# disable swap.
swapoff --all
sed -i -E 's,^(\s*[^#].+\sswap.+),#\1,g' /etc/fstab

# start openbao.
systemctl enable openbao
systemctl start openbao
wait-for-state 501 # wait for the not-initialized state.
journalctl -u openbao

# init openbao.
# NB openbao-operator-init-result.txt will have something like:
#       Unseal Key 1: sXiqMfCPiRNGvo+tEoHVGy+FHFW092H7vfOY0wPrzpYh
#       Unseal Key 2: dCm5+NhacPcX6GwI0IMMK+CM0xL6wif5/k0LJ0XTPHhy
#       Unseal Key 3: YjbM3TANam0dO9FTa0y/2wj7nxnlDyct7oVMksHs7trE
#       Unseal Key 4: CxWG0yrF75cIYsKvWQBku8klN9oPaPJDWqO7l7LNWX2A
#       Unseal Key 5: C+ttQv3KeViOkIxVZH7gXuZ7iZPKi0va1/lUBSiMeyLz
#       Initial Root Token: d2bb2175-2264-d18b-e8d8-18b1d8b61278
#
#       Vault initialized with 5 keys and a key threshold of 3. Please
#       securely distribute the above keys. When the openbao is re-sealed,
#       restarted, or stopped, you must provide at least 3 of these keys
#       to unseal it again.
#
#       Vault does not store the master key. Without at least 3 keys,
#       your openbao will remain permanently sealed.
pushd ~
install -o root -g root -m 600 /dev/null openbao-operator-init-result.txt
install -o root -g root -m 600 /dev/null /opt/openbao/auto-unseal/unseal-keys.txt
install -o root -g root -m 600 /dev/null .vault-token
bao operator init >openbao-operator-init-result.txt
awk '/Unseal Key [0-9]+: /{print $4}' openbao-operator-init-result.txt | head -3 >/opt/openbao/auto-unseal/unseal-keys.txt
awk '/Initial Root Token: /{print $4}' openbao-operator-init-result.txt | tr -d '\n' >.vault-token
cp .vault-token /vagrant/tmp/vault-root-token.txt
popd
cat >/opt/openbao/auto-unseal/unseal <<EOF
#!/bin/bash
set -eu
export VAULT_ADDR='$VAULT_ADDR'
# wait for openbao to be ready.
# see https://openbao.org/api-docs/system/health/
BAO_HEALTH_CHECK_URL="\$VAULT_ADDR/v1/sys/health"
while true; do
    status_code="\$(
        (wget \
            -qO- \
            --server-response \
            --spider \
            --tries=1 \
            "\$BAO_HEALTH_CHECK_URL" \
            2>&1 || true) \
            | awk '/^  HTTP/{print \$2}')"
    case "\$status_code" in
        # openbao is sealed. break the loop, and unseal it.
        503)
            break
            ;;
        # for some odd reason openbao is already unsealed. anyways, its
        # ready and unsealed, so exit this script.
        200)
            exit 0
            ;;
        # otherwise, wait a bit, then retry the health check.
        *)
            sleep 5
            ;;
    esac
done
KEYS=\$(cat /opt/openbao/auto-unseal/unseal-keys.txt)
for key in \$KEYS; do
    /usr/bin/bao operator unseal \$key
done
EOF
/opt/openbao/auto-unseal/unseal

# restart openbao to verify that the automatic unseal is working.
systemctl restart openbao
wait-for-state 200 # wait for the unsealed state.
journalctl -u openbao
bao status

# install command line autocomplete.
bao -autocomplete-install

# show the openbao tls certificate.
openssl s_client -connect $domain:8200 -servername $domain </dev/null 2>/dev/null | openssl x509 -noout -text

# show information about our own token.
# see https://openbao.org/api-docs/auth/token/#lookup-a-token-self
bao token lookup
http $VAULT_ADDR/v1/auth/token/lookup-self \
    "X-Vault-Token: $(cat ~/.vault-token)" \
    | jq .data

# list audits.
# NB the audit is set in the openbao.hcl file.
# see https://openbao.org/docs/commands/audit/
# see https://openbao.org/docs/commands/audit/enable/
bao audit list

# enable the jwt authentication method.
bao auth enable jwt

# configure the openbao vault jwt authentication method to use gitlab.
bao write auth/jwt/config \
    "oidc_discovery_url=https://$gitlab_domain" \
    "bound_issuer=https://$gitlab_domain"

# enable the kv 2 secrets engine.
bao secrets enable -version=2 -path=secret kv

# list enabled authentication methods.
bao auth list

# list the active secret backends.
bao secrets list

# show the default policy.
# see https://openbao.org/docs/concepts/policies/
bao read sys/policy/default

# list the active authentication backends.
# see https://openbao.org/docs/auth/
# see https://openbao.org/api-docs/system/auth/
bao path-help sys/auth
http $VAULT_ADDR/v1/sys/auth "X-Vault-Token: $(cat ~/.vault-token)" \
    | jq -r 'keys[] | select(endswith("/"))'
