import withRspack from "next-rspack";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  typedRoutes: false,

  images: {
    remotePatterns: [
      { protocol: "https", hostname: "images.pexels.com" },
      { protocol: "https", hostname: "images.unsplash.com" },
      { protocol: "https", hostname: "cdn.pixabay.com" },
    ],
  },

  webpack: (config) => {
    config.ignoreWarnings = [
      /pino-pretty/,
      /supportsColor/,
      /debug/,
      /metamask-sdk/,
      /rainbowkit/,
      /wagmi/,
      /Rspack/,
    ];
    return config;
  },
};

export default withRspack(nextConfig);
