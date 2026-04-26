import { cn } from "@/lib/utils";
import { getSignalQuality, RSRP_THRESHOLDS } from "@/types/modem-status";
import { getValueColorClass } from "@/components/dashboard/signal-card-utils";
import type { CarrierOption } from "./simple-mode-utils";

interface CarrierLabelProps {
  opt: CarrierOption;
}

/**
 * Inline label for a Simple Mode carrier dropdown item.
 * Format: "B3 - 1850 (-85)" — RSRP segment is colorized per signal quality.
 */
export function CarrierLabel({ opt }: CarrierLabelProps) {
  const rsrpColor = getValueColorClass(
    getSignalQuality(opt.rsrp, RSRP_THRESHOLDS),
  );

  return (
    <span className="inline-flex items-baseline gap-1 tabular-nums">
      <span className="font-semibold">{opt.band}</span>
      <span className="text-muted-foreground">- {opt.earfcn}</span>
      {opt.rsrp !== null && (
        <span className={cn("font-semibold", rsrpColor)}>
          ({opt.rsrp})
        </span>
      )}
    </span>
  );
}
