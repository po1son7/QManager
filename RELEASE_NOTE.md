# 🚀 QManager BETA v0.1.20

A small but important reliability release for remote operators. The **Reconnect Modem** action in the user menu is now safe to use over Tailscale (or any VPN riding on the cellular link) without locking yourself out of your device.

## 🛠️ Fix — Reconnect Modem no longer locks out remote users

- **The bug.** Reconnect Modem issued `AT+COPS=2` (detach) and `AT+COPS=0` (reattach) as two separate HTTP requests from the browser, with a 3-second delay in between. When you were connected over Tailscale, the first request succeeded and immediately killed the cellular link — which killed Tailscale — which meant the second request (the one that tells the modem to reattach) never arrived. The modem was stranded deregistered and only a physical reboot could recover it.
- **The fix.** The full detach → wait → reattach sequence now runs on-device via a single CGI call (`/cgi-bin/quecmanager/at_cmd/reconnect_modem.sh`). The browser fires one request and the device completes the whole procedure locally, including a deliberate 2-second gap so the modem fully detaches before reselecting. Your browser session may still blip while the cellular link cycles, but the modem always reattaches on its own.
- **Safe over Tailscale, WireGuard, NetBird, or any tunnel that rides the modem's data path.** Also safer on flaky Wi-Fi admin sessions — no more "I clicked Reconnect and now I can't reach the modem."

## 🛠️ Fix — Tower Lock no longer resets your custom MTU

Locking/unlocking a cell (manual, Signal Failover, or scheduled) briefly bounced the data interface and the Quectel driver reset MTU to 1500. The old watcher gave up after one attempt and lost the race. The watcher now verifies MTU is stable across two consecutive reads and re-applies up to 3 times if the driver resets it again. Covers all lock/unlock paths.

## ✅ Improvements

- **Cleaner reconnect UX.** The "Disconnecting… / Reconnecting…" step indicator still transitions exactly as before — the visual flow is unchanged, only the transport underneath is fixed.
- **MTU watcher logs its outcome.** Every lock/unlock emits `MTU stable at <value>` or `MTU already correct at <value>` to `logread` — quick confirmation your MTU survived.
- **New Ethernet Port LEDs card (Local Network).** Opt-in toggle that disables Wake-on-LAN on `eth0` to restore RJ45 port LEDs on carrier boards that suppress them while WoL is armed — notably **rework.network's 5G2PHY** and other QCA8081-based designs. No functional impact: Wake-on-LAN is unused on always-on gateway devices. The card auto-hides on hardware where WoL control isn't available, so you'll only see it if it's useful. Toggling the switch briefly bounces the Ethernet link (~2–5 seconds) — the UI shows a countdown and reconnects automatically.

## 📥 Installation

### Fresh Install

```sh
curl -fsSL -o /tmp/qmanager-installer.sh https://raw.githubusercontent.com/dr-dolomite/QManager/development-home/qmanager-installer.sh && sh /tmp/qmanager-installer.sh
```

### Upgrading from v0.1.19

Head to **System Settings → Software Update** and run the update. **No migration steps required.**

Your Custom SIM Profiles, tower locks, Signal Failover settings, VPN config, watchdog preferences, SMS alerts, and language packs are all preserved.

## 💙 Thank You

Special shout-out to **Outright** for the continued support and the field-side bug reports that drove this release — the Tailscale lockout in particular was exactly the kind of "works on my desk, breaks in the wild" issue that only surfaces with real-world remote operators. Thank you for the careful testing and detailed reproductions.

Bug reports and feature requests are always welcome on [GitHub Issues](https://github.com/dr-dolomite/QManager/issues).

If you find QManager useful, consider [sponsoring on GitHub](https://github.com/sponsors/dr-dolomite) or sending GCash via Remitly to **Russel Yasol** (+639544817486).

<p align="center">
  <a href="https://github.com/sponsors/dr-dolomite">
    <img src="https://img.shields.io/badge/Sponsor%20QManager-ea4aaa?style=for-the-badge" alt="Sponsor QManager on GitHub" height="44">
  </a>
</p>

**License:** MIT + Commons Clause

**Happy connecting!**
