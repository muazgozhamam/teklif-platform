/**
 * consultant.seed.js
 * - Driver adapter (pg + @prisma/adapter-pg) ile PrismaClient açar (engineType=client gereği).
 * - DB'de consultant@local.test varsa role'ünü CONSULTANT yapar, yoksa oluşturur.
 *
 * Çalıştırma: node prisma/seed/consultant.seed.js
 */
const { Pool } = require("pg");
const { PrismaClient } = require("@prisma/client");
const { PrismaPg } = require("@prisma/adapter-pg");

function norm(s){ return String(s || "").trim().replace(/^["']|["']$/g, ""); }

(async () => {
  const dbUrl = norm(process.env.DATABASE_URL);
  if (!dbUrl) {
    console.error("❌ DATABASE_URL yok. apps/api/.env veya ortam değişkeni olmalı.");
    process.exit(2);
  }
  const lower = dbUrl.toLowerCase();
  if (!(lower.startsWith("postgres://") || lower.startsWith("postgresql://"))) {
    console.error("❌ DATABASE_URL postgres değil:", dbUrl);
    process.exit(3);
  }

  const pool = new Pool({ connectionString: dbUrl });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  const email = "consultant@local.test";
  const password = "seed"; // prod değil; local seed için.
  const name = "Local Consultant";

  const existing = await prisma.user.findUnique({ where: { email } });

  if (existing) {
    const updated = await prisma.user.update({
      where: { email },
      data: { role: "CONSULTANT", name: existing.name ?? name },
    });
    console.log("✅ Consultant vardı -> role güncellendi:", {
      id: updated.id, email: updated.email, role: updated.role
    });
  } else {
    const created = await prisma.user.create({
      data: { email, password, name, role: "CONSULTANT" },
    });
    console.log("✅ Consultant oluşturuldu:", {
      id: created.id, email: created.email, role: created.role
    });
  }

  const count = await prisma.user.count({ where: { role: "CONSULTANT" } });
  console.log("CONSULTANT_COUNT=", count);

  await prisma.$disconnect();
  await pool.end();
})().catch((e) => {
  console.error("❌ SEED ERROR:", e?.message || e);
  process.exit(5);
});
