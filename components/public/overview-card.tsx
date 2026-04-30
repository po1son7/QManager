"use client";

import Link from "next/link";
import { useTranslation } from "react-i18next";
import { motion } from "motion/react";
import {
  CheckCircle2Icon,
  Loader2Icon,
  MinusCircleIcon,
  TriangleAlertIcon,
  XCircleIcon,
  type LucideIcon,
} from "lucide-react";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";

import { usePublicOverview } from "@/hooks/use-public-overview";
import {
  deriveConnectionLabel,
  formatBands,
  formatPcis,
  formatUptime,
} from "@/lib/public-overview/format";
import { getSignalQuality, RSRP_THRESHOLDS } from "@/types/modem-status";
import type { ConnectionState } from "@/types/modem-status";
import { useEffect } from "react";

// ---------- Connection badge mapping ---------------------------------------

interface BadgeStyle {
  classes: string;
  Icon: LucideIcon;
  spin?: boolean;
}

function badgeStyleFor(label: ConnectionState | "modem_unreachable"): BadgeStyle {
  switch (label) {
    case "connected":
      return {
        classes:
          "bg-success/15 text-success hover:bg-success/20 border-success/30",
        Icon: CheckCircle2Icon,
      };
    case "limited":
      return {
        classes:
          "bg-warning/15 text-warning hover:bg-warning/20 border-warning/30",
        Icon: TriangleAlertIcon,
      };
    case "searching":
      return {
        classes: "bg-info/15 text-info hover:bg-info/20 border-info/30",
        Icon: Loader2Icon,
        spin: true,
      };
    case "inactive":
    case "unknown":
      return {
        classes:
          "bg-muted/50 text-muted-foreground border-muted-foreground/30",
        Icon: MinusCircleIcon,
      };
    case "disconnected":
    case "error":
    case "modem_unreachable":
    default:
      return {
        classes:
          "bg-destructive/15 text-destructive hover:bg-destructive/20 border-destructive/30",
        Icon: XCircleIcon,
      };
  }
}

// ---------- Component ------------------------------------------------------

export default function OverviewCard() {
  const { t } = useTranslation("common");
  const { data, isLoading, isStale, error } = usePublicOverview();

  // Setup gate: bounce to /setup/ on a fresh-install device.
  useEffect(() => {
    if (data?.state === "setup_required") {
      window.location.href = "/setup/";
    }
  }, [data]);

  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, ease: "easeOut" }}
    >
      <Card className="@container/overview w-full">
        <CardHeader className="items-center text-center">
          <div className="flex size-12 items-center justify-center">
            <img
              src="/qmanager-logo.svg"
              alt="QManager Logo"
              className="size-full"
            />
          </div>
          <CardTitle>{t("overview.title")}</CardTitle>
          <CardDescription>{t("overview.tagline")}</CardDescription>
        </CardHeader>

        <CardContent className="flex flex-col gap-6">
          {renderBody({ data, isLoading, isStale, error, t })}

          <Button asChild className="w-full">
            <Link href="/login/">{t("overview.login_button")}</Link>
          </Button>
        </CardContent>

        <CardFooter className="flex justify-center">
          <p className="text-muted-foreground text-xs">
            {t("overview.copyright", { year: new Date().getFullYear() })}
          </p>
        </CardFooter>
      </Card>
    </motion.div>
  );
}

// ---------- Body renderer --------------------------------------------------

interface BodyProps {
  data: ReturnType<typeof usePublicOverview>["data"];
  isLoading: boolean;
  isStale: boolean;
  error: string | null;
  t: (key: string, opts?: Record<string, unknown>) => string;
}

function renderBody({ data, isLoading, isStale, error, t }: BodyProps) {
  // Loading skeleton (first paint, no data yet)
  if (isLoading && !data) {
    return <SkeletonBody />;
  }

  // Setup-required: hook is redirecting; keep the body neutral.
  if (data?.state === "setup_required") {
    return <SkeletonBody />;
  }

  // Network error with no usable data → empty state.
  if (error && !data) {
    return (
      <EmptyState
        title={t("overview.empty.title")}
        subtitle={t("overview.empty.fetch_error")}
      />
    );
  }

  // Unavailable (poller down, parse error)
  if (data?.state === "unavailable") {
    return (
      <EmptyState
        title={t("overview.empty.title")}
        subtitle={t("overview.empty.subtitle")}
      />
    );
  }

  // From here on, data.state === "ok"
  if (!data || data.state !== "ok") {
    return <SkeletonBody />;
  }

  const reachable = data.modem_reachable;
  const connectionLabel: ConnectionState | "modem_unreachable" = reachable
    ? deriveConnectionLabel(data.network.lte_state, data.network.nr_state)
    : "modem_unreachable";
  const badge = badgeStyleFor(connectionLabel);
  const networkType = data.network.type || t("overview.connection.unknown");

  const quality = getSignalQuality(data.signal.rsrp, RSRP_THRESHOLDS);
  const qualityLabel = t(`overview.quality.${quality}`);
  const signalLine = formatSignalLine(data.signal, t, reachable);

  const uptime = formatUptime(data.uptime_seconds);
  const uptimeText = t(`overview.uptime.${uptime.key}`, { ...uptime });

  const rowsMutedClass = reachable ? "" : "text-muted-foreground";

  return (
    <div className="flex flex-col gap-5">
      {/* Connection state row — aria-live scoped here so only badge transitions
          (e.g. connected → searching) are announced, not per-poll uptime ticks. */}
      <div
        className="flex flex-wrap items-center gap-2"
        aria-live="polite"
        aria-atomic="true"
      >
        <Badge variant="outline" className={badge.classes}>
          <badge.Icon
            className={`size-3 ${badge.spin ? "animate-spin" : ""}`}
            aria-hidden
          />
          {connectionLabel === "modem_unreachable"
            ? t("overview.connection.modem_unreachable")
            : `${t(`overview.connection.${connectionLabel}`)} · ${networkType}`}
        </Badge>
        {isStale && (
          <Badge
            variant="outline"
            className="bg-info/15 text-info hover:bg-info/20 border-info/30"
          >
            {t("overview.stale_indicator")}
          </Badge>
        )}
      </div>

      {/* Hero — signal quality */}
      <div className="flex flex-col gap-1">
        <div className="text-2xl font-semibold leading-tight">
          {qualityLabel}
        </div>
        <div className="text-muted-foreground text-sm">{signalLine}</div>
      </div>

      {/* Grid — carrier / bands / pci / uptime */}
      <dl
        className={`grid grid-cols-1 gap-4 @[18rem]/overview:grid-cols-2 ${rowsMutedClass}`}
      >
        <Field
          label={t("overview.field.carrier")}
          value={data.network.carrier || "—"}
        />
        <Field
          label={t("overview.field.bands")}
          value={formatBands(data.network.bands)}
        />
        <Field
          label={t("overview.field.pci")}
          value={formatPcis(data.network.bands)}
        />
        <Field label={t("overview.field.uptime")} value={uptimeText} />
      </dl>
    </div>
  );
}

// ---------- Sub-components -------------------------------------------------

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-1">
      <dt className="text-muted-foreground text-xs uppercase tracking-wide">
        {label}
      </dt>
      <dd className="text-sm font-medium">{value}</dd>
    </div>
  );
}

function SkeletonBody() {
  return (
    <div className="flex flex-col gap-5" aria-busy="true">
      <Skeleton className="h-6 w-40" />
      <div className="flex flex-col gap-2">
        <Skeleton className="h-7 w-24" />
        <Skeleton className="h-4 w-48" />
      </div>
      <div className="grid grid-cols-1 gap-4 @[18rem]/overview:grid-cols-2">
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-10 w-full" />
      </div>
    </div>
  );
}

function EmptyState({
  title,
  subtitle,
}: {
  title: string;
  subtitle: string;
}) {
  return (
    <div className="flex flex-col items-center gap-2 py-6 text-center">
      <MinusCircleIcon
        className="text-muted-foreground size-8"
        aria-hidden
      />
      <div className="text-base font-medium">{title}</div>
      <p className="text-muted-foreground text-sm">{subtitle}</p>
    </div>
  );
}

// ---------- Helpers --------------------------------------------------------

function formatSignalLine(
  signal: { rsrp: number | null; sinr: number | null },
  t: (key: string, opts?: Record<string, unknown>) => string,
  reachable: boolean,
): string {
  if (!reachable) return t("overview.signal.none");
  const { rsrp, sinr } = signal;
  if (rsrp != null && sinr != null) {
    return t("overview.signal.dual", { rsrp, sinr });
  }
  if (rsrp != null) return t("overview.signal.rsrp_only", { rsrp });
  if (sinr != null) return t("overview.signal.sinr_only", { sinr });
  return t("overview.signal.none");
}
