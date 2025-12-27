const { Pool } = require("pg");
const { PrismaClient } = require("@prisma/client");
const { PrismaPg } = require("@prisma/adapter-pg");
const bcrypt = require("bcryptjs");

function norm(s){ return String(s || "").trim().replace(/^["']|["']$/g, ""); }

async function upsertUser(prisma, { email, passwordPlain, name, role }) {
  const passwordHash = await bcrypt.hash(passwordPlain, 10);
  const existing = await prisma.user.findUnique({ where: { email } });

  const data = { email, password: passwordHash, name, role };

  if (existing) {
    const u = await prisma.user.update({ where: { email }, data });
    return { action: "updated", user: u };
  } else {
    const u = await prisma.user.create({ data });
    return { action: "created", user: u };
  }
}

(async () => {
  const dbUrl = norm(process.env.DATABASE_URL);
  if (dbUrl.length === 0) throw new Error("DATABASE_URL missing");

  const pool = new Pool({ connectionString: dbUrl });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  // ADMIN
  const admin = await upsertUser(prisma, {
    email: "admin@local.test",
    passwordPlain: "Admin1234!",
    name: "Local Admin",
    role: "ADMIN",
  });

  // CONSULTANT1 (varsa role fix)
  const c1 = await upsertUser(prisma, {
    email: "consultant@local.test",
    passwordPlain: "Consultant123!",
    name: "Local Consultant",
    role: "CONSULTANT",
  });

  // CONSULTANT2
  const c2 = await upsertUser(prisma, {
    email: "consultant2@local.test",
    passwordPlain: "Consultant123!",
    name: "Local Consultant 2",
    role: "CONSULTANT",
  });

  console.log("✅ Seed OK");
  console.log("ADMIN:", { action: admin.action, id: admin.user.id, email: admin.user.email, role: admin.user.role });
  console.log("C1   :", { action: c1.action, id: c1.user.id, email: c1.user.email, role: c1.user.role });
  console.log("C2   :", { action: c2.action, id: c2.user.id, email: c2.user.email, role: c2.user.role });

  await prisma.$disconnect();
  await pool.end();
})().catch((e) => {
  console.error("SEED ERROR:", e?.message || e);
  process.exit(2);
});
