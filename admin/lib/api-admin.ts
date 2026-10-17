/**
 * AquaConnect 서버(/api/admin/*) 호출 — **서버 전용**.
 *
 * ⚠️ 이 파일을 클라이언트 컴포넌트("use client")에서 import 하지 말 것.
 *    ADMIN_API_KEY 가 번들에 딸려 들어간다.
 *    브라우저는 app/api/admin/[...path] 프록시를 통해 간접 호출한다.
 */

import type { AdminStats, MemoPage } from "./api";

export const API = (process.env.API_BASE_URL ?? "https://aquaconnectmvp-production.up.railway.app").replace(/\/$/, "");

export function upstream(path: string, init: RequestInit = {}): Promise<Response> {
  const headers = new Headers(init.headers);
  headers.set("X-Admin-Key", process.env.ADMIN_API_KEY ?? "");
  return fetch(`${API}/api/admin/${path}`, { ...init, headers, cache: "no-store" });
}

async function getJson<T>(path: string): Promise<T> {
  const res = await upstream(path);
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error ?? `HTTP ${res.status}`);
  return data as T;
}

export const getStats = () => getJson<AdminStats>("stats");
export const getRecentMemos = (pageSize = 5) => getJson<MemoPage>(`memos?pageSize=${pageSize}`);
