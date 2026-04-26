"use client";

import { useEffect } from "react";
import OverviewCard from "@/components/public/overview-card";

export default function Home() {
  // Logged-in visitors land directly on the dashboard. We can't read the
  // HttpOnly session cookie, but the indicator cookie qm_logged_in=1 is set
  // by the login flow and is sufficient for this gate (see AuthGate).
  useEffect(() => {
    if (
      typeof document !== "undefined" &&
      document.cookie.includes("qm_logged_in=1")
    ) {
      window.location.href = "/dashboard/";
    }
  }, []);

  return (
    <div className="bg-background flex min-h-svh items-center justify-center p-4 font-sans">
      <main className="w-full max-w-md">
        <OverviewCard />
      </main>
    </div>
  );
}
