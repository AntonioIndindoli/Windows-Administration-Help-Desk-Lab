"""Verify the real local staff login over authenticated TLS without logging secrets."""
import datetime
import http.cookiejar
import json
import pathlib
import re
import ssl
import urllib.parse
import urllib.request
from html.parser import HTMLParser

root = pathlib.Path(__file__).resolve().parent.parent
base = 'https://127.0.0.1:8443'
credentials = json.loads((root / 'LabSecrets' / 'osticket.json').read_text(encoding='utf-8-sig'))
context = ssl.create_default_context(cafile=str(root / 'data' / 'lab-ca.crt'))
cookies = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=context), urllib.request.HTTPCookieProcessor(cookies))

class HiddenInputs(HTMLParser):
    def __init__(self):
        super().__init__()
        self.values = {}
    def handle_starttag(self, tag, attributes):
        values = dict(attributes)
        if tag == 'input' and values.get('type') == 'hidden' and values.get('name'):
            self.values[values['name']] = values.get('value', '')

login = opener.open(base + '/scp/login.php', timeout=20).read().decode()
form = HiddenInputs()
form.feed(login)
form.values.update(userid=credentials['admin_username'], passwd=credentials['admin_password'], do='scplogin')
response = opener.open(base + '/scp/login.php', data=urllib.parse.urlencode(form.values).encode(), timeout=20)
body = response.read().decode()
passed = ('logout.php' in body or 'Log Out' in body) and 'name="passwd"' not in body
result = dict(time=datetime.datetime.now(datetime.timezone.utc).isoformat(), http_status=response.status, final_url=response.url, staff_login_passed=passed, tls_chain_and_hostname_verified=True)
(root / 'evidence' / 'osticket-staff-login.json').write_text(json.dumps(result, indent=2))
print(json.dumps(result))
if not passed:
    raise SystemExit('Staff login did not reach an authenticated agent page.')
