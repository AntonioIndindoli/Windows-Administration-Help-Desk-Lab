"""Render the acceptance register from recorded live results."""
import csv
import datetime
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
E=ROOT/'evidence'
def load(name): return json.loads((E/name).read_text(encoding='utf-8-sig'))
results=load('verified-ticket-results.json')
manifest=load('osticket-ticket-manifest.json')
baseline=list(csv.DictReader((E/'baseline-final.csv').read_text(encoding='utf-8-sig').splitlines()))
assert len(results)==20 and all(all(x[k] is True for k in ('fault_observed','repair_verified','baseline_restored')) for x in results)
assert len(manifest)==20 and all(x['verified'] and x['ticket_status']=='closed' and x['faq_status']=='published' for x in manifest)
assert len(baseline)==19 and all(x['Passed']=='True' for x in baseline)
maps=load('interactive-mappings.json')
assert any(x['LocalPath']=='P:' and x['RemotePath']==r'\\FS01\Public' for x in maps)
assert any(x['LocalPath']=='H:' and x['RemotePath']==r'\\FS01\IT' for x in maps)
faq=load('osticket-public-faq-checks.json')
assert len(faq['articles'])==20 and all(x['expected_article_and_verified_guidance'] for x in faq['articles']) and faq['search_found_kb09']
for vm in ('dc01','fs01','pc01','pc02'):
    assert load(vm+'-evaluation-license.json')['LicenseStatus']==1
    cleanup=load(vm+'-setup-cleanup.json')
    assert cleanup['autologon_disabled'] and cleanup['default_password_absent'] and cleanup['guest_service']=='Running'
now=datetime.datetime.now().astimezone().isoformat(timespec='seconds')
lines=['# Actual validation register','',f'**Complete - {now}.** Five live VirtualBox VMs deployed; 30 domain users provisioned; FS01, PC01 and PC02 joined; 20 support exercises resolved in osTicket with 20 published knowledge-base articles.','',
'The records below describe tests actually performed. Proposed solutions in the exercise guide were not accepted as results. Historical installation-stage observations remain in `deployment-history.md`.','',
'## Acceptance results','',
'| Check | Observed result | Evidence |','|---|---|---|',
'| Domain acceptance | All 19 checks passed: domain, 30 users, LDAP SRV, DHCP authorization/scope/options, department counts/nesting and three computer objects. | [baseline-final.csv](baseline-final.csv) |',
'| AD DS/DNS health | dcdiag Advertising, Services and basic DNS tests passed; exit 0. | [dcdiag-final.txt](dcdiag-final.txt) |',
'| DHCP | Active authorized .100â€“.199 scope; PC01 .100 and PC02 .101; /24 mask, DNS .10, gateway .1. | [dhcp-final-leases.json](dhcp-final-leases.json); [DHCP configuration](dhcp-configuration.txt) |',
'| Secure domain membership | FS01 and both Windows 11 clients report corp.example.test and successful secure-channel checks. | [FS01](fs01-shares.txt); [PC01](pc01-domain-policy.txt); [PC02](pc02-domain-policy.txt) |',
'| Accounts and groups | 30 real users, six in each of five department global groups, nested into five resource groups. All 30 completed authenticated password changes. | [final counts](final-group-counts.json); [password-change status only](onboarding-password-changes.csv) |',
'| Account policy | Minimum length 14, complexity enabled, history 24, lockout threshold 5, duration/reset 15 minutes; named domain-root GPO applied. | [final-account-policy.json](final-account-policy.json); [domain GPO](domain-account-gpo.html) |',
'| Workstation policy | Both clients have InactivityTimeoutSecs=900; domain firewall enabled, inbound Block and outbound Allow. | [PC01 policy](pc01-domain-policy.txt); [PC02 policy](pc02-domain-policy.txt); [firewall](pc02-final-client-host.txt) |',
'| Interactive user policy | Real CORP\\it04 console sign-in; user-experience GPO processed successfully; P: maps to Public and H: to IT. Noninteractive Session 0 did not apply these mappings and was not counted. | [mappings](interactive-mappings.json); [events](interactive-gp-events.json); [resultant policy](interactive-user-gpresult.html) |',
'| Department permissions | Five ordinary-user own-department create/read/delete checks passed and five other-department checks denied access. | [baseline tests](suffix-and-share-baselines.txt); share-baseline-*.json |',
'| Public permissions | it04 read Public, was denied writing there, and could modify IT; no permission broadening. | [Public result](share-T20-it04-Public.json); [IT result](share-baseline-it04-IT.json) |',
'| Trusted help desk HTTPS | PC01 and PC02 returned HTTP 200 with the lab CA trusted inside the guests; host Python checks verified CA and hostname. | [PC01](pc01-https.txt); [PC02](pc02-final-client-host.txt); [staff login](osticket-staff-login.json) |',
'| osTicket acceptance | 20/20 exercise tickets closed, 20/20 FAQs published; actual article bodies and public cache search verified. One separate installer welcome ticket remains outside the exercises. | [application manifest](osticket-ticket-manifest.json); [public checks](osticket-public-faq-checks.json) |',
'| Evaluation licensing | All four Windows guests report LicenseStatus=1 (activated TIMEBASED_EVAL). | *-evaluation-license.json |',
'| Installation cleanup | Setup DVDs detached; automatic administrator sign-in disabled; no DefaultPassword registry value; Guest Additions service running on all four Windows guests. | *-setup-cleanup.json |',
'| Completed-state backup | Final SQL restored into an independent test database: 21 total tickets, 20 FAQs and 61 thread entries. Application configuration restored and compared. Independent restricted host backup hashes match guest hashes. | [restore](osticket-completed-restore.txt); [guest hashes](osticket-completed-backup-hashes.txt); [host hashes](osticket-completed-host-hashes.json) |',
'| Recovery exercise | Earlier HD01 snapshot restored successfully; test marker absent and services active afterward. | [restore observation](hd01-restore-test.txt) |']
if (E/'lab-checkpoints.json').exists():
    snapshots=load('lab-checkpoints.json');assert len(snapshots)==5
    lines.append('| Coordinated recovery set | All five VMs paused together, checkpointed, then resumed. Restore the entire set together. The new set was saved; only the earlier HD01 checkpoint was restore-tested. | [lab-checkpoints.json](lab-checkpoints.json) |')
lines += ['', '## Ticket resolutions', '', 'Each row is backed by observed fault, successful repair/retest and baseline restoration. The ticket contains an internal validation note; its public FAQ contains client guidance.', '', '| Exercise / ticket | Observed cause and repair | Verification / evidence |', '|---|---|---|']
by_id={x['exercise']:x for x in manifest}
def safe(s): return s.replace('|','/').replace('\n',' ')
for r in results:
    m=by_id[r['exercise']]
    ticket=f"[{r['exercise']} / {m['ticket_number']}](https://127.0.0.1:8443/scp/tickets.php?id={m['ticket_id']})"
    lines.append(f"| {ticket} - CLOSED; [KB{m['faq_id']:02}](https://127.0.0.1:8443/kb/faq.php?id={m['faq_id']}) | {safe(r['cause'])} {safe(r['resolution'])} | {safe(r['verification'])} Evidence: {safe(r['evidence'])}. |")
lines += ['', '## Scope and limitations', '',
'T09 validated stale **cache-only** negative DNS retrieval after record creation, followed by a successful cache clear, fresh resolution and positive cache retest. Earlier ordinary application lookups auto-refreshed, so a persistent ordinary-lookup outage was **not reproduced**. That limitation is preserved in the ticket, FAQ and raw observations.', '',
'T10 used nslookup to validate suffix search. An earlier Resolve-DnsName short-name probe was unsuitable; its failed attempt remains in diagnostic history. T12 used unused .250, outside the DHCP pool, for its temporary /30 fault. Login cases used real Windows authentication calls; the drive-map check additionally used an interactive console sign-in.', '',
'The host retains VBS; VirtualBox uses its slower NEM backend. Several guest shutdown/setup phases stalled and required VM resets, followed by successful guest and domain verification. No physical-host security feature was disabled. The VMs are isolated from the physical LAN; HD01 forwards bind to loopback only.', '',
'Passwords, private keys, SQL/application backups and VM disks are excluded from the build ZIP and kept in restricted local storage. The ZIP is the reproducible build/evidence package; the registered VMs are the live deployment. See [live-lab.md](../docs/live-lab.md) for access and recovery instructions.']
(E/'validation.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Final register rendered: 19 baseline checks, 20 validated tickets, 20 published FAQs.')
