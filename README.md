# Windows Administration & Help Desk Lab

I built a small office network in VirtualBox to practice the work an internal IT team does every day. The lab has two Windows 11 workstations, employee accounts for five departments, a file server, and a running help desk. I used it to see what happens when someone can’t sign in, loses their connection, or suddenly can’t open a folder they need for work.

**5 virtual machines** · **30 test accounts** · **20 tickets closed** · **20 help articles published**

## What I set up

| Part of the office | How it works |
| --- | --- |
| Employee accounts and computers | A Windows server uses Active Directory for sign-ins and Group Policy to set up shared drives and screen locking. DHCP gives the workstations their network settings, and DNS helps them find internal services by name. |
| Shared files | IT, HR, Finance, Sales, and Operations each have a department folder. Access follows department membership. Everyone can read the Public folder, which is where the office keeps shared reference material. |
| Help desk | osTicket runs on a separate Ubuntu machine. Each exercise has a ticket with internal troubleshooting notes and a short help article written for employees. |

## How the tickets work

The exercises start with a problem someone might report, such as “The shared drive won’t open on my computer.” In the lab, I can recreate that problem, check where it starts, and test the fix from the affected account or workstation. The ticket records what was found and how it was checked. The help article explains what the employee can do the next time it happens. [Browse the practice tickets and FAQs](docs/tickets-and-kb.md)

## Three tickets from the lab

**An HR employee couldn’t open the HR folder.** Their account was missing from the group that grants access. After the membership was restored, a fresh sign-in confirmed they could create and delete a test file in HR. The same account got an access-denied message when it tried to open Finance. [File access results](evidence/validation.md#file-access)

**One workstation couldn’t reach the file server.** The computer could find the server by name, which narrowed the problem down. An outbound firewall rule was blocking file-sharing traffic from that workstation. Removing the rule restored the connection. [Connectivity results](evidence/validation.md#connectivity)

**An employee couldn’t save to Public.** The account could open files in Public and save to its own department folder. That was the expected setup, so the right response was to show the employee where to save their work. [Public folder exercise](docs/tickets-and-kb.md#t20--kb20---read-only-public-share-mistaken-for-a-writable-folder)

## What the lab verified

The October 2026 validation run used automated tests to check the setup and exercise fixes. Both workstations joined the domain and reached the help desk over a trusted connection. The file tests checked access from standard employee accounts in all five departments. The osTicket backup was restored to a separate test database, where the tickets and help articles could be checked. [Full validation report](evidence/validation.md)

## Build or explore the lab

The repository has the instructions and test records. The virtual machines and lab credentials live on the lab host.

- Start with the steps for setting up the servers, workstations, employee accounts, and shared folders. [Build guide](docs/build-guide.md)
- See how I set up password rules, workstation settings, and access to department folders. [Group Policy and permissions](docs/group-policy.md)
- See how the installed lab starts, how to reach the help desk, and how to recover it from backups. [Guide to the existing lab](docs/live-lab.md)
