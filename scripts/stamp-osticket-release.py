"""Apply the same release identifiers/error-display defaults as upstream's Git deployment step."""
import pathlib
import re
import sys
path = pathlib.Path('/var/www/osticket/bootstrap.php')
commit = sys.argv[1]
if not re.fullmatch(r'[0-9a-f]{40}', commit):
    raise SystemExit('Expected an upstream commit SHA')
text = path.read_text()
text, version_count = re.subn(r"define\('THIS_VERSION',.*?;[^\n]*", "define('THIS_VERSION', 'v1.18.4'); // Release archive deployment", text)
text, git_count = re.subn(r"define\('GIT_VERSION',.*?;[^\n]*", f"define('GIT_VERSION', '{commit[:7]}'); // Verified upstream tag commit", text)
text = re.sub(r"ini_set\('(display_errors|display_startup_errors)',\s*1\)", r"ini_set('\1', 0)", text)
if version_count != 1 or git_count != 1:
    raise SystemExit('Unexpected upstream bootstrap layout')
path.write_text(text)
print('Stamped upstream v1.18.4 / '+commit[:7]+' and disabled browser error display.')
