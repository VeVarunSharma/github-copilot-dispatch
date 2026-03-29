export const config = {
  PORT: parseInt(process.env.PORT || "3001", 10),
  GITHUB_CLIENT_ID: process.env.GITHUB_CLIENT_ID || "",
  GITHUB_CLIENT_SECRET: process.env.GITHUB_CLIENT_SECRET || "",
  NODE_ENV: process.env.NODE_ENV || "development",
} as const;
