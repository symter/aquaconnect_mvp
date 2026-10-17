import type { NextConfig } from "next";

// Don't set outputFileTracingRoot / turbopack.root here: on Vercel (Root
// Directory = admin) it makes the builder resolve traced files against the
// repo root and fail with "ENOENT ... /vercel/path0/.next/package.json".
// The local "multiple lockfiles" warning it would silence is harmless.
const nextConfig: NextConfig = {};

export default nextConfig;
