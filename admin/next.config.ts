import type { NextConfig } from "next";

// The repo root has its own package-lock.json; pin the workspace root to this
// folder so Next.js doesn't trace files from the parent.
const nextConfig: NextConfig = {
  outputFileTracingRoot: __dirname,
  turbopack: { root: __dirname },
};

export default nextConfig;
