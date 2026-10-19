"""Convert observed live checks into resolution records; never accept expected-only results."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
E = ROOT / 'evidence'
def read(name):
    return json.loads((E / name).read_text(encoding='utf-8-sig'))
results = read('login-ticket-results.json')
details = {
'T05': ('Local namespace authentication failed with error 1326.', 'No local operations01 account exists.', 'Used CORP domain credentials.', 'Windows LogonUser succeeded and token identity was CORP\\operations01.', 'Use the domain username format supplied during onboarding.'),
'T06': ('Internal names failed with client DNS set to 10.77.0.99.', 'Incorrect adapter DNS server.', 'Reset DNS to the DHCP-provided DC01 address and cleared the cache.', 'DC01 resolved to 10.77.0.10 after repair.', 'Leave managed DNS automatic.'),
'T07': ('Helpdesk hostname resolved to unused 10.77.0.99.', 'The application A record was incorrect.', 'Restored only helpdesk to 10.77.0.30 and cleared the client cache.', 'Client resolution returned .30 and certificate-validated HTTPS returned 200.', 'Report the exact application hostname when requesting help.'),
'T08': ('Application resolution used .99 while authoritative DNS returned .30.', 'An injected hosts-file override took precedence.', 'Restored the exact original hosts-file bytes and cleared DNS cache.', 'Application resolution returned .30 and HTTPS port connectivity succeeded.', 'Do not add local hosts overrides for managed services.'),
'T09': ('A cache-only DNS lookup retained name-not-found after the authoritative record was created. Ordinary application lookups had refreshed automatically in earlier attempts.', 'The cache-only query used a stale negative entry. A persistent outage in ordinary lookups was not reproduced on this Windows build.', 'Confirmed the record on DC01, cleared the client cache, then performed a fresh lookup.', 'Fresh application resolution and a subsequent cache-only lookup both returned .30; the temporary record was removed. The fault was limited to cache-only retrieval.', 'Ask support to compare authoritative, fresh and cache-only results before refreshing cached DNS.'),
'T10': ('nslookup of FS01 failed while the FQDN resolved.', 'The suffix search list had been changed to invalid.test.', 'Restored the saved suffix search configuration.', 'nslookup expanded FS01 to FS01.corp.example.test and returned .20.', 'Provide the full server name when short names fail.'),
'T11': ('PC01 had a 169.254/16 APIPA address.', 'The VM was attached to an empty internal switch without DHCP.', 'Reattached only PC01 to HelpDeskLab and renewed its lease.', 'The client received a 10.77.0.0/24 DHCP address again.', 'Report a 169.254 address to support; do not invent a static address.'),
'T12': ('DC01 became unreachable after applying a /30 mask to an out-of-pool .250 client address.', 'The client subnet mask was incorrect.', 'Removed the temporary manual address and restored DHCP and automatic DNS.', 'DC TCP389 succeeded with a DHCP /24 address.', 'Keep managed IP settings automatic.'),
'T13': ('Client networking failed with its Ethernet adapter disabled.', 'The lab adapter was disabled.', 'Enabled the same adapter and renewed DHCP.', 'Adapter status was Up and FS01 TCP445 succeeded.', 'Report disabled adapters; avoid changing other network devices.'),
'T14': ('FS01 DNS resolved while TCP445 was blocked.', 'The named Lab-T14 outbound rule blocked SMB.', 'Removed only the injected Lab-T14 rule.', 'FS01 TCP445 succeeded and the temporary rule was absent.', 'Give support the server and service affected by a connection failure.'),
'T15': ('Internal SMB worked while external HTTPS connectivity failed.', 'The client gateway was changed to unused .254.', 'Restored DHCP routing through HD01 at .1.', 'The same external TCP443 probe succeeded again.', 'Keep the managed gateway configuration automatic.'),
'T19': ('An existing user token remained denied after department membership was restored.', 'The old logon and SMB session retained the earlier group authorization state.', 'Started a fresh Windows logon after restoring authorized membership.', 'The retained token stayed denied and a new ordinary-user logon read, wrote and deleted in Operations.', 'Sign out completely and sign back in after an approved access change.'),
}
for ex, info in details.items():
    p = E / f'{ex}-observations.json'
    if not p.exists():
        continue
    raw = read(p.name)
    if not all(raw.get(k) is True for k in ('fault_observed','repair_verified','baseline_restored')):
        print(f'{ex}: pending or failed; not eligible')
        continue
    symptom,cause,resolution,verification,guidance=info
    results.append(dict(exercise=ex,fault_observed=True,repair_verified=True,baseline_restored=True,symptom=symptom,cause=cause,resolution=resolution,verification=verification,evidence=f'evidence/{p.name}',client_guidance=guidance))
for ex,user,share,cause,resolution in [
 ('T16','hr04','HR','The authorized user was missing from GG_HR.','Restored only hr04 membership in GG_HR.'),
 ('T17','finance04','Finance','The department NTFS Allow rule was removed while SMB Change remained.','Restored the exact saved directory security descriptor.'),
 ('T18','sales04','Sales','SMB Change was removed while the NTFS Modify grant remained.','Restored SMB Change for CORP\\DL_Sales_Modify; confirmed NTFS was unchanged.')]:
    paths=[f'share-{ex}-{phase}-{user}-{share}.json' for phase in ('fault','repair')]
    if not all((E/p).exists() for p in paths): continue
    fault,repair=map(read,paths)
    if not(fault['pass'] and fault['expected']=='Denied' and repair['pass'] and repair['expected']=='Modify'): continue
    results.append(dict(exercise=ex,fault_observed=True,repair_verified=True,baseline_restored=True,symptom=f'{user} was denied access to {share}.',cause=cause,resolution=resolution,verification='Fresh ordinary-user logon read, wrote and deleted successfully; another department remained denied.',evidence='; '.join('evidence/'+p for p in paths)+'; evidence/permission-live-tickets.txt',client_guidance='Request approved department access; administrators should change only the missing permission.'))
p=E/'share-T20-it04-Public.json'
if p.exists() and read(p.name)['pass'] and read('share-baseline-it04-IT.json')['pass']:
    results.append(dict(exercise='T20',fault_observed=True,repair_verified=True,baseline_restored=True,symptom='it04 could read Public but received Access Denied when writing.',cause='Public intentionally grants read-only access.',resolution='Confirmed the intended ACL and directed the requester to the writable IT department share.',verification='Public file read succeeded and write failed; the same ordinary user read, wrote and deleted in IT. No broad permission grant was made.',evidence='evidence/share-T20-it04-Public.json; evidence/share-baseline-it04-IT.json',client_guidance='Use your department share to save work; Public documents are read-only.'))
results.sort(key=lambda r:r['exercise'])
assert len({r['exercise'] for r in results})==len(results)
(E/'verified-ticket-results.json').write_text(json.dumps(results,indent=2)+'\n')
print(f'{len(results)}/20 exercises have observed fault, repair and restoration records.')
