import CommunityList from "./CommunityList";

export default async function CommunityPage({ searchParams }: { searchParams: Promise<{ authorId?: string; authorName?: string }> }) {
  const { authorId, authorName } = await searchParams;
  return <CommunityList authorId={authorId ?? null} authorName={authorName ?? null} />;
}
