#!/usr/bin/env bash
# Run only on HD01 as root after cloud-init completes. Uses upstream deployment/installer code.
set -euo pipefail
test "$(id -u)" = 0 || { echo 'Run as root'; exit 1; }
archive=${1:?Pass the upstream osTicket source ZIP path}
test ! -e /var/www/osticket/include/ost-config.php || { echo 'Existing configuration: inspect before rerunning'; exit 1; }
install -d -m 700 /root/lab-secrets /opt/helpdesk-build
unzip -q "$archive" -d /opt/helpdesk-build
cd /opt/helpdesk-build/osTicket-1.18.4
php manage.php deploy --setup /var/www/osticket
cp /var/www/osticket/include/ost-sampleconfig.php /var/www/osticket/include/ost-config.php
chown root:www-data /var/www/osticket/include/ost-config.php
chmod 660 /var/www/osticket/include/ost-config.php
python3 - <<'PY'
import json, pathlib, secrets, subprocess
data = {'db_password': secrets.token_urlsafe(32), 'admin_password': 'Aa1!'+secrets.token_urlsafe(28), 'admin_username': 'lab.supervisor'}
path = pathlib.Path('/root/lab-secrets/osticket.json')
path.write_text(json.dumps(data))
path.chmod(0o600)
sql = "CREATE DATABASE osticket CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci; CREATE USER 'osticket'@'localhost' IDENTIFIED BY '%s'; GRANT ALL PRIVILEGES ON osticket.* TO 'osticket'@'localhost';" % data['db_password']
subprocess.run(['mariadb'], input=sql, text=True, check=True)
PY
cat >/etc/apache2/sites-available/helpdesk.conf <<'CONF'
<VirtualHost *:80>
    ServerName helpdesk.corp.example.test
    DocumentRoot /var/www/osticket
    <Directory /var/www/osticket>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/helpdesk-error.log
    CustomLog ${APACHE_LOG_DIR}/helpdesk-access.log combined
</VirtualHost>
CONF
a2enmod rewrite
a2dissite 000-default
a2ensite helpdesk
systemctl reload apache2
python3 - <<'PY'
import json, pathlib, urllib.parse, urllib.request
data = json.loads(pathlib.Path('/root/lab-secrets/osticket.json').read_text())
form = dict(s='install', name='Windows Administration Help Desk Lab', email='support@corp.example.test', fname='Lab', lname='Supervisor', admin_email='supervisor@corp.example.test', username=data['admin_username'], passwd=data['admin_password'], passwd2=data['admin_password'], prefix='ost_', dbhost='localhost', dbname='osticket', dbuser='osticket', dbpass=data['db_password'])
request = urllib.request.Request('http://127.0.0.1/setup/install.php', data=urllib.parse.urlencode(form).encode(), headers={'Host':'helpdesk.corp.example.test'})
response = urllib.request.urlopen(request, timeout=120).read()
log=pathlib.Path('/root/lab-secrets/installer-response.html')
log.write_bytes(response)
log.chmod(0o600)
config=pathlib.Path('/var/www/osticket/include/ost-config.php').read_text()
import re
if not re.search(r"define\s*\(\s*['\"]OSTINSTALLED['\"]\s*,\s*(?:true|TRUE)\s*\)", config):
    raise SystemExit('Installer did not mark the application installed; inspect the protected installer response.')
print('Upstream installer completed successfully.')
PY
chmod 640 /var/www/osticket/include/ost-config.php
# Move the installer out of the web root; retain it for a verified rollback.
mv /var/www/osticket/setup /root/lab-secrets/completed-setup
install -d -m 700 /root/lab-secrets/pki
openssl req -x509 -newkey rsa:3072 -nodes -keyout /root/lab-secrets/pki/lab-ca.key -out /root/lab-secrets/pki/lab-ca.crt -days 365 -subj '/CN=HelpDesk Lab Root CA' -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign' -addext 'subjectKeyIdentifier=hash'
openssl req -newkey rsa:3072 -nodes -keyout /root/lab-secrets/pki/helpdesk.key -out /root/lab-secrets/pki/helpdesk.csr -subj '/CN=helpdesk.corp.example.test'
cat >/root/lab-secrets/pki/helpdesk.ext <<'EXT'
subjectAltName=DNS:helpdesk.corp.example.test,DNS:localhost,IP:10.77.0.30,IP:127.0.0.1
extendedKeyUsage=serverAuth
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
EXT
openssl x509 -req -in /root/lab-secrets/pki/helpdesk.csr -CA /root/lab-secrets/pki/lab-ca.crt -CAkey /root/lab-secrets/pki/lab-ca.key -CAcreateserial -out /root/lab-secrets/pki/helpdesk.crt -days 180 -extfile /root/lab-secrets/pki/helpdesk.ext
install -m 600 /root/lab-secrets/pki/helpdesk.key /etc/ssl/private/helpdesk.key
install -m 644 /root/lab-secrets/pki/helpdesk.crt /etc/ssl/certs/helpdesk.crt
cat >/etc/apache2/sites-available/helpdesk-ssl.conf <<'CONF'
<VirtualHost *:443>
    ServerName helpdesk.corp.example.test
    DocumentRoot /var/www/osticket
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/helpdesk.crt
    SSLCertificateKeyFile /etc/ssl/private/helpdesk.key
    <Directory /var/www/osticket>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
CONF
a2enmod ssl
a2ensite helpdesk-ssl
apache2ctl configtest
systemctl reload apache2
echo 'osTicket installed. Credentials: /root/lab-secrets/osticket.json; trust only the public lab-ca.crt on lab clients.'
