#!/bin/sh
. /usr/lib/qmanager/cgi_base.sh
# =============================================================================
# wol.sh — CGI Endpoint: Wake-on-LAN Toggle (GET + POST)
# =============================================================================
# Opt-in toggle that disables eth0 Wake-on-LAN to restore RJ45 port LED
# behaviour on carrier boards using QCA8081 PHYs (e.g. rework.network
# 5G2PHY).  Disabling WoL has zero functional impact on always-on modem
# gateways.
#
# GET:  Returns WoL support probe + current state + UCI flag.
# POST: Saves UCI flag and fire-and-forgets ethtool apply so the HTTP
#       response flushes before the ~2-5 s PHY link bounce.
#
# GET response:
#   { success, supported, [reason], enabled_fix, current_wol, effective_mode }
#
# POST body:   { "disable_wol": true|false }
# POST response:
#   { success, apply_in_progress, disconnect_window_seconds, disable_wol }
#
# Endpoint: GET/POST /cgi-bin/quecmanager/network/wol.sh
# Install location: /www/cgi-bin/quecmanager/network/wol.sh
# =============================================================================

# --- Logging -----------------------------------------------------------------
qlog_init "cgi_wol"
cgi_headers
cgi_handle_options

# --- Events (for append_event) -----------------------------------------------
EVENTS_FILE="/tmp/qmanager_events.json"
MAX_EVENTS=50
. /usr/lib/qmanager/events.sh 2>/dev/null || {
    append_event() { :; }
}

ETH_INTERFACE="eth0"

# --- Helper: ensure UCI network section exists --------------------------------
ensure_uci_section() {
    if ! uci get quecmanager.network >/dev/null 2>&1; then
        uci set quecmanager.network=network
        uci commit quecmanager
    fi
}

# --- Helper: WoL support probe ------------------------------------------------
# Sets globals: wol_supported (true|false), wol_reason, wol_current, wol_effective
probe_wol_support() {
    wol_supported="false"
    wol_reason=""
    wol_current=""
    wol_effective="default"

    # Check 1: ethtool must be present
    if ! command -v ethtool >/dev/null 2>&1; then
        wol_reason="ethtool_missing"
        return 0
    fi

    # Check 2: eth0 must exist
    if [ ! -d "/sys/class/net/$ETH_INTERFACE" ]; then
        wol_reason="no_eth0"
        return 0
    fi

    # Check 3: interface must support WoL (needs 'g' in Supports Wake-on)
    eth_output=$(ethtool "$ETH_INTERFACE" 2>/dev/null)
    supports_line=$(printf '%s' "$eth_output" | grep "Supports Wake-on:")
    if [ -z "$supports_line" ]; then
        wol_reason="wol_not_supported"
        return 0
    fi
    supports_modes=$(printf '%s' "$supports_line" | awk '{print $3}')
    case "$supports_modes" in
        *g*) ;;
        *)
            wol_reason="wol_not_supported"
            return 0
            ;;
    esac

    # Supported — read current Wake-on mode
    wol_supported="true"
    wake_line=$(printf '%s' "$eth_output" | grep "Wake-on:" | grep -v "Supports")
    wol_current=$(printf '%s' "$wake_line" | awk '{print $2}')
    [ -z "$wol_current" ] && wol_current=""

    if [ "$wol_current" = "d" ]; then
        wol_effective="disabled"
    else
        wol_effective="default"
    fi
}

# =============================================================================
# GET — Read WoL support + current state
# =============================================================================
if [ "$REQUEST_METHOD" = "GET" ]; then
    qlog_info "Reading WoL status for $ETH_INTERFACE"

    probe_wol_support

    # Read UCI flag
    ensure_uci_section
    uci_val=$(uci get quecmanager.network.disable_wol 2>/dev/null)
    if [ "$uci_val" = "1" ]; then
        enabled_fix="true"
    else
        enabled_fix="false"
    fi

    if [ "$wol_supported" = "true" ]; then
        qlog_info "WoL supported: current=$wol_current effective=$wol_effective enabled_fix=$enabled_fix"
        jq -n \
            --argjson enabled_fix "$enabled_fix" \
            --arg current_wol "$wol_current" \
            --arg effective_mode "$wol_effective" \
            '{
                success: true,
                supported: true,
                enabled_fix: $enabled_fix,
                current_wol: $current_wol,
                effective_mode: $effective_mode
            }'
    else
        qlog_info "WoL not supported: reason=$wol_reason"
        jq -n \
            --arg reason "$wol_reason" \
            '{
                success: true,
                supported: false,
                reason: $reason,
                enabled_fix: false,
                current_wol: "",
                effective_mode: "default"
            }'
    fi
    exit 0
fi

# =============================================================================
# POST — Save disable_wol setting
# =============================================================================
if [ "$REQUEST_METHOD" = "POST" ]; then

    cgi_read_post

    # --- Validate disable_wol field -------------------------------------------
    # Don't use `// default` — jq's `//` coalesces on false AND null, so
    # {"disable_wol": false} would trip the missing path. Check presence and
    # type explicitly via `has` + `type`.
    disable_wol_check=$(printf '%s' "$POST_DATA" | jq -r '
        if type != "object" then "not_object"
        elif has("disable_wol") | not then "missing"
        elif (.disable_wol | type) != "boolean" then "not_boolean"
        else (.disable_wol | tostring)
        end
    ' 2>/dev/null)

    case "$disable_wol_check" in
        true|false)
            disable_wol="$disable_wol_check"
            ;;
        *)
            cgi_error "missing_field" "disable_wol must be a boolean"
            exit 0
            ;;
    esac

    # --- Re-run support probe -------------------------------------------------
    probe_wol_support

    if [ "$wol_supported" != "true" ]; then
        qlog_error "WoL not supported on this hardware: $wol_reason"
        cgi_error "wol_not_supported" "Wake-on-LAN control not supported on this hardware"
        exit 0
    fi

    qlog_info "Saving disable_wol=$disable_wol"

    # --- Persist to UCI -------------------------------------------------------
    ensure_uci_section
    if [ "$disable_wol" = "true" ]; then
        uci set quecmanager.network.disable_wol=1 2>/dev/null
    else
        uci set quecmanager.network.disable_wol=0 2>/dev/null
    fi

    if ! uci commit quecmanager 2>/dev/null; then
        qlog_error "uci commit failed"
        cgi_error "wol_save_failed" "Failed to persist Wake-on-LAN setting"
        exit 0
    fi

    # --- Emit network event ---------------------------------------------------
    if [ "$disable_wol" = "true" ]; then
        append_event "wol_changed" "Wake-on-LAN disabled (LED fix enabled)" "info"
    else
        append_event "wol_changed" "Wake-on-LAN enabled (default)" "info"
    fi

    # --- Emit HTTP response BEFORE PHY change ---------------------------------
    jq -n \
        --argjson disable_wol "$([ "$disable_wol" = "true" ] && echo "true" || echo "false")" \
        '{
            success: true,
            apply_in_progress: true,
            disconnect_window_seconds: 8,
            disable_wol: $disable_wol
        }'

    # --- Fire-and-forget ethtool apply (double-fork) -------------------------
    # 1 s delay ensures HTTP bytes flush before the PHY link bounce.
    if [ "$disable_wol" = "true" ]; then
        ( ( sleep 1 && ethtool -s "$ETH_INTERFACE" wol d ) </dev/null >/dev/null 2>&1 & )
    else
        ( ( sleep 1 && ethtool -s "$ETH_INTERFACE" wol g ) </dev/null >/dev/null 2>&1 & )
    fi

    exit 0
fi

# --- Method not allowed -------------------------------------------------------
cgi_method_not_allowed
