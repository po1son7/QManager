# 🚀 QManager BETA v0.1.22

A focused **Tower Locking** release. Locking to a specific LTE or 5G NR cell no longer requires copying EARFCN / PCI values out of Cellular Information by hand — a new **Simple Mode** lets you pick straight from the carriers your modem is currently using. Plus a round of translation-string additions for the community language packs to pick up.

## ✨ New Features

- **Tower Lock Simple Mode.** A new **Simple Mode** toggle on both the LTE and NR-SA Tower Locking cards lets you pick from your modem's currently active carriers in a dropdown instead of typing EARFCN / ARFCN and PCI manually. Each carrier label is color-coded by live RSRP, and slots already used elsewhere on the card are flagged with a *(used in slot N)* suffix and hard-prevented from being selected twice. On the NR-SA card the modem's reported ARFCN, PCI, Band, and Subcarrier Spacing are all filled in for you — and when SCS is inferred from the band's typical default rather than read from the modem, a small warning icon explains *"This is the typical SCS for N{{band}}. Your operator may use a different value — verify before locking."* If no carriers are detected, the dropdown explains why and you can flip back to Custom mode in one click.
- **2.5 Gbps Ethernet.** The Local Network → Ethernet Status card's **Set Link Speed** dropdown now offers a **2500 Mbps** option on hardware that supports it (e.g. carrier boards using a 2.5 G PHY like rework.network's 5G2PHY). The option only appears when the modem reports 2.5 G as a supported link mode — devices limited to 1 G PHYs see the same four choices as before. The Active Link Speed readout shows the friendlier `2.5 Gbps` once negotiation settles.

## ✅ Improvements

- **Tower Lock info tooltips.** Both **LTE Tower Locking Enabled** and **NR Tower Locking Enabled** toggles now have an info hint next to the label explaining what locking actually does (force the modem to attach only to the listed cells, identified by EARFCN/ARFCN + PCI). The toggle's helper text also updates with a clear **On** / **Off** state label so you can see at a glance which mode is armed.
- **Cleaner Tower Lock UI hints.** Hover/keyboard-focus hints on the Tower Lock cards moved from the older `Tooltip` pattern to the shared `HintIcon` component for consistency with the rest of the app.
- **Better band parsing.** Fixed a subtle bug in the band-list parser that would accept malformed composite values with empty halves; FR2 NR bands (the high-frequency mmWave range) are now covered by the parser tests.
- **Language-pack toasts.** Install / remove / switch toast messages now consistently include both the language name and its language code (e.g. *Language Italian (it) removed* instead of *it removed*), and there's a new generic **Failed to install language pack** fallback for cases where the pack name isn't yet known.
- **Wake-on-LAN card copy.** The Local Network → Wake-on-LAN card description and toast messages have been rewritten to focus on what the toggle actually does (powering the unit out of sleep via a magic packet) rather than the older Ethernet-LED side-effect framing.
- **Wake-on-LAN now disabled by default.** Fresh installs and upgrades now seed the Wake-on-LAN setting to **disabled**, which restores correct RJ45 LED behaviour out of the box on QCA8081-PHY carrier boards (the LEDs were the most common reason users were toggling this off manually anyway). If you previously toggled the Wake-on-LAN switch — to either enabled or disabled — your choice is **preserved** through this upgrade. Only users who never opened the Wake-on-LAN card see the new default applied.

## 🌐 Translations

This release adds new UI strings, primarily around the Tower Lock cards. Until a community translator publishes an updated pack, these specific strings will fall back to English in non-English locales — everything else continues to render in your selected language.

**Added** (English + Simplified Chinese shipped; Italian / Indonesian fall back to English until repackaged):

- `cellular.lte_tower_locking.enabled_tooltip` + `enabled_info_aria`
- `cellular.lte_tower_locking.simple_mode.*` — `toggle_label`, `switch_aria`, `info_aria`, `info_tooltip`, `empty_tooltip`, `select_placeholder`, `custom_value_label`, `slot_used_suffix`
- `cellular.nr_sa_tower_locking.enabled_tooltip` + `enabled_info_aria`
- `cellular.nr_sa_tower_locking.simple_mode.*` — `toggle_label`, `switch_aria`, `info_aria`, `info_tooltip`, `empty_tooltip`, `select_placeholder`, `custom_value_label`, `scs_band_default_warning`, `scs_warning_aria`
- `system-settings.languages.toast.install_failed_generic`
- Tighter wording on existing language-pack toasts (`install_started`, `install_success`, `install_failed`, `install_cancelled`, `remove_success`, `remove_failed`, `remove_active_switched`, `switched`) — the keys are unchanged but the strings now include the language code, so existing translations should be re-reviewed.
- Updated `local-network.ethernet_leds.card_title`, `card_description`, `toast_success_enabled`, `toast_success_disabled` for the Wake-on-LAN copy refresh.

**Removed:**

- `cellular.lte_tower_locking.use_current` — orphaned after the Simple Mode redesign.
- `cellular.nr_sa_tower_locking.use_current` — same.

If you maintain or contribute to a language pack, the [`docs/i18n/CONTRIBUTING.md`](https://github.com/dr-dolomite/QManager/blob/development-home/docs/i18n/CONTRIBUTING.md) guide walks through repackaging — `bun run i18n:check` will list the exact keys missing in your pack.

## 📥 Installation

### Fresh Install

```sh
curl -fsSL -o /tmp/qmanager-installer.sh https://raw.githubusercontent.com/dr-dolomite/QManager/development-home/qmanager-installer.sh && sh /tmp/qmanager-installer.sh
```

### Upgrading from v0.1.21

Head to **System Settings → Software Update** and run the update. **No migration steps required.**

Your Custom SIM Profiles, tower locks, Signal Failover settings, VPN config, watchdog preferences, SMS alerts, and installed language packs are all preserved.

## 💙 Thank You

Thanks to everyone testing the Simple Mode tower-lock flow and reporting edge cases on the carrier list. If you'd like to contribute a translation, the guide at [`docs/i18n/CONTRIBUTING.md`](https://github.com/dr-dolomite/QManager/blob/development-home/docs/i18n/CONTRIBUTING.md) walks you through it — no coding required.

Bug reports and feature requests are always welcome on [GitHub Issues](https://github.com/dr-dolomite/QManager/issues).

If you find QManager useful, consider [sponsoring on GitHub](https://github.com/sponsors/dr-dolomite) or sending GCash via Remitly to **Russel Yasol** (+639544817486).

<p align="center">
  <a href="https://github.com/sponsors/dr-dolomite">
    <img src="https://img.shields.io/badge/Sponsor%20QManager-ea4aaa?style=for-the-badge" alt="Sponsor QManager on GitHub" height="44">
  </a>
</p>

**License:** MIT + Commons Clause

**Happy connecting!**
