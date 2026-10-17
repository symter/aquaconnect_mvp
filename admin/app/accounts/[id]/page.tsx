"use client";

import { use, useCallback, useEffect, useState, type FormEvent } from "react";
import Link from "next/link";
import { ArrowLeft, Eye, EyeOff, KeyRound, NotebookPen, Power, Save, Shuffle } from "lucide-react";
import { adminFetch, formatDateTime, formatPhone, ROLE_LABELS, type Member } from "@/lib/api";
import { Avatar, Badge, Button, cardStyle, COLORS, ErrorBox, Field, inputStyle, Loading, Notice, SectionLabel } from "@/components/ui";

// 서버 lib/validators.js validatePassword 와 같은 규칙.
function passwordProblem(pw: string): string | null {
  if (pw.length < 8) return "비밀번호는 8자 이상이어야 합니다.";
  const kinds = [/[A-Za-z]/, /\d/, /[^A-Za-z0-9]/].filter((re) => re.test(pw)).length;
  if (kinds < 2) return "비밀번호는 영문·숫자·특수문자 중 2종 이상을 조합해야 합니다.";
  return null;
}

// 헷갈리는 글자(0/O, 1/l/I)를 뺀 임시 비밀번호.
function randomPassword(): string {
  const letters = "abcdefghjkmnpqrstuvwxyz";
  const digits = "23456789";
  const pick = (set: string, n: number) =>
    Array.from(crypto.getRandomValues(new Uint32Array(n)), (v) => set[v % set.length]).join("");
  return `${pick(letters, 6)}${pick(digits, 4)}`;
}

type Msg = { tone: "success" | "danger"; text: string } | null;

export default function AccountDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [member, setMember] = useState<Member | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const [form, setForm] = useState({ name: "", email: "", phone: "" });
  const [savingInfo, setSavingInfo] = useState(false);
  const [infoMsg, setInfoMsg] = useState<Msg>(null);

  const [pw, setPw] = useState("");
  const [pw2, setPw2] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [savingPw, setSavingPw] = useState(false);
  const [pwMsg, setPwMsg] = useState<Msg>(null);

  const [togglingStatus, setTogglingStatus] = useState(false);

  const applyMember = useCallback((m: Member) => {
    setMember(m);
    setForm({ name: m.name, email: m.email, phone: m.phone ? formatPhone(m.phone) : "" });
  }, []);

  useEffect(() => {
    adminFetch<Member>(`members/${id}`)
      .then(applyMember)
      .catch((e) => setError(e instanceof Error ? e.message : "계정을 불러올 수 없습니다."))
      .finally(() => setLoading(false));
  }, [id, applyMember]);

  async function saveInfo(e: FormEvent) {
    e.preventDefault();
    setInfoMsg(null);
    setSavingInfo(true);
    try {
      applyMember(await adminFetch<Member>(`members/${id}`, { method: "PATCH", body: JSON.stringify(form) }));
      setInfoMsg({ tone: "success", text: "계정 정보를 저장했습니다." });
    } catch (e) {
      setInfoMsg({ tone: "danger", text: e instanceof Error ? e.message : "저장에 실패했습니다." });
    } finally {
      setSavingInfo(false);
    }
  }

  async function savePassword(e: FormEvent) {
    e.preventDefault();
    setPwMsg(null);
    const problem = passwordProblem(pw);
    if (problem) return setPwMsg({ tone: "danger", text: problem });
    if (pw !== pw2) return setPwMsg({ tone: "danger", text: "비밀번호 확인이 일치하지 않습니다." });
    if (!confirm(`${member?.name} 님의 비밀번호를 변경할까요?\n기존 비밀번호로는 더 이상 로그인할 수 없습니다.`)) return;
    setSavingPw(true);
    try {
      await adminFetch(`members/${id}/password`, { method: "POST", body: JSON.stringify({ password: pw }) });
      setPwMsg({ tone: "success", text: `비밀번호를 변경했습니다. 새 비밀번호(${pw})를 사용자에게 안전한 경로로 전달해 주세요.` });
      setPw("");
      setPw2("");
    } catch (e) {
      setPwMsg({ tone: "danger", text: e instanceof Error ? e.message : "비밀번호 변경에 실패했습니다." });
    } finally {
      setSavingPw(false);
    }
  }

  function fillRandom() {
    const generated = randomPassword();
    setPw(generated);
    setPw2(generated);
    setShowPw(true);
    setPwMsg(null);
  }

  async function toggleStatus() {
    if (!member) return;
    const next = member.status === "active" ? "inactive" : "active";
    const prompt = next === "inactive"
      ? `${member.name} 님의 계정을 비활성화할까요?\n즉시 로그아웃되며 다시 활성화할 때까지 로그인할 수 없습니다. 작성한 메모는 유지됩니다.`
      : `${member.name} 님의 계정을 다시 활성화할까요?`;
    if (!confirm(prompt)) return;
    setTogglingStatus(true);
    try {
      applyMember(await adminFetch<Member>(`members/${id}/status`, { method: "POST", body: JSON.stringify({ status: next }) }));
    } catch (e) {
      alert(e instanceof Error ? e.message : "상태 변경에 실패했습니다.");
    } finally {
      setTogglingStatus(false);
    }
  }

  const active = member?.status === "active";

  return (
    <div style={{ maxWidth: 760 }}>
      <Link href="/accounts" style={{ display: "inline-flex", alignItems: "center", gap: 6, fontSize: 13, fontWeight: 600, color: "#666", textDecoration: "none", marginBottom: 20 }}>
        <ArrowLeft size={16} /> 계정 관리
      </Link>

      {loading && <Loading />}
      {error && <ErrorBox>{error}</ErrorBox>}

      {member && (
        <>
          {/* 프로필 */}
          <div style={{ ...cardStyle, padding: "24px 28px", marginBottom: 28, display: "flex", alignItems: "center", gap: 18, flexWrap: "wrap" }}>
            <Avatar text={member.name} />
            <div style={{ flex: 1, minWidth: 200 }}>
              <h1 style={{ fontSize: 20, fontWeight: 800, color: "#1a1a1a" }}>{member.name}</h1>
              <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 8, flexWrap: "wrap" }}>
                {active
                  ? <Badge color={COLORS.successText} bg={COLORS.successSoft}>활성</Badge>
                  : <Badge color="#555" bg={COLORS.neutralSoft}>비활성</Badge>}
                <Badge color={COLORS.primaryDark} bg={COLORS.primarySoft}>{member.orgName}</Badge>
                <Badge color="#555" bg={COLORS.neutralSoft}>{ROLE_LABELS[member.role] ?? member.role}</Badge>
              </div>
              <p style={{ fontSize: 12, color: "#999", marginTop: 8 }}>
                가입 {formatDateTime(member.createdAt)}
                {member.marketingAgreed && " · 마케팅 수신 동의"}
              </p>
            </div>
            <Link
              href={`/community?authorId=${member.id}&authorName=${encodeURIComponent(member.name)}`}
              style={{ display: "inline-flex", alignItems: "center", gap: 6, fontSize: 13, fontWeight: 700, color: COLORS.primary, textDecoration: "none" }}
            >
              <NotebookPen size={15} /> 작성한 메모 {member.memoCount}건
            </Link>
          </div>

          {/* 기본 정보 */}
          <SectionLabel>기본 정보</SectionLabel>
          <form onSubmit={saveInfo} style={{ ...cardStyle, padding: "24px 28px", marginBottom: 28, display: "flex", flexDirection: "column", gap: 16 }}>
            <Field label="이름">
              <input required value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} style={inputStyle} />
            </Field>
            <Field label="이메일 (로그인 아이디)">
              <input required type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} style={inputStyle} />
            </Field>
            <Field label="연락처">
              <input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} placeholder="010-0000-0000" style={inputStyle} />
            </Field>
            {infoMsg && <Notice tone={infoMsg.tone}>{infoMsg.text}</Notice>}
            <div>
              <Button type="submit" disabled={savingInfo}>
                <Save size={14} /> {savingInfo ? "저장 중..." : "정보 저장"}
              </Button>
            </div>
          </form>

          {/* 비밀번호 */}
          <SectionLabel>비밀번호 재설정</SectionLabel>
          <form onSubmit={savePassword} style={{ ...cardStyle, padding: "24px 28px", marginBottom: 28, display: "flex", flexDirection: "column", gap: 16 }}>
            <p style={{ fontSize: 13, color: "#888", lineHeight: 1.6 }}>
              8자 이상, 영문·숫자·특수문자 중 2종 이상. 변경 내역은 해당 관리원의 변경 이력에 &lsquo;시스템 관리자&rsquo;로 기록됩니다.
            </p>
            <Field label="새 비밀번호">
              <div style={{ position: "relative" }}>
                <input
                  type={showPw ? "text" : "password"}
                  value={pw}
                  onChange={(e) => setPw(e.target.value)}
                  autoComplete="new-password"
                  style={{ ...inputStyle, paddingRight: 44 }}
                />
                <button
                  type="button"
                  onClick={() => setShowPw(!showPw)}
                  aria-label={showPw ? "비밀번호 숨기기" : "비밀번호 보기"}
                  style={{ position: "absolute", right: 10, top: "50%", transform: "translateY(-50%)", border: "none", background: "transparent", cursor: "pointer", color: "#999", display: "flex" }}
                >
                  {showPw ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </Field>
            <Field label="새 비밀번호 확인">
              <input type={showPw ? "text" : "password"} value={pw2} onChange={(e) => setPw2(e.target.value)} autoComplete="new-password" style={inputStyle} />
            </Field>
            {pwMsg && <Notice tone={pwMsg.tone}>{pwMsg.text}</Notice>}
            <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
              <Button type="submit" disabled={savingPw || !pw}>
                <KeyRound size={14} /> {savingPw ? "변경 중..." : "비밀번호 변경"}
              </Button>
              <Button variant="outline" onClick={fillRandom}>
                <Shuffle size={14} /> 임시 비밀번호 생성
              </Button>
            </div>
          </form>

          {/* 계정 상태 */}
          <SectionLabel>계정 상태</SectionLabel>
          <div style={{ ...cardStyle, padding: "24px 28px", display: "flex", alignItems: "center", justifyContent: "space-between", gap: 16, flexWrap: "wrap" }}>
            <div>
              <p style={{ fontSize: 15, fontWeight: 700, color: "#1a1a1a" }}>{active ? "활성 계정" : "비활성 계정"}</p>
              <p style={{ fontSize: 13, color: "#888", marginTop: 4 }}>
                {active ? "비활성화하면 즉시 로그아웃되고 로그인할 수 없습니다." : "현재 로그인할 수 없습니다. 활성화하면 기존 비밀번호로 다시 로그인할 수 있습니다."}
              </p>
            </div>
            <Button variant={active ? "danger" : "success"} disabled={togglingStatus} onClick={toggleStatus}>
              <Power size={14} /> {togglingStatus ? "처리 중..." : active ? "비활성화" : "활성화"}
            </Button>
          </div>
        </>
      )}
    </div>
  );
}
