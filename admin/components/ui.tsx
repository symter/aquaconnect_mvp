"use client";

import type { CSSProperties, ReactNode } from "react";
import { RefreshCw } from "lucide-react";

// 기존 관리자 화면들이 인라인으로 반복하던 스타일을 모아 둔 것. 색·크기는 그대로다.

export const COLORS = {
  primary: "#185FA5",
  primaryDark: "#0C447C",
  primarySoft: "#E6F1FB",
  success: "#1D9E75",
  successText: "#085041",
  successSoft: "#E1F5EE",
  danger: "#D85A30",
  dangerText: "#712B13",
  dangerSoft: "#FAECEA",
  warnText: "#854F0B",
  warnSoft: "#FAEEDA",
  neutralSoft: "#F0F2F5",
};

export const cardStyle: CSSProperties = {
  background: "#fff",
  borderRadius: 18,
  padding: "20px 24px",
  boxShadow: "0 2px 8px rgba(0,0,0,0.06)",
};

export const inputStyle: CSSProperties = {
  width: "100%",
  padding: "11px 14px",
  borderRadius: 12,
  border: "1.5px solid #E5E7EB",
  background: "#FAFAFA",
  fontSize: 14,
  color: "#1a1a1a",
  outline: "none",
  fontFamily: "inherit",
};

export function PageHeader({ title, subtitle }: { title: string; subtitle?: string }) {
  return (
    <div style={{ marginBottom: 28 }}>
      <h1 style={{ fontSize: 24, fontWeight: 800, color: "#1a1a1a", letterSpacing: "-0.02em" }}>{title}</h1>
      {subtitle && <p style={{ fontSize: 13, color: "#999", marginTop: 6 }}>{subtitle}</p>}
    </div>
  );
}

export function SectionLabel({ children }: { children: ReactNode }) {
  return (
    <p style={{ fontSize: 11, fontWeight: 700, color: "#888", letterSpacing: "0.06em", textTransform: "uppercase", marginBottom: 14 }}>
      {children}
    </p>
  );
}

export function FilterChip({ active, onClick, children }: { active: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      onClick={onClick}
      style={{
        padding: "8px 18px",
        borderRadius: 99,
        fontSize: 13,
        fontWeight: 600,
        border: active ? `1.5px solid ${COLORS.primary}` : "1.5px solid #E0E0E0",
        background: active ? COLORS.primary : "#fff",
        color: active ? "#fff" : "#555",
        cursor: "pointer",
        transition: "all 0.15s",
        fontFamily: "inherit",
      }}
    >
      {children}
    </button>
  );
}

export function RefreshButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      style={{
        display: "flex", alignItems: "center", gap: 6,
        padding: "8px 16px",
        borderRadius: 99,
        fontSize: 13,
        fontWeight: 600,
        border: "1.5px solid #E0E0E0",
        background: "#fff",
        color: "#555",
        cursor: "pointer",
        fontFamily: "inherit",
        flexShrink: 0,
      }}
    >
      <RefreshCw size={14} />
      새로고침
    </button>
  );
}

export function Badge({ color, bg, children }: { color: string; bg: string; children: ReactNode }) {
  return (
    <span style={{ padding: "3px 10px", borderRadius: 99, fontSize: 11, fontWeight: 700, background: bg, color, whiteSpace: "nowrap" }}>
      {children}
    </span>
  );
}

export function Avatar({ text }: { text: string }) {
  return (
    <div style={{
      width: 48, height: 48, borderRadius: 14,
      background: COLORS.primarySoft,
      display: "flex", alignItems: "center", justifyContent: "center",
      fontSize: 18, fontWeight: 800, color: COLORS.primary,
      flexShrink: 0,
    }}>
      {(text || "?").charAt(0).toUpperCase()}
    </div>
  );
}

export function Loading() {
  return <div style={{ textAlign: "center", padding: "60px 0", color: "#999", fontSize: 14 }}>불러오는 중...</div>;
}

export function Empty({ children }: { children: ReactNode }) {
  return <div style={{ textAlign: "center", padding: "60px 0", color: "#999", fontSize: 14 }}>{children}</div>;
}

export function ErrorBox({ children }: { children: ReactNode }) {
  return (
    <div style={{ background: COLORS.warnSoft, borderRadius: 14, padding: "16px 20px", color: COLORS.warnText, fontSize: 13, fontWeight: 600, marginBottom: 16 }}>
      ⚠️ {children}
    </div>
  );
}

export function Notice({ tone, children }: { tone: "success" | "danger"; children: ReactNode }) {
  const ok = tone === "success";
  return (
    <div style={{
      padding: "12px 16px", borderRadius: 12, fontSize: 13, fontWeight: 600,
      background: ok ? COLORS.successSoft : COLORS.dangerSoft,
      color: ok ? COLORS.successText : COLORS.dangerText,
    }}>
      {children}
    </div>
  );
}

type ButtonVariant = "primary" | "success" | "danger" | "outline";

const BUTTON_VARIANTS: Record<ButtonVariant, CSSProperties> = {
  primary: { border: "none", background: COLORS.primary, color: "#fff" },
  success: { border: "none", background: COLORS.success, color: "#fff" },
  danger: { border: "none", background: COLORS.danger, color: "#fff" },
  outline: { border: "1.5px solid #E0E0E0", background: "#fff", color: "#666" },
};

export function Button({
  variant = "primary",
  disabled,
  onClick,
  type = "button",
  children,
}: {
  variant?: ButtonVariant;
  disabled?: boolean;
  onClick?: () => void;
  type?: "button" | "submit";
  children: ReactNode;
}) {
  return (
    <button
      type={type}
      disabled={disabled}
      onClick={onClick}
      style={{
        display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 6,
        padding: "9px 18px", borderRadius: 12,
        fontSize: 13, fontWeight: 700,
        cursor: disabled ? "not-allowed" : "pointer",
        opacity: disabled ? 0.6 : 1,
        fontFamily: "inherit",
        whiteSpace: "nowrap",
        ...BUTTON_VARIANTS[variant],
      }}
    >
      {children}
    </button>
  );
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label style={{ display: "block" }}>
      <span style={{ display: "block", fontSize: 12, fontWeight: 700, color: "#555", marginBottom: 8 }}>{label}</span>
      {children}
    </label>
  );
}
