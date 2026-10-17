"use client";

import { useState, FormEvent } from "react";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const router = useRouter();
  const [id, setId] = useState("");
  const [pw, setPw] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id, pw }),
      });
      if (res.ok) {
        router.push("/");
        router.refresh();
      } else {
        const data = await res.json();
        setError(data.error ?? "로그인에 실패했습니다.");
      }
    } catch {
      setError("서버에 연결할 수 없습니다.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ display: "flex", width: "100vw", minHeight: "100vh" }}>

      {/* ── 왼쪽 브랜드 패널 (데스크톱) ── */}
      <div style={{
        flex: "0 0 420px",
        background: "linear-gradient(160deg, #185FA5 0%, #0C447C 100%)",
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        padding: "60px 48px",
        position: "relative",
        overflow: "hidden",
      }}
        className="hidden md:flex"
      >
        {/* 배경 장식 원 */}
        <div style={{
          position: "absolute", width: 300, height: 300,
          borderRadius: "50%", background: "rgba(255,255,255,0.05)",
          top: -80, right: -80,
        }} />
        <div style={{
          position: "absolute", width: 200, height: 200,
          borderRadius: "50%", background: "rgba(255,255,255,0.05)",
          bottom: 40, left: -60,
        }} />

        {/* 로고 */}
        <div style={{ display: "flex", alignItems: "center", gap: 14, marginBottom: 48 }}>
          <div style={{
            width: 56, height: 56, borderRadius: 16,
            background: "rgba(255,255,255,0.18)",
            display: "flex", alignItems: "center", justifyContent: "center",
            fontSize: 30,
          }}>🐟</div>
          <div>
            <p style={{ fontWeight: 900, fontSize: 22, color: "#fff", letterSpacing: "-0.02em" }}>AquaConnect</p>
            <p style={{ fontSize: 13, color: "rgba(255,255,255,0.60)", marginTop: 2 }}>Admin Dashboard</p>
          </div>
        </div>

        {/* 소개 */}
        <h2 style={{ fontSize: 26, fontWeight: 800, color: "#fff", lineHeight: 1.3, marginBottom: 16 }}>
          한국 수산 양식<br />통합 관리 플랫폼
        </h2>
        <p style={{ fontSize: 14, color: "rgba(255,255,255,0.65)", lineHeight: 1.7, marginBottom: 40 }}>
          현장 메모·댓글 관리와<br />관리원 계정 관리를 한 곳에서.
        </p>

        {/* 기능 목록 */}
        {["메모 · 댓글 검토 및 삭제", "계정 비밀번호 재설정", "계정 활성화 · 비활성화"].map((item) => (
          <div key={item} style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 14 }}>
            <div style={{
              width: 22, height: 22, borderRadius: "50%",
              background: "rgba(255,255,255,0.20)",
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 12, color: "#fff",
            }}>✓</div>
            <span style={{ fontSize: 14, color: "rgba(255,255,255,0.80)", fontWeight: 500 }}>{item}</span>
          </div>
        ))}
      </div>

      {/* ── 오른쪽 로그인 폼 ── */}
      <div style={{
        flex: 1,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: "#F0F2F5",
        padding: "40px 24px",
      }}>
        <div style={{
          width: "100%",
          maxWidth: 400,
          background: "#fff",
          borderRadius: 24,
          padding: "44px 40px",
          boxShadow: "0 4px 32px rgba(0,0,0,0.10)",
        }}>
          {/* 모바일용 로고 */}
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", marginBottom: 36 }}
            className="flex md:hidden"
          >
            <div style={{
              width: 60, height: 60, borderRadius: 18,
              background: "#185FA5",
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: 32, marginBottom: 12,
            }}>🐟</div>
            <p style={{ fontSize: 20, fontWeight: 900, color: "#1a1a1a" }}>AquaConnect</p>
            <p style={{ fontSize: 12, color: "#999", marginTop: 4 }}>Admin Dashboard</p>
          </div>

          <h1 style={{ fontSize: 22, fontWeight: 800, color: "#1a1a1a", marginBottom: 6 }}>관리자 로그인</h1>
          <p style={{ fontSize: 13, color: "#999", marginBottom: 32 }}>AquaConnect 관리자 계정으로 로그인하세요.</p>

          <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: 18 }}>
            <div>
              <label style={{ display: "block", fontSize: 12, fontWeight: 700, color: "#555", marginBottom: 8 }}>
                아이디
              </label>
              <input
                type="text"
                value={id}
                onChange={(e) => setId(e.target.value)}
                placeholder="아이디를 입력하세요"
                autoComplete="username"
                required
                style={{
                  width: "100%",
                  padding: "13px 16px",
                  borderRadius: 12,
                  border: "1.5px solid #E5E7EB",
                  background: "#FAFAFA",
                  fontSize: 14,
                  color: "#1a1a1a",
                  outline: "none",
                  transition: "border-color 0.15s",
                  fontFamily: "inherit",
                }}
                onFocus={(e) => (e.target.style.borderColor = "#185FA5")}
                onBlur={(e) => (e.target.style.borderColor = "#E5E7EB")}
              />
            </div>

            <div>
              <label style={{ display: "block", fontSize: 12, fontWeight: 700, color: "#555", marginBottom: 8 }}>
                비밀번호
              </label>
              <input
                type="password"
                value={pw}
                onChange={(e) => setPw(e.target.value)}
                placeholder="비밀번호를 입력하세요"
                autoComplete="current-password"
                required
                style={{
                  width: "100%",
                  padding: "13px 16px",
                  borderRadius: 12,
                  border: "1.5px solid #E5E7EB",
                  background: "#FAFAFA",
                  fontSize: 14,
                  color: "#1a1a1a",
                  outline: "none",
                  transition: "border-color 0.15s",
                  fontFamily: "inherit",
                }}
                onFocus={(e) => (e.target.style.borderColor = "#185FA5")}
                onBlur={(e) => (e.target.style.borderColor = "#E5E7EB")}
              />
            </div>

            {error && (
              <div style={{
                padding: "12px 16px",
                borderRadius: 12,
                background: "#FAECEA",
                color: "#712B13",
                fontSize: 13,
                fontWeight: 600,
              }}>
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              style={{
                width: "100%",
                padding: "15px",
                borderRadius: 14,
                border: "none",
                background: loading ? "#93B8D8" : "#185FA5",
                color: "#fff",
                fontSize: 15,
                fontWeight: 700,
                cursor: loading ? "not-allowed" : "pointer",
                transition: "background 0.15s",
                fontFamily: "inherit",
                marginTop: 4,
              }}
            >
              {loading ? "로그인 중..." : "로그인"}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
