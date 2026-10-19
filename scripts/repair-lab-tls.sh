#!/usr/bin/env bash
# Apply strict RFC 5280 key-usage extensions to the initial lab certificates.
set -euo pipefail
cd /root/lab-secrets/pki
openssl req -new -x509 -key lab-ca.key -out lab-ca.crt -days 365 -subj '/CN=HelpDesk Lab Root CA' -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign' -addext 'subjectKeyIdentifier=hash'
cat >helpdesk.ext <<'EXT'
subjectAltName=DNS:helpdesk.corp.example.test,DNS:localhost,IP:10.77.0.30,IP:127.0.0.1
extendedKeyUsage=serverAuth
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
EXT
openssl x509 -req -in helpdesk.csr -CA lab-ca.crt -CAkey lab-ca.key -CAcreateserial -out helpdesk.crt -days 180 -extfile helpdesk.ext
install -m 644 helpdesk.crt /etc/ssl/certs/helpdesk.crt
openssl verify -CAfile lab-ca.crt helpdesk.crt
systemctl reload apache2
