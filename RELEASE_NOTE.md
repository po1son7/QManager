# 🚀 QManager BETA v0.1.21

A small quality-of-life release: a new **Ethernet Port LEDs** control for carrier boards that suppress RJ45 LEDs, and our first community-contributed language pack — **Italian** 🇮🇹.

## ✨ New Features

- **Ethernet Port LEDs card (Local Network).** Opt-in toggle that disables Wake-on-LAN on `eth0` to restore RJ45 port LEDs on carrier boards that suppress them while WoL is armed — notably **rework.network's 5G2PHY** and other QCA8081-based designs. No functional impact: Wake-on-LAN is unused on always-on gateway devices. The card auto-hides on hardware where WoL control isn't available, so you'll only see it if it's useful. Toggling the switch briefly bounces the Ethernet link (~2–5 seconds) — the UI shows a countdown and reconnects automatically.
- **Italian language pack 🇮🇹.** QManager's first community-contributed translation, courtesy of **@fmase**. Install it from **System Settings → Languages → Available** — the pack downloads directly to the device, no firmware update needed. Partial translations fall back to English, so you'll never see an untranslated blank string.

## ✅ Improvements

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

A huge thank you to **@fmase** for contributing the Italian language pack — the first community translation shipped with QManager. If you'd like to translate QManager into your language, the guide at [`docs/i18n/CONTRIBUTING.md`](https://github.com/dr-dolomite/QManager/blob/development-home/docs/i18n/CONTRIBUTING.md) walks you through it — no coding required.

Bug reports and feature requests are always welcome on [GitHub Issues](https://github.com/dr-dolomite/QManager/issues).

If you find QManager useful, consider [sponsoring on GitHub](https://github.com/sponsors/dr-dolomite) or sending GCash via Remitly to **Russel Yasol** (+639544817486).

<p align="center">
  <a href="https://github.com/sponsors/dr-dolomite">
    <img src="https://img.shields.io/badge/Sponsor%20QManager-ea4aaa?style=for-the-badge" alt="Sponsor QManager on GitHub" height="44">
  </a>
</p>

**License:** MIT + Commons Clause

**Happy connecting!**
