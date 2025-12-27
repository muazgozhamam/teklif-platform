require('dotenv/config');

const bcrypt = require('bcrypt');
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

function getAdapter() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL is missing');
  return new PrismaPg({ connectionString: url });
}

const prisma = new PrismaClient({ adapter: getAdapter() });

async function main() {
  const email = 'admin@local.dev';
  const password = await bcrypt.hash('admin123', 10);

  await prisma.user.upsert({
    where: { email },
    update: {},
    create: { email, password, role: 'ADMIN' },
  });

  console.log('✅ Admin user hazır:', email, ' / admin123');
}

main()
  .catch((e) => {
    console.error('SEED ERROR:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
