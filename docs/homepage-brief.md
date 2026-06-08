# Homepage Brief

This document defines the direction for the `Homepage` deployment. It is a
working brief, not final product documentation. Update it when the dashboard's
role, content model, or iteration process changes.

## Role

`Homepage` is the daily front door for home operations and personal admin. It
should answer:

> What should I care about right now, and where do I go next?

The visible title should stay `Homepage` unless there is a specific reason to
change it.

It is not the Grafana Home Ops Cockpit. Grafana owns system truth, trends,
diagnosis, correlation, and historical investigation. Homepage can overlap with
Grafana only at the glance layer: compact status, alert counts, and links into
the right dashboard when something needs investigation.

## Rules

- Useful before decorative.
- Live widgets before prose.
- Short labels before descriptions.
- Current state before history.
- Triage and routing before diagnosis.
- Plain links are allowed, but they should sit below higher-signal widgets.
- Custom CSS is expected if it makes the page cleaner, calmer, and more
  professional.

## Content Model

Homepage should be organised around daily use, not app taxonomy:

- **Today:** weather, date/time, search, calendar, transit, appointments,
  reminders, and other personal admin.
- **At a Glance:** active streams, requests, download health, failed grabs,
  unhealthy services, active alerts, and media leaving soon.
- **Media:** Plex/Tautulli streams, Plex library counts, recently added media,
  Seerr requests, Radarr/Sonarr/Bazarr/Prowlarr state, media calendar, and
  Maintainerr leaving-soon media.
- **Downloads:** qBittorrent, SABnzbd, Autobrr, and Qui.
- **Home and Photos:** future Home Assistant and Immich glance cards, kept at
  summary level rather than replacing the owning apps.
- **Operations:** Gatus, Alertmanager, Grafana, Konflate, and small Kubernetes or
  Prometheus summaries only when immediately actionable.
- **Admin:** docs, repos, admin tools, utilities, and lower-frequency links.

Maintainerr is a good Homepage feature, but its API has no authentication. Any
custom Maintainerr widget or proxy must stay internal, expose only the small safe
payload Homepage needs, and avoid leaking settings or service API keys.

Do not recreate Grafana panels in Homepage unless the panel is genuinely useful
as a small glance card.

## Visual Direction

The target is clean, restrained, polished, and useful. It should feel like a
professional personal operations portal, not a generic launcher and not a
dashboard theme demo.

Preferred traits:

- dark theme
- strong spacing and alignment
- dense but readable cards
- widget metric blocks with consistent rhythm
- subtle personalisation
- no filler descriptions
- no empty config files
- no oversized decorative treatment that competes with the data

Background imagery is optional. If used, it should be quiet enough that text and
status remain the dominant layer.

## Iteration

1. Inventory the current app tree, native Homepage widgets, and required secrets.
2. Land high-signal content and layout before custom styling.
3. Add custom API or proxy work only when native widgets cannot express important
   content.
4. Add custom CSS after the content model is useful.
5. Use Playwright screenshots at desktop, laptop, and mobile widths for visual
   review.
6. Keep major content, custom API, and polish changes in separate pull requests.

Codex should make complete passes, post screenshots plus a short self-review,
then revise from one focused user correction. Final polish happens after the
dashboard is already useful.
