# hatchery

Experimental grubbery applications, followed into the ship as a desk
(same mechanism as contacts-nexus / wallet-nexus). Apps are migrated
here from the grubbery kernel (`/gub`) one at a time.

`code/` is the followed desk:
- `bill.json` — declares which nexuses to spawn
- `version.json` — update gate; bump to trigger a re-sync
- `nex/<app>/app.hoon` — each app's nexus
- `man/<app>/` — each app's handbook
