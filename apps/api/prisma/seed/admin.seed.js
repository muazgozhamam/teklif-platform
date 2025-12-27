const { Pool } = require("pg");
const { PrismaClient } = require("@prisma/client");
const { PrismaPg } = require("@prisma/adapter-pg");
const bcrypt = require("bcryptjs");

function norm(s){ return String(s || "").trim().replace(/^["']|["']$/g, ""); }

(async () => {
  const dbUrl = norm(process.env.DATABASE_URL);
  const pool = new Pool({ connectionString: dbUrl });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  const email = "admin@local.test";
  const plain = "Admin1234!";
  const hash = await bcrypt.hash(plain, 10);

  const existing = await prisma.user.findUnique({ where: { email } });

  if (existing) {
    const updated = await prisma.user.update({
      where: { email },
      data: { role: "ADMIN", password: hash, name: existing.name ?? "Local Admin" },
    });
    console.log("✅ Admin updated:", { id: updated.id, email: updated.email, role: updated.role, password: plain });
  } else {
    const created = await prisma.user.create({
      data: { email, password: hash, name: "Local Admin", role: "ADMIN" },
    });
    console.log("✅ Admin created:", { id: created.id, email: created.email, role: created.role, password: plain });
  }

  await prisma.$disconnect();
  await pool.end();
})().catch((e) => {
  console.error("SEED ERROR:", e?.message || e);
  process.exit(2);
});
