import Link from "next/link";
import { Building2, Users, UserX, NotebookPen, MessageCircle, AlertTriangle, ChevronRight } from "lucide-react";
import { getRecentMemos, getStats } from "@/lib/api-admin";
import { formatDateTime } from "@/lib/api";

interface StatCardProps {
  label: string;
  value: number;
  sub?: string;
  color: string;
  bg: string;
  Icon: React.FC<{ size?: number; strokeWidth?: number; color?: string }>;
}

function StatCard({ label, value, sub, color, bg, Icon }: StatCardProps) {
  return (
    <div style={{
      background: "#fff",
      borderRadius: 18,
      padding: "24px 24px 20px",
      boxShadow: "0 2px 8px rgba(0,0,0,0.07)",
      display: "flex",
      flexDirection: "column",
      gap: 12,
    }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <p style={{ fontSize: 12, fontWeight: 700, color: "#888", letterSpacing: "0.04em", textTransform: "uppercase" }}>
          {label}
        </p>
        <div style={{
          width: 38, height: 38, borderRadius: 10,
          background: bg,
          display: "flex", alignItems: "center", justifyContent: "center",
        }}>
          <Icon size={18} strokeWidth={2} color={color} />
        </div>
      </div>
      <div>
        <p style={{ fontSize: 36, fontWeight: 800, color, lineHeight: 1 }}>{value}</p>
        {sub && <p style={{ fontSize: 12, color: "#999", marginTop: 6 }}>{sub}</p>}
      </div>
    </div>
  );
}

const sectionLabel: React.CSSProperties = {
  fontSize: 11, fontWeight: 700, color: "#888", letterSpacing: "0.06em", textTransform: "uppercase", marginBottom: 14,
};

export default async function DashboardPage() {
  let stats, recent;
  try {
    [stats, recent] = await Promise.all([getStats(), getRecentMemos(5)]);
  } catch (e) {
    return (
      <div>
        <h1 style={{ fontSize: 24, fontWeight: 800, color: "#1a1a1a", marginBottom: 24 }}>대시보드</h1>
        <div style={{
          background: "#FAECEA",
          borderRadius: 16,
          padding: "20px 24px",
          display: "flex",
          alignItems: "center",
          gap: 12,
        }}>
          <AlertTriangle size={20} color="#D85A30" />
          <p style={{ fontSize: 14, fontWeight: 600, color: "#712B13" }}>
            AquaConnect 서버에 연결할 수 없습니다. ({e instanceof Error ? e.message : "알 수 없는 오류"})
          </p>
        </div>
      </div>
    );
  }

  return (
    <div>
      {/* 헤더 */}
      <div style={{ marginBottom: 36 }}>
        <h1 style={{ fontSize: 24, fontWeight: 800, color: "#1a1a1a", letterSpacing: "-0.02em" }}>
          대시보드
        </h1>
        <p style={{ fontSize: 13, color: "#999", marginTop: 6 }}>AquaConnect 서비스 현황 요약</p>
      </div>

      {/* 커뮤니티 현황 */}
      <p style={sectionLabel}>커뮤니티 현황</p>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))", gap: 16, marginBottom: 36 }}>
        <StatCard label="전체 메모" value={stats.memos} color="#0C447C" bg="#E6F1FB" Icon={NotebookPen}
          sub={`최근 7일 +${stats.memosThisWeek}`} />
        <StatCard label="전체 댓글" value={stats.comments} color="#085041" bg="#E1F5EE" Icon={MessageCircle}
          sub={`최근 7일 +${stats.commentsThisWeek}`} />
      </div>

      {/* 계정 현황 */}
      <p style={sectionLabel}>계정 현황</p>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))", gap: 16, marginBottom: 36 }}>
        <StatCard label="관리원" value={stats.organizations} color="#0C447C" bg="#E6F1FB" Icon={Building2} />
        <StatCard label="활성 계정" value={stats.activeMembers} color="#085041" bg="#E1F5EE" Icon={Users}
          sub={`전체 ${stats.members}개`} />
        <StatCard label="비활성 계정" value={stats.inactiveMembers} color="#555" bg="#F0F2F5" Icon={UserX} />
      </div>

      {/* 최근 메모 */}
      <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
        <p style={sectionLabel}>최근 메모</p>
        <Link href="/community" style={{ fontSize: 12, fontWeight: 700, color: "#185FA5", textDecoration: "none" }}>
          전체 보기 →
        </Link>
      </div>
      {recent.items.length === 0 ? (
        <div style={{ background: "#fff", borderRadius: 18, padding: "28px 24px", color: "#999", fontSize: 14, textAlign: "center" }}>
          아직 작성된 메모가 없습니다.
        </div>
      ) : (
        <div style={{ background: "#fff", borderRadius: 18, boxShadow: "0 2px 8px rgba(0,0,0,0.06)", overflow: "hidden" }}>
          {recent.items.map((m, i) => (
            <Link
              key={m.id}
              href={`/community/${m.id}`}
              style={{
                display: "flex", alignItems: "center", gap: 16,
                padding: "16px 24px",
                borderTop: i === 0 ? "none" : "1px solid #F0F2F5",
                textDecoration: "none", color: "inherit",
              }}
            >
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ fontSize: 14, color: "#1a1a1a", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                  {m.content}
                </p>
                <p style={{ fontSize: 12, color: "#999", marginTop: 4 }}>
                  {m.orgName} · {m.farmName ?? "양식장 미지정"} · {m.authorName} · {formatDateTime(m.createdAt)}
                </p>
              </div>
              <ChevronRight size={18} color="#ccc" style={{ flexShrink: 0 }} />
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
