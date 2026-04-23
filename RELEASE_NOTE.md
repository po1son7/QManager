# 🚀 QManager BETA v0.1.21

A small quality-of-life release: a new **Wake-on-LAN** control on the Local Network page, and two community-contributed language packs — **Italian** 🇮🇹 and **Indonesian** 🇮🇩.

## ✨ New Features

- **Wake-on-LAN card (Local Network).** Simple toggle to enable or disable Wake-on-LAN on the Ethernet port. When enabled, another device on the network can power this unit out of sleep by sending a magic packet; leave it disabled if you don't use it (most always-on modem gateways don't). The card auto-hides on hardware where WoL control isn't available. Toggling briefly bounces the Ethernet link (~2–5 seconds) — the UI shows a countdown and reconnects automatically.
- **Italian language pack 🇮🇹.** QManager's first community-contributed translation, courtesy of **@fmase**. Install it from **System Settings → Languages → Available** — the pack downloads directly to the device, no firmware update needed. Partial translations fall back to English, so you'll never see an untranslated blank string.
- **Indonesian language pack 🇮🇩.** Second community translation, courtesy of **@ikhsanh**. Install from the same Languages card. A handful of strings added late in this release cycle still fall back to English — a follow-up update is already requested.

## ✅ Improvements

- **Faster signal updates everywhere.** Per-antenna RSRP, RSRQ, and SINR now refresh every 2 seconds across Cellular Information, Antenna Statistics, and Antenna Alignment — five times more responsive than before. The dashboard Signal History chart now plots the last 10 seconds with relative `-10s … Now` labels (matching the Live Latency chart) so you can see signal swings the moment they happen. Antenna Alignment slot recordings finish in ~6 s instead of ~30 s.
- **Contributor-friendly i18n workflow.** The `docs/i18n/CONTRIBUTING.md` guide is live, and the language-pack publishing pipeline is now scripted — expect more community packs in upcoming releases.
- **Polished language-pack UI.** The sidebar switcher now shows both native and English names (e.g. *Italiano (Italian)*) with a base-code fallback so locales like `it-IT` no longer collapse to a bare `it`. Toast messages across install, remove, and activate flows now read formally and include the language code — e.g. *Language Italian (it) removed* instead of *it removed*.

## 📥 Installation

### Fresh Install

```sh
curl -fsSL -o /tmp/qmanager-installer.sh https://raw.githubusercontent.com/dr-dolomite/QManager/development-home/qmanager-installer.sh && sh /tmp/qmanager-installer.sh
```

### Upgrading from v0.1.20

Head to **System Settings → Software Update** and run the update. **No migration steps required.**

Your Custom SIM Profiles, tower locks, Signal Failover settings, VPN config, watchdog preferences, SMS alerts, and installed language packs are all preserved.

## 💙 Thank You

A huge thank you to **@fmase** and **@ikhsanh** for the Italian and Indonesian language packs — the first two community translations shipped with QManager. If you'd like to translate QManager into your language, the guide at [`docs/i18n/CONTRIBUTING.md`](https://github.com/dr-dolomite/QManager/blob/development-home/docs/i18n/CONTRIBUTING.md) walks you through it — no coding required.

Bug reports and feature requests are always welcome on [GitHub Issues](https://github.com/dr-dolomite/QManager/issues).

If you find QManager useful, consider [sponsoring on GitHub](https://github.com/sponsors/dr-dolomite) or sending GCash via Remitly to **Russel Yasol** (+639544817486).

<p align="center">
  <a href="https://github.com/sponsors/dr-dolomite">
    <img src="https://img.shields.io/badge/Sponsor%20QManager-ea4aaa?style=for-the-badge" alt="Sponsor QManager on GitHub" height="44">
  </a>
</p>

**License:** MIT + Commons Clause

**Happy connecting!**
