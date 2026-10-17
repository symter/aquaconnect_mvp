// 클라이언트 컴포넌트도 쓰는 타입·라벨만 둔다.
// 실제 백엔드 호출은 lib/api-admin.ts(서버 전용)와 app/api/admin/[...path] 프록시가 한다.

export type MemberRole = "owner" | "director" | "staff" | "employee";
export type MemberStatus = "active" | "inactive";

export interface AdminStats {
  organizations: number;
  members: number;
  activeMembers: number;
  inactiveMembers: number;
  memos: number;
  memosThisWeek: number;
  comments: number;
  commentsThisWeek: number;
}

export interface Organization {
  id: string;
  name: string;
  memberCount: number;
  createdAt: string;
}

export interface Member {
  id: string;
  orgId: string;
  orgName: string;
  name: string;
  email: string;
  phone: string | null;
  role: MemberRole;
  status: MemberStatus;
  memoCount: number;
  commentCount: number;
  marketingAgreed: boolean;
  termsAgreedAt: string | null;
  createdAt: string;
}

export interface Memo {
  id: string;
  orgId: string;
  orgName: string;
  farmId: string | null;
  farmName: string | null;
  authorType: "institute" | "farm";
  authorName: string;
  authorMemberId: string | null;
  content: string;
  tags: string[];
  photoCount: number;
  commentCount: number;
  editCount: number;
  createdAt: string;
}

export interface MemoPage {
  items: Memo[];
  total: number;
  page: number;
  pageSize: number;
}

export interface MemoComment {
  id: string;
  authorMemberId: string | null;
  authorName: string;
  content: string;
  createdAt: string;
}

export interface MemoDetail extends Memo {
  photoIds: string[];
  comments: MemoComment[];
  edits: { editorName: string; previousContent: string; editedAt: string }[];
}

export const ROLE_LABELS: Record<MemberRole, string> = {
  owner: "소유자",
  director: "원장",
  staff: "수산질병관리사",
  employee: "직원",
};

/** 브라우저에서 /api/admin/* 프록시를 부른다. 실패하면 서버 메시지로 throw. */
export async function adminFetch<T = unknown>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api/admin/${path}`, {
    ...init,
    headers: init?.body ? { "Content-Type": "application/json", ...init.headers } : init?.headers,
    cache: "no-store",
  });
  if (res.status === 204) return undefined as T;
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error ?? `HTTP ${res.status}`);
  return data as T;
}

export function formatDateTime(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}.${pad(d.getMonth() + 1)}.${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function formatPhone(value: string | null): string {
  const d = (value ?? "").replace(/\D/g, "");
  if (d.length === 11) return `${d.slice(0, 3)}-${d.slice(3, 7)}-${d.slice(7)}`;
  if (d.length === 10) return d.startsWith("02") ? `${d.slice(0, 2)}-${d.slice(2, 6)}-${d.slice(6)}` : `${d.slice(0, 3)}-${d.slice(3, 6)}-${d.slice(6)}`;
  return d;
}
