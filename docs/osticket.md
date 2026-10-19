# osTicket deployment and knowledge base

Install osTicket on HD01, separate from DC01. Use a maintained Linux distribution and the official osTicket release. Follow the official installation page for the exact release: web server (Apache/LiteSpeed or IIS with URL Rewrite), a supported PHP version/extensions, and MySQL. At preparation time the published installation guide lists PHP 8.2–8.4; verify compatibility before installing rather than assuming the OS-default PHP works. See `references.md`.

1. Give HD01 10.77.0.30/24, DNS .10, and an optional real lab router. Temporarily permit controlled internet access if downloads require it. Install a web server, supported PHP plus the extensions listed by the installer, and a database server. Limit inbound web traffic to the lab subnet; keep the database on localhost.
2. Create a database named `osticket` and a dedicated database user limited to that database. Use generated credentials; do not reuse domain administrator credentials. Extract the official release's `upload/` contents into a dedicated web root.
3. Copy `include/ost-sampleconfig.php` to `include/ost-config.php`; grant only the installation-time write access required by the installer. Browse to the installer at your lab web hostname and supply the database, help desk name, administrator account, and email settings. Use a lab-only email address; no external mailbox is required for manually entered tickets.
4. Delete the `setup/` directory when installation completes, remove write permission from `ost-config.php` for the web process as directed by the installer, and limit remaining writable folders to those required by your chosen storage configuration. Verify file ownership and access. Configure HTTPS with a lab CA certificate trusted on the clients. Never expose this exercise service to the public internet.
5. Sign in to `/scp/`. Create a Help Desk department, an agent account separate from the administrator, and help topics Login, DNS, Connectivity, File Access. Give the agent the permissions needed to manage these lab tickets and FAQs. Keep self-registration/email fetching disabled unless you explicitly configure them.
6. In the knowledge base, create categories matching those four topics. Create FAQs from the 20 articles in `tickets-and-kb.md`; their symptom, cause, repair, and verification fields are ready to copy. Publish client-safe guidance only; keep administrator commands in internal notes where appropriate. Verify category/FAQ visibility with an ordinary client account.

## Tickets and FAQ entry

For each scenario, use the agent panel's New Ticket action to create a ticket on behalf of the test user. Include the exercise ID in the subject, relevant help topic, user, affected machine, priority, symptom, and reproduction. These Markdown files are source material, **not a native osTicket import**. No direct database writes or unsupported bulk FAQ imports are required.

During the exercise add private diagnostic notes, then a customer-facing resolution with the relevant published FAQ link. Retest with the affected user before marking the ticket resolved/closed according to the available status workflow. Record the actual osTicket number, URL, timestamps, and screenshots in `evidence/validation.md`. Do not label a scenario resolved merely because its proposed fix is documented.

## Resolution note template

```text
Exercise / actual ticket ID:
Affected user and machine:
Reported symptom and impact:
Observed diagnostics (exact output / evidence link):
Confirmed cause:
Change performed and rollback:
User-context retest and result:
Related FAQ URL:
Agent / date / final status:
```

Back up the database and application configuration; test restoring them in a disposable VM before declaring backups verified. Screenshot the 20-ticket queue and searchable FAQ categories after completion, with personal data and secrets redacted.
