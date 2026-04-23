"use client";

import { useState, useCallback, useRef, useEffect } from "react";
import { useTranslation } from "react-i18next";
import { authFetch } from "@/lib/auth-fetch";
import { resolveErrorMessage } from "@/lib/i18n/resolve-error";
import type { WolStatus, WolSaveResponse } from "@/types/wol-setting";

// =============================================================================
// useWolSetting — Wake-on-LAN Toggle Hook
// =============================================================================
// Fetches current WoL state on mount. Provides saveWol for applying the
// disable-WoL LED fix.
//
// Critical: POST triggers a ~2-5 s PHY link bounce on eth0. The hook enters
// an "applying" window during which fetch errors are swallowed (false
// positives due to the link drop). After the window expires it retries with
// exponential backoff until the device is reachable again.
//
// Backend endpoint:
//   GET/POST /cgi-bin/quecmanager/network/wol.sh
// =============================================================================

const CGI_ENDPOINT = "/cgi-bin/quecmanager/network/wol.sh";

// Retry schedule after the disconnect window: 1s, 2s, 4s then every 8s until
// ~30 s total has elapsed.
const RETRY_DELAYS_MS = [1000, 2000, 4000, 8000, 8000, 8000];

export interface SaveWolResult {
  success: boolean;
  errorCode?: string;
  errorDetail?: string;
}

export interface UseWolSettingReturn {
  /** Current WoL status data (null before first fetch) */
  data: WolStatus | null;
  /** True while the initial fetch is in progress */
  isLoading: boolean;
  /** True while the POST save request is in-flight */
  isSaving: boolean;
  /** True during the disconnect window after a successful save */
  isApplying: boolean;
  /** Seconds remaining in the disconnect window */
  applyCountdown: number;
  /** Error message if fetch or save failed */
  error: string | null;
  /** Re-fetch WoL status */
  refresh: () => Promise<void>;
  /** Toggle WoL disable. Returns a result object with raw error codes on failure. */
  saveWol: (disable_wol: boolean) => Promise<SaveWolResult>;
}

export function useWolSetting(): UseWolSettingReturn {
  const { t } = useTranslation("errors");
  const [data, setData] = useState<WolStatus | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isApplying, setIsApplying] = useState(false);
  const [applyCountdown, setApplyCountdown] = useState(0);
  const [error, setError] = useState<string | null>(null);

  const mountedRef = useRef(true);
  const countdownRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
      if (countdownRef.current) {
        clearInterval(countdownRef.current);
      }
    };
  }, []);

  // ---------------------------------------------------------------------------
  // Fetch current WoL status
  // ---------------------------------------------------------------------------
  const fetchWol = useCallback(
    async (silent = false): Promise<void> => {
      if (!silent) setIsLoading(true);
      setError(null);

      try {
        const resp = await authFetch(CGI_ENDPOINT);
        if (!resp.ok) {
          throw new Error(`HTTP ${resp.status}: ${resp.statusText}`);
        }

        const json = await resp.json();
        if (!mountedRef.current) return;

        if (!json.success) {
          setError(
            resolveErrorMessage(
              t,
              json.error,
              json.detail,
              "Failed to fetch Wake-on-LAN status",
            ),
          );
          return;
        }

        setData(json as WolStatus);
      } catch (err) {
        if (!mountedRef.current) return;
        setError(
          err instanceof Error
            ? err.message
            : "Failed to fetch Wake-on-LAN status",
        );
      } finally {
        if (mountedRef.current && !silent) {
          setIsLoading(false);
        }
      }
    },
    [t],
  );

  // Fetch on mount
  useEffect(() => {
    fetchWol();
  }, [fetchWol]);

  // ---------------------------------------------------------------------------
  // Save WoL setting
  // ---------------------------------------------------------------------------
  const saveWol = useCallback(
    async (disable_wol: boolean): Promise<SaveWolResult> => {
      setError(null);
      setIsSaving(true);

      let resp: Response;
      try {
        resp = await authFetch(CGI_ENDPOINT, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ disable_wol }),
        });
      } catch (err) {
        const detail = err instanceof Error ? err.message : "Failed to save Wake-on-LAN setting";
        if (mountedRef.current) {
          setError(detail);
          setIsSaving(false);
        }
        return { success: false, errorDetail: detail };
      }

      if (!resp.ok) {
        // Try to extract error from body; fall back to HTTP status message.
        let json: WolSaveResponse | null = null;
        try {
          json = await resp.json();
        } catch {
          // ignore parse error
        }
        if (mountedRef.current) {
          setError(
            resolveErrorMessage(
              t,
              json?.error,
              json?.detail,
              `HTTP ${resp.status}: ${resp.statusText}`,
            ),
          );
          setIsSaving(false);
        }
        return { success: false, errorCode: json?.error, errorDetail: json?.detail };
      }

      let json: WolSaveResponse;
      try {
        json = await resp.json();
      } catch {
        if (mountedRef.current) {
          setError("Failed to parse save response");
          setIsSaving(false);
        }
        return { success: false };
      }

      if (!json.success) {
        if (mountedRef.current) {
          setError(
            resolveErrorMessage(
              t,
              json.error,
              json.detail,
              "Failed to save Wake-on-LAN setting",
            ),
          );
          setIsSaving(false);
        }
        return { success: false, errorCode: json.error, errorDetail: json.detail };
      }

      // --- Disconnect window ---------------------------------------------------
      if (json.apply_in_progress) {
        const windowSec = json.disconnect_window_seconds ?? 8;

        if (!mountedRef.current) return { success: false };
        setIsSaving(false);
        setIsApplying(true);
        setApplyCountdown(windowSec);

        // Count down every second
        countdownRef.current = setInterval(() => {
          if (!mountedRef.current) {
            if (countdownRef.current) clearInterval(countdownRef.current);
            return;
          }
          setApplyCountdown((prev) => {
            const next = prev - 1;
            if (next <= 0) {
              if (countdownRef.current) {
                clearInterval(countdownRef.current);
                countdownRef.current = null;
              }
            }
            return next > 0 ? next : 0;
          });
        }, 1000);

        // Wait for the disconnect window to elapse before retrying
        await new Promise<void>((resolve) =>
          setTimeout(resolve, windowSec * 1000),
        );

        // Clear countdown interval if still running
        if (countdownRef.current) {
          clearInterval(countdownRef.current);
          countdownRef.current = null;
        }

        // Retry with exponential backoff until success or ~30 s timeout
        let succeeded = false;
        for (const delayMs of RETRY_DELAYS_MS) {
          if (!mountedRef.current) break;

          try {
            const retryResp = await authFetch(CGI_ENDPOINT);
            if (retryResp.ok) {
              const retryJson = await retryResp.json();
              if (retryJson.success && mountedRef.current) {
                setData(retryJson as WolStatus);
                succeeded = true;
                break;
              }
            }
          } catch {
            // Swallow — likely still in the link-bounce window; wait and retry
          }

          if (!mountedRef.current) break;
          await new Promise<void>((resolve) => setTimeout(resolve, delayMs));
        }

        if (mountedRef.current) {
          setIsApplying(false);
          setApplyCountdown(0);
          if (!succeeded) {
            const timeoutDetail = "Device did not respond after applying Wake-on-LAN setting";
            setError(timeoutDetail);
            return { success: false, errorDetail: timeoutDetail };
          }
        }
        return succeeded ? { success: true } : { success: false };
      }

      // Fallback: normal success path (no disconnect window)
      if (mountedRef.current) {
        setIsSaving(false);
        await fetchWol(true);
      }
      return { success: true };
    },
    [t, fetchWol],
  );

  return {
    data,
    isLoading,
    isSaving,
    isApplying,
    applyCountdown,
    error,
    refresh: fetchWol,
    saveWol,
  };
}
