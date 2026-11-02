"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { adminFetch, formatDateTime, type AiReportStatus, type AiReportSummary, type Organization } from "@/lib/api";
import { Badge, COLORS, Empty, ErrorBox, FilterChip, inputStyle, Loading, PageHeader, RefreshButton } from "@/components/ui";
import ReportStatusBadge from "@/components/ReportStatusBadge";

const STATUS_FILTERS: { value: AiReportStatus | ""; label: string }[] = [
  { value: "draft", label: "검토 대기" },
  { value: "confirmed", label: "확정" },
  { value: "sent", label: "어가 발송" },
  { value: "", label: "전체" },
];

export default function ReportsPage() {
  const [orgs, setOrgs] = useState<Organization[]>([]);
  const [orgId, setOrgId] = useState("");
  const [status, setStatus] = useState<AiReportStatus | "">("draft");
  const [autoOnly, setAutoOnly] = useState(false);
  const [rows, setRows] = useState<AiReportSummary[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    adminFetch<Organization[]>("organizations").then(setOrgs).catch(() => {});
  }, []);

  const fetchRows = useCallback(async () => {
    setLoading(true);
    setError("");
    const params = new URLSearchParams();
    if (status) params.set("status", status);
    if (autoOnly) params.set("source", "auto");
    if (orgId) params.set("orgId", orgId);
    try {
      setRows(await adminFetch<AiReportSummary[]>(`ai-reports?${params}`));
    } catch (e) {
      setError(e instanceof Error ? e.message : "리포트를 불러올 수 없습니다.");
    } finally {
      setLoading(false);
    }
  }, [status, autoOnly, orgId]);

  useEffect(() => { fetchRows(); }, [fetchRows]);

  return (
    <div style={{ maxWidth: 1000 }}>
      <PageHeader
        title="AI 리포트 검토"
        subtitle="매달 초 지난달 리포트 초안이 자동으로 만들어집니다. 초안은 여기서 검토·수정할 수 있고, 어가 발송은 관리원이 앱에서 합니다."
      />
      <div style={{ display: "flex", gap: 8, alignItems: "center", flexWrap: "wrap", marginBottom: 18 }}>
        {STATUS_FILTERS.map((f) => (
          <FilterChip key={f.label} active={status === f.value} onClick={() => setStatus(f.value)}>{f.label}</FilterChip>
        ))}
        <FilterChip active={autoOnly} onClick={() => setAutoOnly(!autoOnly)}>자동 생성만</FilterChip>
        <select value={orgId} onChange={(e) => setOrgId(e.target.value)} style={{ ...inputStyle, width: 220, padding: "8px 12px" }}>
          <option value="">모든 기관</option>
          {orgs.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
        </select>
        <div style={{ marginLeft: "auto" }}><RefreshButton onClick={fetchRows} /></div>
      </div>

      {loading && <Loading />}
      {error && <ErrorBox>{error}</ErrorBox>}
      {rows && !loading && rows.length === 0 && <Empty>해당하는 리포트가 없습니다.</Empty>}
      {rows && !loading && rows.length > 0 && (
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {rows.map((r) => (
            <Link key={r.id} href={`/reports/${r.id}`} style={{ textDecoration: "none" }}>
              <div style={{ background: "#fff", borderRadius: 14, padding: "14px 18px", boxShadow: "0 1px 4px rgba(0,0,0,0.05)" }}>
                <div style={{ display: "flex", gap: 6, alignItems: "center", flexWrap: "wrap" }}>
                  <ReportStatusBadge status={r.status} />
                  {r.source === "auto" && <Badge color="#555" bg={COLORS.neutralSoft}>자동 생성</Badge>}
                  {r.type === "agency" && <Badge color="#555" bg={COLORS.neutralSoft}>종합</Badge>}
                  {r.adminReviewedAt && <Badge color={COLORS.successText} bg={COLORS.successSoft}>심터 검토됨</Badge>}
                  {r.checkCount > 0 && <Badge color={COLORS.dangerText} bg={COLORS.dangerSoft}>확인 필요 {r.checkCount}</Badge>}
                </div>
                <p style={{ fontSize: 15, fontWeight: 700, color: "#1a1a1a", marginTop: 6 }}>
                  {r.farmName ?? "관리원 종합"} <span style={{ fontWeight: 500, color: "#888", fontSize: 13 }}>· {r.orgName}</span>
                </p>
                <p style={{ fontSize: 12.5, color: "#999", marginTop: 2 }}>
                  {r.periodStart} ~ {r.periodEnd} · 메모 {r.memoCount}건 · {r.createdByName || "-"} · {formatDateTime(r.createdAt)}
                </p>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
