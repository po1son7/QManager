"use client";

import { useCallback, useState, useMemo } from "react";
import { useTranslation, Trans } from "react-i18next";
import { toast } from "sonner";
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Field, FieldGroup, FieldLabel, FieldSet } from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Skeleton } from "@/components/ui/skeleton";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { SaveButton, useSaveFlash } from "@/components/ui/save-button";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import {
  AlertTriangle,
  CheckCircle2,
  Download,
  Loader2,
  PackageIcon,
  RefreshCcwIcon,
  Trash2Icon,
  Zap,
} from "lucide-react";
import { useVideoOptimizer } from "@/hooks/use-video-optimizer";
import { ServiceStats } from "../service-stats";
import { ServiceStatusBadge } from "../service-status-badge";
import { TbInfoCircleFilled } from "react-icons/tb";

function VideoOptimizerSkeleton() {
  return (
    <Card className="@container/card">
      <CardHeader>
        <Skeleton className="h-5 w-40" />
        <Skeleton className="h-4 w-72" />
      </CardHeader>
      <CardContent className="grid gap-4">
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-24 w-full" />
        <Skeleton className="h-32 w-full" />
      </CardContent>
    </Card>
  );
}

function VerificationDisplay({
  verifyResult,
  onRunTest,
  isRunning,
  serviceRunning,
}: {
  verifyResult: ReturnType<typeof useVideoOptimizer>["verifyResult"];
  onRunTest: () => void;
  isRunning: boolean;
  serviceRunning: boolean;
}) {
  const { t } = useTranslation("local-network");

  return (
    <div className="space-y-3">
      <div>
        <h4 className="text-sm font-medium">
          {t("video_optimizer.verify_title")}
        </h4>
        <p className="text-xs text-muted-foreground">
          {t("video_optimizer.verify_description")}
        </p>
      </div>

      {verifyResult.status === "complete" && verifyResult.passed === true && (
        <Alert className="border-success/30 bg-success/5">
          <CheckCircle2 className="text-success" />
          <AlertDescription className="text-success">
            <p>{verifyResult.message}</p>
          </AlertDescription>
        </Alert>
      )}

      {verifyResult.status === "complete" && verifyResult.passed === false && (
        <Alert className="border-warning/30 bg-warning/10">
          <AlertTriangle className="text-warning" />
          <AlertDescription className="text-warning">
            <p>{verifyResult.message}</p>
          </AlertDescription>
        </Alert>
      )}

      {verifyResult.status === "error" && verifyResult.error && (
        <Alert variant="destructive">
          <AlertTriangle className="size-4" />
          <AlertDescription>
            <p>{verifyResult.error}</p>
          </AlertDescription>
        </Alert>
      )}

      <Button
        variant="outline"
        className="w-full"
        onClick={onRunTest}
        disabled={isRunning || !serviceRunning}
      >
        {isRunning ? (
          <>
            <Loader2 className="animate-spin" />
            {t("video_optimizer.state_verifying")}
          </>
        ) : (
          <>
            <Zap />
            {t("video_optimizer.button_verify_service")}
          </>
        )}
      </Button>
    </div>
  );
}

interface VideoOptimizerSettingsCardProps {
  hook: ReturnType<typeof useVideoOptimizer>;
  otherActive?: boolean;
  onSaved?: () => void;
}

export default function VideoOptimizerSettingsCard({
  hook,
  otherActive = false,
  onSaved,
}: VideoOptimizerSettingsCardProps) {
  const { t } = useTranslation("local-network");
  const { settings, isLoading, error, refresh } = hook;

  const { installResult, runInstall } = hook;

  if (isLoading) return <VideoOptimizerSkeleton />;

  // H4: Error state — fetch failed, no settings to show
  if (error && !settings) {
    return (
      <Card className="@container/card">
        <CardHeader>
          <CardTitle>{t("video_optimizer.card_title")}</CardTitle>
          <CardDescription>
            {t("video_optimizer.card_description")}
          </CardDescription>
        </CardHeader>
        <CardContent aria-live="polite">
          <Alert variant="destructive">
            <AlertTriangle className="size-4" />
            <AlertDescription className="flex items-center justify-between">
              <span>{t("video_optimizer.error_load_failed")}</span>
              <Button variant="outline" size="sm" onClick={() => refresh()}>
                <RefreshCcwIcon className="size-3.5" />
                {t("actions.retry", { ns: "common" })}
              </Button>
            </AlertDescription>
          </Alert>
        </CardContent>
      </Card>
    );
  }

  // Not installed state — nfqws binary missing
  if (settings && !settings.binary_installed) {
    return (
      <Card className="@container/card">
        <CardHeader>
          <CardTitle>{t("video_optimizer.card_title")}</CardTitle>
          <CardDescription>
            {t("video_optimizer.card_description")}
          </CardDescription>
        </CardHeader>
        <CardContent aria-live="polite">
          <div className="flex flex-col items-center justify-center py-6 gap-4">
            <PackageIcon className="size-10 text-muted-foreground" />
            <div className="text-center space-y-1.5">
              <p className="text-sm font-medium">
                {t("video_optimizer.error_binary_not_installed")}
              </p>
              <p className="text-xs text-muted-foreground">
                <Trans
                  i18nKey="video_optimizer.error_download_zapret"
                  t={t}
                  components={{
                    link: (
                      <a
                        href="https://github.com/bol-van/zapret"
                        target="_blank"
                        rel="noopener noreferrer"
                        className="underline underline-offset-2"
                      />
                    ),
                  }}
                />
              </p>
            </div>

            {installResult.status === "complete" && (
              <Alert className="border-success/30 bg-success/5">
                <CheckCircle2 className="text-success" />
                <AlertDescription className="text-success">
                  <p>
                    {installResult.message}
                    {installResult.detail && (
                      <span className="text-muted-foreground">
                        {" "}
                        ({installResult.detail})
                      </span>
                    )}
                  </p>
                </AlertDescription>
              </Alert>
            )}

            {installResult.status === "error" && (
              <Alert variant="destructive">
                <AlertTriangle className="size-4" />
                <AlertDescription>
                  <p>
                    {installResult.message}
                    {installResult.detail && (
                      <span className="block text-xs mt-1 opacity-80">
                        {installResult.detail}
                      </span>
                    )}
                  </p>
                </AlertDescription>
              </Alert>
            )}

            <div className="flex items-center gap-2">
              <Button
                onClick={runInstall}
                disabled={installResult.status === "running"}
              >
                {installResult.status === "running" ? (
                  <>
                    <Loader2 className="animate-spin" />
                    {installResult.message ||
                      t("video_optimizer.state_installing")}
                  </>
                ) : (
                  <>
                    <Download />
                    {t("video_optimizer.button_install")}
                  </>
                )}
              </Button>
              <Button
                variant="outline"
                size="sm"
                onClick={() => refresh()}
                disabled={installResult.status === "running"}
              >
                <RefreshCcwIcon className="size-3.5" />
                {t("video_optimizer.button_check_again")}
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>
    );
  }

  // H3: Key-based remount — when settings change (initial load or post-save
  // re-fetch), the form reinitializes with fresh values from useState defaults.
  const formKey = settings
    ? `${settings.enabled}:${settings.desync_repeats}`
    : "empty";

  return (
    <VideoOptimizerForm
      key={formKey}
      hook={hook}
      otherActive={otherActive}
      onSaved={onSaved}
    />
  );
}

function VideoOptimizerForm({
  hook,
  otherActive,
  onSaved,
}: {
  hook: ReturnType<typeof useVideoOptimizer>;
  otherActive: boolean;
  onSaved?: () => void;
}) {
  const { t } = useTranslation("local-network");
  const {
    settings,
    isSaving,
    isUninstalling,
    error,
    saveSettings,
    verifyResult,
    runVerification,
    runUninstall,
    refresh,
  } = hook;

  const [isEnabled, setIsEnabled] = useState(settings?.enabled ?? false);
  const [repeatsText, setRepeatsText] = useState<string>(
    String(settings?.desync_repeats ?? 1),
  );
  const { saved, markSaved } = useSaveFlash();

  const repeatsValid = useMemo(() => {
    if (!/^\d+$/.test(repeatsText)) return false;
    const n = parseInt(repeatsText, 10);
    return n >= 1 && n <= 10;
  }, [repeatsText]);

  const isDirty = useMemo(() => {
    if (!settings) return false;
    const currentRepeats = settings.desync_repeats;
    const typedRepeats = repeatsValid ? parseInt(repeatsText, 10) : NaN;
    return isEnabled !== settings.enabled || typedRepeats !== currentRepeats;
  }, [settings, isEnabled, repeatsText, repeatsValid]);

  const handleSave = useCallback(
    async (e: React.FormEvent) => {
      e.preventDefault();
      if (!repeatsValid) {
        toast.error(t("invalid_repeats", { ns: "errors" }));
        return;
      }
      const desync_repeats = parseInt(repeatsText, 10);
      const success = await saveSettings({
        enabled: isEnabled,
        desync_repeats,
      });
      if (success) {
        markSaved();
        toast.success(
          isEnabled
            ? t("video_optimizer.toast_success_enabled")
            : t("video_optimizer.toast_success_disabled"),
        );
        onSaved?.();
      } else {
        toast.error(error || t("video_optimizer.toast_error_apply"));
      }
    },
    [
      isEnabled,
      repeatsText,
      repeatsValid,
      saveSettings,
      markSaved,
      error,
      onSaved,
      t,
    ],
  );

  const serviceStats = useMemo(
    () =>
      settings
        ? [
            { label: t("video_optimizer.stat_uptime"), value: settings.uptime },
            {
              label: t("video_optimizer.stat_packets_processed"),
              value: settings.packets_processed.toLocaleString(),
            },
            {
              label: t("video_optimizer.stat_domains_protected"),
              value: settings.domains_loaded.toString(),
            },
          ]
        : [],
    [settings, t],
  );

  const canEnable =
    settings?.binary_installed &&
    settings?.kernel_module_loaded &&
    !otherActive;
  // Allow toggling OFF even when canEnable is false (e.g., other feature is active)
  const canToggle = canEnable || settings?.enabled;
  const isRunning = settings?.status === "running";

  return (
    <Card className="@container/card">
      <CardHeader>
        <CardTitle>{t("video_optimizer.card_title")}</CardTitle>
        <CardDescription>
          {t("video_optimizer.card_description_full")}
        </CardDescription>
      </CardHeader>
      <CardContent aria-live="polite">
        {otherActive ? (
          <Alert className="border-warning/30 bg-warning/10 text-warning mb-4">
            <AlertTriangle className="size-4" />
            <AlertDescription className="text-warning">
              {t("video_optimizer.alert_masquerade_active")}
            </AlertDescription>
          </Alert>
        ) : (
          <Alert className="border-warning/30 bg-warning/10 text-warning mb-4">
            <AlertTriangle className="size-4" />
            <AlertTitle className="text-warning">
              {t("video_optimizer.badge_experimental")}
            </AlertTitle>
          </Alert>
        )}

        {!settings?.kernel_module_loaded && (
          <Alert className="mb-4">
            <AlertTriangle className="size-4" />
            <AlertDescription>
              <p>
                <Trans
                  i18nKey="video_optimizer.alert_kernel_module_missing"
                  ns="local-network"
                  components={{
                    code: (
                      <code className="rounded bg-muted px-1 py-0.5 text-xs font-mono" />
                    ),
                  }}
                />
              </p>
            </AlertDescription>
          </Alert>
        )}

        <form className="grid gap-4" onSubmit={handleSave}>
          <FieldSet>
            <Separator />
            <FieldGroup>
              <div className="flex items-center justify-between">
                <Field orientation="horizontal" className="w-fit">
                  <FieldLabel htmlFor="dpi-enabled">
                    {t("video_optimizer.label_enable")}
                  </FieldLabel>
                  <Switch
                    id="dpi-enabled"
                    checked={isEnabled}
                    onCheckedChange={setIsEnabled}
                    disabled={!canToggle || isSaving}
                    aria-label={t("video_optimizer.aria_enable")}
                  />
                </Field>
                {settings && (
                  <CardAction>
                    <ServiceStatusBadge
                      status={settings.status}
                      installed={settings.binary_installed}
                    />
                  </CardAction>
                )}
              </div>

              {isRunning && settings && (
                <>
                  <Separator />
                  <ServiceStats stats={serviceStats} />

                  <Separator />

                  <VerificationDisplay
                    verifyResult={verifyResult}
                    onRunTest={runVerification}
                    isRunning={verifyResult.status === "running"}
                    serviceRunning={isRunning}
                  />
                </>
              )}

              <Separator />

              <Field orientation="vertical" className="gap-2">
                <div className="flex items-center gap-2">
                                    <Tooltip>
                    <TooltipTrigger asChild>
                      <button
                        type="button"
                        className="inline-flex"
                        aria-label={t("core_settings.info.cell_data.info_aria")}
                      >
                        <TbInfoCircleFilled className="size-5 text-info" />
                      </button>
                    </TooltipTrigger>
                    <TooltipContent>
                      <p className="max-w-xs">
                        {t("video_optimizer.help_desync_repeats")}
                      </p>
                    </TooltipContent>
                  </Tooltip>
                  <FieldLabel htmlFor="dpi-desync-repeats">
                    {t("video_optimizer.label_desync_repeats")}
                  </FieldLabel>
                </div>
                <Input
                  id="dpi-desync-repeats"
                  type="number"
                  inputMode="numeric"
                  min={1}
                  max={10}
                  step={1}
                  value={repeatsText}
                  onChange={(e) => setRepeatsText(e.target.value)}
                  disabled={isSaving}
                  aria-invalid={!repeatsValid}
                  className="w-24 max-w-xs"
                />
              </Field>

              <Separator />
            </FieldGroup>
          </FieldSet>
          <div>
            <SaveButton
              type="submit"
              isSaving={isSaving}
              saved={saved}
              disabled={!isDirty || !canToggle || !repeatsValid}
            />
          </div>
        </form>

        {!isRunning && (
          <>
            <Separator className="mt-4" />
            <div className="flex items-center justify-between pt-4">
              <div>
                <p className="text-sm font-medium">
                  {t("video_optimizer.section_remove_binary")}
                </p>
                <p className="text-xs text-muted-foreground">
                  {t("video_optimizer.section_remove_binary_desc")}
                </p>
              </div>
              <AlertDialog>
                <AlertDialogTrigger asChild>
                  <Button
                    variant="destructive"
                    size="sm"
                    disabled={isUninstalling || isRunning}
                  >
                    {isUninstalling ? (
                      <>
                        <Loader2 className="size-4 animate-spin" />
                        {t("video_optimizer.state_removing")}
                      </>
                    ) : (
                      <>
                        <Trash2Icon className="size-4" />
                        {t("video_optimizer.button_uninstall")}
                      </>
                    )}
                  </Button>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>
                      {t("video_optimizer.dialog_uninstall_title")}
                    </AlertDialogTitle>
                    <AlertDialogDescription>
                      {t("video_optimizer.dialog_uninstall_desc")}
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>
                      {t("actions.cancel", { ns: "common" })}
                    </AlertDialogCancel>
                    <AlertDialogAction
                      className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                      onClick={async () => {
                        const success = await runUninstall();
                        if (success) {
                          toast.success(
                            t("video_optimizer.toast_uninstall_success"),
                          );
                          refresh();
                        } else {
                          toast.error(
                            error || t("video_optimizer.toast_uninstall_error"),
                          );
                        }
                      }}
                    >
                      {t("video_optimizer.button_uninstall")}
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </div>
          </>
        )}
      </CardContent>
    </Card>
  );
}
