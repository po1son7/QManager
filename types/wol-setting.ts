// =============================================================================
// WoL Setting Types
// =============================================================================
// Type contracts for the Wake-on-LAN toggle endpoint.
// Endpoint: GET/POST /cgi-bin/quecmanager/network/wol.sh
// =============================================================================

export interface WolStatus {
  success: true;
  /** false if WoL control is unavailable on this hardware */
  supported: boolean;
  /** Present when supported=false */
  reason?: "ethtool_missing" | "no_eth0" | "wol_not_supported";
  /** UCI flag — user opted into WoL-disable (LED fix) */
  enabled_fix: boolean;
  /** Raw mode letters from ethtool e.g. "pg" or "d" */
  current_wol: string;
  /** Human-readable effective mode */
  effective_mode: "disabled" | "default";
}

export interface WolSaveRequest {
  disable_wol: boolean;
}

export interface WolSaveResponse {
  success: boolean;
  apply_in_progress?: boolean;
  /** Seconds the PHY link bounce is expected to take */
  disconnect_window_seconds?: number;
  disable_wol?: boolean;
  error?: string;
  detail?: string;
}
