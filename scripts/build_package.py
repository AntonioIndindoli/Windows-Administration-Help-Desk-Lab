"""Create a reproducible build/evidence ZIP, excluding runtime media and secrets."""
import csv
import hashlib
import json
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
paths=[ROOT/'README.md',ROOT/'.gitignore']
for folder in ('scripts','docs','data','evidence'):
    paths.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix not in ('.pyc',) and p.name!='build-package-result.json')
paths=sorted(paths)
secrets=[]
for p in (ROOT/'LabSecrets').glob('*.password'):
    value=p.read_text(encoding='utf-8-sig').strip()
    if value: secrets.append(value)
for row in csv.DictReader((ROOT/'LabSecrets/working-users.csv').read_text(encoding='utf-8-sig').splitlines()):
    secrets.append(row['Password'])
ost=json.loads((ROOT/'LabSecrets/osticket.json').read_text(encoding='utf-8-sig'))
secrets.extend(str(v) for k,v in ost.items() if 'password' in k.lower())
for p in paths:
    raw=p.read_bytes()
    if any(value.encode() in raw or value.encode('utf-16-le') in raw for value in secrets):
        raise SystemExit(f'Secret detected in package input: {p.relative_to(ROOT)}')
    if (b'-----BEGIN '+b'OPENSSH PRIVATE KEY-----') in raw or (b'-----BEGIN '+b'PRIVATE KEY-----') in raw:
        raise SystemExit(f'Private key detected: {p.relative_to(ROOT)}')
out=ROOT/'Build';out.mkdir(exist_ok=True)
manifest=[dict(path=p.relative_to(ROOT).as_posix(),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in paths]
manifest_bytes=(json.dumps(manifest,indent=2)+'\n').encode()
(out/'file-manifest.json').write_bytes(manifest_bytes)
archive=out/'Windows-Administration-Help-Desk-Lab.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in paths:z.write(p,p.relative_to(ROOT).as_posix())
    z.writestr('file-manifest.json',manifest_bytes)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert not any(n.startswith(('LabSecrets/','VMs/','media/','.tools/','payload/')) for n in z.namelist())
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
(out/(archive.name+'.sha256')).write_text(digest+'  '+archive.name+'\n')
print(json.dumps(dict(archive=str(archive),files=len(paths),bytes=archive.stat().st_size,sha256=digest,zip_crc_passed=True,known_secret_scan_passed=True),indent=2))
