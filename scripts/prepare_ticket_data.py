"""Convert the authored exercises into explicitly unverified osTicket seed data."""
import json
import pathlib
import re
root = pathlib.Path(__file__).resolve().parent.parent
text = (root / 'docs' / 'tickets-and-kb.md').read_text(encoding='utf-8')
items = []
for match in re.finditer(r'^## (T\d{2}) / (KB\d{2}) — ([^\n]+)\n(.*?)(?=^## |\Z)', text, re.M | re.S):
    exercise, kb, title, body = match.groups()
    category = re.search(r'\*\*Category:\*\* ([^.]+)', body).group(1)
    user = re.search(r'\*\*User:\*\* ([^.]+)', body).group(1)
    items.append(dict(exercise=exercise, kb=kb, title=title, category=category, user=user, expected_article=body.strip(), verified=False))
assert len(items) == 20
(root / 'data' / 'ticket-seed.json').write_text(json.dumps(items, indent=2, ensure_ascii=False), encoding='utf-8')
print('Prepared 20 open exercise requests and private, unverified draft FAQ sources.')
