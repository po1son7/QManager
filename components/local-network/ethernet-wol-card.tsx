"use client";

import { useState, useEffect, useCallback } from "react";
import { useTranslation } from "react-i18next";
import { Loader2Icon } from "lucide-react";
import { toast } from "sonner";

import { SaveButton, useSaveFlash } from "@/components/ui/save-button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Field, FieldGroup, FieldLabel, FieldSet } from "@/components/ui/field";
import { Switch } from "@/components/ui/switch";
import { Skeleton } from "@/components/ui/skeleton";

import { useWolSetting } from "@/hooks/use-wol-setting";
import { resolveErrorMessage } from "@/lib/i18n/resolve-error";

// =============================================================================
// EthernetWolCard — Wake-on-LAN / RJ45 LED Fix
// =============================================================================
// Renders an opt-in toggle that disables eth0 WoL to restore RJ45 port LED
// behaviour on carrier boards using QCA8081 PHYs (rework.network 5G2PHY etc.).
//
// Returns null when data.supported === false so the card is invisible on
// hardware where WoL control is unavailable.
// =============================================================================

const EthernetWolCard = () => {
  const { t } = useTranslation("local-network");
  const { t: tErrors } = useTranslation("errors");
  const { data, isLoading, isSaving, isApplying, applyCountdown, saveWol } =
    useWolSetting();
  const { saved, markSaved } = useSaveFlash();

  // Local form state — mirrors data.enabled_fix
  const [disableWol, setDisableWol] = useState(false);

  // Sync from backend
  useEffect(() => {
    if (data) {
      setDisableWol(data.enabled_fix);
    }
  }, [data]);

  // Dirty check
  const isDirty = data ? disableWol !== data.enabled_fix : false;

  const handleToggle = useCallback((checked: boolean) => {
    setDisableWol(checked);
  }, []);

  const handleSave = useCallback(async () => {
    const result = await saveWol(disableWol);
    if (result.success) {
      markSaved();
      toast.success(
        disableWol
          ? t("ethernet_leds.toast_success_enabled")
          : t("ethernet_leds.toast_success_disabled"),
      );
    } else {
      toast.error(
        resolveErrorMessage(
          tErrors,
          result.errorCode,
          result.errorDetail,
          t("ethernet_leds.toast_error_save"),
        ),
      );
    }
  }, [disableWol, saveWol, markSaved, t, tErrors]);

  // --- Unsupported hardware: render nothing ----------------------------------
  if (!isLoading && data && !data.supported) {
    return null;
  }

  // --- Loading skeleton -------------------------------------------------------
  if (isLoading) {
    return (
      <Card className="@container/card">
        <CardHeader>
          <CardTitle>{t("ethernet_leds.card_title")}</CardTitle>
          <CardDescription>{t("ethernet_leds.card_description")}</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4">
            <Skeleton className="h-6 w-48" />
            <Skeleton className="h-10 w-28" />
          </div>
        </CardContent>
      </Card>
    );
  }

  // --- Normal render ----------------------------------------------------------
  return (
    <Card className="@container/card">
      <CardHeader>
        <CardTitle>{t("ethernet_leds.card_title")}</CardTitle>
        <CardDescription>{t("ethernet_leds.card_description")}</CardDescription>
      </CardHeader>
      <CardContent>
        <form
          className="grid gap-4"
          onSubmit={(e) => {
            e.preventDefault();
            handleSave();
          }}
        >
          <FieldSet>
            <FieldGroup>
              <Field orientation="horizontal" className="w-fit">
                <FieldLabel htmlFor="disable-wol">
                  {t("ethernet_leds.label_disable_wol")}
                </FieldLabel>
                <Switch
                  id="disable-wol"
                  checked={disableWol}
                  onCheckedChange={handleToggle}
                  disabled={isSaving || isApplying}
                />
              </Field>

              {isApplying && (
                <div className="flex items-center gap-2 text-sm text-muted-foreground">
                  <Loader2Icon className="size-3.5 animate-spin shrink-0" />
                  <span>
                    {t("ethernet_leds.applying", { seconds: applyCountdown })}
                  </span>
                </div>
              )}

              <SaveButton
                type="submit"
                isSaving={isSaving}
                saved={saved}
                label={t("actions.apply", { ns: "common" })}
                className="w-fit"
                disabled={!isDirty || isSaving || isApplying}
              />
            </FieldGroup>
          </FieldSet>
        </form>
      </CardContent>
    </Card>
  );
};

export default EthernetWolCard;
