"use client";

import { useRouter } from "next/navigation";
import { LogOut } from "lucide-react";

export default function LogoutButton() {
  const router = useRouter();

  async function handleLogout() {
    await fetch("/api/auth/logout", { method: "POST" });
    router.push("/login");
    router.refresh();
  }

  return (
    <button
      onClick={handleLogout}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 10,
        width: "100%",
        padding: "10px 14px",
        borderRadius: 12,
        border: "none",
        background: "transparent",
        color: "rgba(255,255,255,0.55)",
        fontSize: 14,
        fontWeight: 500,
        cursor: "pointer",
        transition: "all 0.15s",
        fontFamily: "inherit",
      }}
      onMouseOver={(e) => {
        (e.currentTarget as HTMLElement).style.background = "rgba(255,255,255,0.10)";
        (e.currentTarget as HTMLElement).style.color = "rgba(255,255,255,0.85)";
      }}
      onMouseOut={(e) => {
        (e.currentTarget as HTMLElement).style.background = "transparent";
        (e.currentTarget as HTMLElement).style.color = "rgba(255,255,255,0.55)";
      }}
    >
      <LogOut size={18} strokeWidth={2} />
      로그아웃
    </button>
  );
}
