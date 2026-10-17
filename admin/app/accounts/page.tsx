"use client";

import { useCallback, useEffect, useState, type FormEvent } from "react";
import Link from "next/link";
import { ChevronRight, Search } from "lucide-react";
import { adminFetch, formatDateTime, formatPhone, ROLE_LABELS, type Member, type Organization } from "@/lib/api";
import { Avatar, Badge, Button, COLORS, Empty, ErrorBox, FilterChip, inputStyle, Loading, PageHeader, RefreshButton } from "@/components/ui";

const FILTERS = [
  { key: "", label: "전체" },
  { key: "active", label: "활성" },
  { key: "inactive", label: "비활성" },
];

export default function AccountsPage() {
  const [orgs, setOrgs] = useState<Organization[]>([]);
  const [members, setMembers] = useState<Member[]>([]);
  const [status, setStatus] = useState("");
  const [orgId, setOrgId] = useState("");
  const [queryInput, setQueryInput] = useState("");
  const [q, setQ] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    adminFetch<Organization[]>("organizations").then(setOrgs).catch(() => {});
  }, []);

  const fetchMembers = useCallback(async () => {
    setLoading(true);
    setError("");
    const params = new URLSearchParams();
    if (status) params.set("status", status);
    if (orgId) params.set("orgId", orgId);
    if (q) params.set("q", q);
    try {
      setMembers(await adminFetch<Member[]>(`members?${params}`));
    } catch (e) {
      setError(e instanceof Error ? e.message : "계정 목록을 불러올 수 없습니다.");
    } finally {
      setLoading(false);
    }
  }, [status, orgId, q]);

  useEffect(() => { fetchMembers(); }, [fetchMembers]);

  function handleSearch(e: FormEvent) {
    e.preventDefault();
    setQ(queryInput.trim());
  }

  return (
    <div>
      <PageHeader
        title="계정 관리"
        subtitle="관리원 구성원 계정의 정보 수정, 비밀번호 재설정, 활성화·비활성화를 처리합니다."
      />

      {/* 필터 탭 + 새로고침 */}
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 16, flexWrap: "wrap" }}>
        {FILTERS.map(({ key, label }) => (
          <FilterChip key={key} active={status === key} onClick={() => setStatus(key)}>{label}</FilterChip>
        ))}
        <div style={{ marginLeft: "auto" }}>
          <RefreshButton onClick={fetchMembers} />
        </div>
      </div>

      {/* 검색 */}
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 24, flexWrap: "wrap" }}>
        <form onSubmit={handleSearch} style={{ display: "flex", gap: 8, flex: "1 1 320px" }}>
          <div style={{ position: "relative", flex: 1 }}>
            <Search size={16} color="#999" style={{ position: "absolute", left: 14, top: "50%", transform: "translateY(-50%)" }} />
            <input
              value={queryInput}
              onChange={(e) => setQueryInput(e.target.value)}
              placeholder="이름 · 이메일 · 연락처 · 관리원 검색"
              style={{ ...inputStyle, paddingLeft: 38, background: "#fff" }}
            />
          </div>
          <Button type="submit">검색</Button>
        </form>
        <select
          value={orgId}
          onChange={(e) => setOrgId(e.target.value)}
          style={{ ...inputStyle, width: "auto", minWidth: 180, background: "#fff", cursor: "pointer" }}
        >
          <option value="">전체 관리원</option>
          {orgs.map((o) => <option key={o.id} value={o.id}>{o.name} ({o.memberCount})</option>)}
        </select>
      </div>

      {loading && <Loading />}
      {error && <ErrorBox>{error}</ErrorBox>}
      {!loading && !error && members.length === 0 && <Empty>해당 조건의 계정이 없습니다.</Empty>}

      {!loading && members.length > 0 && (
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          {members.map((m) => (
            <Link key={m.id} href={`/accounts/${m.id}`} style={{ textDecoration: "none", color: "inherit" }}>
              <div
                style={{
                  background: "#fff",
                  borderRadius: 18,
                  padding: "20px 24px",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "space-between",
                  gap: 16,
                  boxShadow: "0 2px 8px rgba(0,0,0,0.06)",
                  cursor: "pointer",
                  transition: "box-shadow 0.15s",
                  opacity: m.status === "inactive" ? 0.7 : 1,
                }}
                onMouseOver={(e) => { e.currentTarget.style.boxShadow = "0 4px 16px rgba(0,0,0,0.10)"; }}
                onMouseOut={(e) => { e.currentTarget.style.boxShadow = "0 2px 8px rgba(0,0,0,0.06)"; }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 16, minWidth: 0 }}>
                  <Avatar text={m.name} />
                  <div style={{ minWidth: 0 }}>
                    <p style={{ fontSize: 15, fontWeight: 700, color: "#1a1a1a" }}>{m.name}</p>
                    <p style={{ fontSize: 12, color: "#666", marginTop: 2, overflowWrap: "anywhere" }}>
                      {m.email}
                      {m.phone && <span style={{ color: "#999" }}> · {formatPhone(m.phone)}</span>}
                    </p>
                    <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 8, flexWrap: "wrap" }}>
                      {m.status === "active"
                        ? <Badge color={COLORS.successText} bg={COLORS.successSoft}>활성</Badge>
                        : <Badge color="#555" bg={COLORS.neutralSoft}>비활성</Badge>}
                      <Badge color={COLORS.primaryDark} bg={COLORS.primarySoft}>{m.orgName}</Badge>
                      <Badge color="#555" bg={COLORS.neutralSoft}>{ROLE_LABELS[m.role] ?? m.role}</Badge>
                      <span style={{ fontSize: 11, color: "#aaa" }}>
                        메모 {m.memoCount} · 댓글 {m.commentCount} · 가입 {formatDateTime(m.createdAt).split(" ")[0]}
                      </span>
                    </div>
                  </div>
                </div>
                <ChevronRight size={20} color="#ccc" style={{ flexShrink: 0 }} />
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
