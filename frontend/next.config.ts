import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "images.pexels.com" },
      { protocol: "https", hostname: "images.unsplash.com" },
      { protocol: "https", hostname: "cdn.pixabay.com" },
    ],
  },

  experimental: {
    optimizePackageImports: ["wagmi", "viem", "lucide-react"],
  },

  turbopack: {
    rules: {
      'wasm': {
        loaders: ['asset/resource'],
        as: 'url',
      },
    },
  },
  
};

export default nextConfig;
