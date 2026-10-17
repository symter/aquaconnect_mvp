"use client";

import { use, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft, History, MessageCircle, Trash2 } from "lucide-react";
import { adminFetch, formatDateTime, type MemoDetail } from "@/lib/api";
import { Badge, Button, cardStyle, COLORS, Empty, ErrorBox, Loading, SectionLabel } from "@/components/ui";

export default function MemoDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const [memo, setMemo] = useState<MemoDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [showEdits, setShowEdits] = useState(false);

  const fetchMemo = useCallback(async () => {
    setError("");
    try {
      setMemo(await adminFetch<MemoDetail>(`memos/${id}`));
    } catch (e) {
      setError(e instanceof Error ? e.message : "메모를 불러올 수 없습니다.");
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => { fetchMemo(); }, [fetchMemo]);

  async function deleteMemo() {
    if (!confirm("이 메모를 삭제할까요?\n사진·댓글·수정 이력도 함께 삭제되며 되돌릴 수 없습니다.")) return;
    setBusy("memo");
    try {
      await adminFetch(`memos/${id}`, { method: "DELETE" });
      router.push("/community");
      router.refresh();
    } catch (e) {
      alert(e instanceof Error ? e.message : "삭제에 실패했습니다.");
      setBusy(null);
    }
  }

  async function deleteComment(commentId: string) {
    if (!confirm("이 댓글을 삭제할까요? 되돌릴 수 없습니다.")) return;
    setBusy(commentId);
    try {
      await adminFetch(`comments/${commentId}`, { method: "DELETE" });
      await fetchMemo();
    } catch (e) {
      alert(e instanceof Error ? e.message : "삭제에 실패했습니다.");
    } finally {
      setBusy(null);
    }
  }

  return (
    <div style={{ maxWidth: 860 }}>
      <Link href="/community" style={{ display: "inline-flex", alignItems: "center", gap: 6, fontSize: 13, fontWeight: 600, color: "#666", textDecoration: "none", marginBottom: 20 }}>
        <ArrowLeft size={16} /> 커뮤니티 관리
      </Link>

      {loading && <Loading />}
      {error && <ErrorBox>{error}</ErrorBox>}

      {memo && (
        <>
          {/* 메모 본문 */}
          <div style={{ ...cardStyle, padding: "24px 28px", marginBottom: 24 }}>
            <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 16, marginBottom: 16, flexWrap: "wrap" }}>
              <div>
                <div style={{ display: "flex", alignItems: "center", gap: 6, flexWrap: "wrap" }}>
                  <Badge color={COLORS.primaryDark} bg={COLORS.primarySoft}>{memo.orgName}</Badge>
                  {memo.authorType === "farm" && <Badge color={COLORS.successText} bg={COLORS.successSoft}>양식장 문의</Badge>}
                </div>
                <h1 style={{ fontSize: 20, fontWeight: 800, color: "#1a1a1a", marginTop: 10 }}>
                  {memo.farmName ?? "양식장 미지정"}
                </h1>
                <p style={{ fontSize: 13, color: "#999", marginTop: 4 }}>
                  {memo.authorMemberId ? (
                    <Link href={`/accounts/${memo.authorMemberId}`} style={{ color: COLORS.primary, textDecoration: "none", fontWeight: 600 }}>
                      {memo.authorName}
                    </Link>
                  ) : memo.authorName}
                  {" · "}{formatDateTime(memo.createdAt)}
                </p>
              </div>
              <Button variant="danger" disabled={busy === "memo"} onClick={deleteMemo}>
                <Trash2 size={14} />
                {busy === "memo" ? "삭제 중..." : "메모 삭제"}
              </Button>
            </div>

            <p style={{ fontSize: 15, color: "#222", lineHeight: 1.7, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>{memo.content}</p>

            {memo.tags.length > 0 && (
              <div style={{ display: "flex", gap: 6, marginTop: 14, flexWrap: "wrap" }}>
                {memo.tags.map((t) => <Badge key={t} color="#555" bg={COLORS.neutralSoft}>#{t}</Badge>)}
              </div>
            )}

            {memo.photoIds.length > 0 && (
              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(140px, 1fr))", gap: 10, marginTop: 18 }}>
                {memo.photoIds.map((pid) => (
                  <a key={pid} href={`/api/admin/photos/${pid}`} target="_blank" rel="noreferrer">
                    {/* eslint-disable-next-line @next/next/no-img-element -- 관리자 세션 쿠키가 필요한 프록시 이미지 */}
                    <img
                      src={`/api/admin/photos/${pid}`}
                      alt="메모 사진"
                      style={{ width: "100%", aspectRatio: "1", objectFit: "cover", borderRadius: 12, background: COLORS.neutralSoft, display: "block" }}
                    />
                  </a>
                ))}
              </div>
            )}

            {memo.edits.length > 0 && (
              <div style={{ marginTop: 18, borderTop: "1px solid #F0F2F5", paddingTop: 14 }}>
                <button
                  onClick={() => setShowEdits(!showEdits)}
                  style={{ display: "inline-flex", alignItems: "center", gap: 6, border: "none", background: "transparent", color: "#666", fontSize: 13, fontWeight: 600, cursor: "pointer", fontFamily: "inherit", padding: 0 }}
                >
                  <History size={14} /> 수정 이력 {memo.edits.length}건 {showEdits ? "접기" : "보기"}
                </button>
                {showEdits && (
                  <div style={{ display: "flex", flexDirection: "column", gap: 10, marginTop: 12 }}>
                    {memo.edits.map((e, i) => (
                      <div key={i} style={{ background: "#FAFAFA", borderRadius: 12, padding: "12px 16px" }}>
                        <p style={{ fontSize: 12, color: "#999", marginBottom: 6 }}>
                          {e.editorName || "알 수 없음"} · {formatDateTime(e.editedAt)} 수정 전 내용
                        </p>
                        <p style={{ fontSize: 13, color: "#555", lineHeight: 1.6, whiteSpace: "pre-wrap" }}>{e.previousContent}</p>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>

          {/* 댓글 */}
          <SectionLabel>
            <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
              <MessageCircle size={13} /> 댓글 {memo.comments.length}
            </span>
          </SectionLabel>
          {memo.comments.length === 0 ? (
            <div style={cardStyle}><Empty>댓글이 없습니다.</Empty></div>
          ) : (
            <div style={{ ...cardStyle, padding: 0, overflow: "hidden" }}>
              {memo.comments.map((c, i) => (
                <div
                  key={c.id}
                  style={{ display: "flex", gap: 16, alignItems: "flex-start", padding: "16px 24px", borderTop: i === 0 ? "none" : "1px solid #F0F2F5" }}
                >
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{ fontSize: 13, fontWeight: 700, color: "#1a1a1a" }}>
                      {c.authorMemberId ? (
                        <Link href={`/accounts/${c.authorMemberId}`} style={{ color: "inherit", textDecoration: "none" }}>{c.authorName}</Link>
                      ) : c.authorName || "알 수 없음"}
                      <span style={{ fontSize: 12, fontWeight: 400, color: "#aaa", marginLeft: 8 }}>{formatDateTime(c.createdAt)}</span>
                    </p>
                    <p style={{ fontSize: 14, color: "#333", lineHeight: 1.6, marginTop: 4, whiteSpace: "pre-wrap", wordBreak: "break-word" }}>{c.content}</p>
                  </div>
                  <Button variant="outline" disabled={busy === c.id} onClick={() => deleteComment(c.id)}>
                    <Trash2 size={14} />
                    {busy === c.id ? "삭제 중..." : "삭제"}
                  </Button>
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}
