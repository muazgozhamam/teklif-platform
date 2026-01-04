const fs = require('fs');
const path = require('path');

// Minimal .env loader
function loadEnv(envPath) {
  if (!fs.existsSync(envPath)) return false;
  const content = fs.readFileSync(envPath, 'utf8');
  for (const line of content.split('\n')) {
    const t = line.trim();
    if (!t || t.startsWith('#')) continue;
    const i = t.indexOf('=');
    if (i === -1) continue;
    const key = t.slice(0, i).trim();
    let val = t.slice(i + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    if (!process.env[key]) process.env[key] = val;
  }
  return true;
}

loadEnv(path.join(__dirname, '.env'));
loadEnv(path.join(__dirname, '..', '..', '.env'));
const { Pool } = require("pg");
const { PrismaClient } = require("@prisma/client");
const { PrismaPg } = require("@prisma/adapter-pg");
const bcrypt = require("bcryptjs");

(async () => {
  const email = process.env.ADMIN_EMAIL || "admin@local.test";
  const pass  = process.env.ADMIN_PASS  || "Admin12345!";
  const dbUrl = process.env.DATABASE_URL;

  if (!dbUrl) {
    console.error("ERROR: DATABASE_URL not found. Check apps/api/.env (or repo root .env).");
    process.exit(1);
  }

  const pool = new Pool({ connectionString: dbUrl });
  const adapter = new PrismaPg(pool);
  const prisma = new PrismaClient({ adapter });

  const hash = await bcrypt.hash(pass, 10);

  const user = await prisma.user.upsert({
    where: { email },
    update: { password: hash, role: "ADMIN", name: "Local Admin" },
    create: { email, password: hash, role: "ADMIN", name: "Local Admin" },
  });

  console.log("OK admin ready:", { id: user.id, email: user.email, role: user.role });

  await prisma.$disconnect();
  await pool.end();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
