import path from "node:path";
import dotenv from "dotenv";

/* AUTO-ENV-BOOTSTRAP */
// __dirname için (ESM uyumlu)
// Önce apps/api/.env
dotenv.config({ path: path.resolve(__dirname, ".env"), quiet: true });
// Sonra repo root .env (apps/api -> ../../)
dotenv.config({ path: path.resolve(__dirname, "../../.env"), quiet: true });

// Fail-fast: DATABASE_URL şart
if (!process.env.DATABASE_URL) {
  throw new Error(
    "DATABASE_URL bulunamadı. apps/api/.env içine DATABASE_URL ekle veya repo root .env'yi ayarla."
  );
}


import { defineConfig } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  datasource: {
    url: process.env.DATABASE_URL,
  },
});
