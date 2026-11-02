"use client";

import { use, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { ArrowLeft, CheckCircle2, Save } from "lucide-react";
import { adminFetch, formatDateTime, type AiReportDetail } from "@/lib/api";
import { Badge, Button, cardStyle, COLORS, ErrorBox, inputStyle, Loading, Notice, SectionLabel } from "@/components/ui";
import ReportStatusBadge from "@/components/ReportStatusBadge";

export default function ReportDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [report, setReport] = useState<AiReportDetail | null>(null);
  const [body, setBody] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [saved, setSaved] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      const r = await adminFetch<AiReportDetail>(`ai-reports/${id}`);
      setReport(r);
      setBody(r.body);
    } catch (e) {
      setError(e instanceof Error ? e.message : "리포트를 불러올 수 없습니다.");
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => { load(); }, [load]);

  async function save(withBody: boolean) {
    setBusy(true);
    setSaved("");
    try {
      const r = await adminFetch<AiReportDetail>(`ai-reports/${id}`, { method: "PUT", body: JSON.stringify(withBody ? { body } : {}) });
      setReport(r);
      setBody(r.body);
      setSaved(withBody ? "수정 내용을 저장했습니다. 관리원 앱에 바로 반영됩니다." : "검토 완료로 표시했습니다.");
    } catch (e) {
      alert(e instanceof Error ? e.message : "저장하지 못했습니다.");
    } finally {
      setBusy(false);
    }
  }

  const editable = report?.status === "draft";
  const dirty = report != null && body.trim() !== report.body.trim();

  return (
    <div style={{ maxWidth: 1100 }}>
      <Link href="/reports" style={{ display: "inline-flex", alignItems: "center", gap: 6, fontSize: 13, fontWeight: 600, color: "#666", textDecoration: "none", marginBottom: 20 }}>
        <ArrowLeft size={16} /> AI 리포트 검토
      </Link>
      {loading && <Loading />}
      {error && <ErrorBox>{error}</ErrorBox>}
      {report && (
        <>
          <div style={{ ...cardStyle, marginBottom: 20 }}>
            <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
              <ReportStatusBadge status={report.status} />
              {report.source === "auto" && <Badge color="#555" bg={COLORS.neutralSoft}>자동 생성</Badge>}
              {report.adminReviewedAt && <Badge color={COLORS.successText} bg={COLORS.successSoft}>심터 검토됨 · {formatDateTime(report.adminReviewedAt)}</Badge>}
              {report.edited && <Badge color={COLORS.primaryDark} bg={COLORS.primarySoft}>수정됨{report.editedByName ? ` · ${report.editedByName}` : ""}</Badge>}
            </div>
            <h1 style={{ fontSize: 20, fontWeight: 800, color: "#1a1a1a", marginTop: 10 }}>
              {report.farmName ?? "관리원 종합 리포트"} <span style={{ fontSize: 14, color: "#888", fontWeight: 600 }}>· {report.orgName}</span>
            </h1>
            <p style={{ fontSize: 13, color: "#999", marginTop: 4 }}>
              {report.periodStart} ~ {report.periodEnd} · 메모 {report.memoCount}건 · {report.model} · {report.createdByName || "-"} {formatDateTime(report.createdAt)}
            </p>
            {!editable && (
              <p style={{ fontSize: 13, color: COLORS.warnText, marginTop: 10 }}>관리원이 이미 확정(또는 발송)한 리포트라 여기서는 고칠 수 없습니다.</p>
            )}
          </div>

          {saved && <div style={{ marginBottom: 16 }}><Notice tone="success">{saved}</Notice></div>}

          <div style={{ display: "grid", gridTemplateColumns: "minmax(0, 3fr) minmax(0, 2fr)", gap: 20, alignItems: "start" }}>
            <div style={cardStyle}>
              <SectionLabel>리포트 본문 (&quot;## 제목&quot;이 섹션, &quot;- &quot;가 항목)</SectionLabel>
              <textarea
                value={body}
                onChange={(e) => setBody(e.target.value)}
                readOnly={!editable}
                style={{ ...inputStyle, minHeight: 640, lineHeight: 1.65, fontSize: 13.5, resize: "vertical" }}
              />
              {editable && (
                <div style={{ display: "flex", gap: 8, marginTop: 12, justifyContent: "flex-end" }}>
                  <Button variant="outline" disabled={busy || dirty} onClick={() => save(false)}>
                    <CheckCircle2 size={14} /> 수정 없이 검토 완료
                  </Button>
                  <Button disabled={busy || !dirty} onClick={() => save(true)}>
                    <Save size={14} /> {busy ? "저장 중..." : "수정 저장"}
                  </Button>
                </div>
              )}
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
              {report.checks.length > 0 && (
                <div style={cardStyle}>
                  <SectionLabel>확인 필요 {report.checks.length}</SectionLabel>
                  {report.checks.map((c, i) => (
                    <div key={i} style={{ fontSize: 13, padding: "8px 0", borderTop: i ? "1px solid #F0F2F5" : "none" }}>
                      <p style={{ fontWeight: 700, color: "#333" }}>{c.section}</p>
                      <p style={{ color: "#555", marginTop: 2 }}>{c.text}</p>
                      <p style={{ color: COLORS.dangerText, marginTop: 2 }}>{c.problem}</p>
                    </div>
                  ))}
                </div>
              )}
              <div style={cardStyle}>
                <SectionLabel>근거 메모 {report.memos.length}건</SectionLabel>
                <div style={{ maxHeight: 520, overflowY: "auto" }}>
                  {report.memos.map((m, i) => (
                    <div key={m.n} style={{ fontSize: 13, padding: "8px 0", borderTop: i ? "1px solid #F0F2F5" : "none" }}>
                      <p style={{ color: "#888" }}>#{m.n} · {m.date} · {m.kind} · {m.author}</p>
                      <p style={{ color: "#222", marginTop: 2, whiteSpace: "pre-wrap" }}>{m.body}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
