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
  const adminEmail = 'admin@local.dev';
  const adminPassword = await bcrypt.hash('admin123', 10);
  const consultantEmail = 'consultant1@test.com';
  const consultantPassword = await bcrypt.hash('pass123', 10);

  await prisma.user.upsert({
    where: { email: adminEmail },
    update: { isActive: true, role: 'ADMIN' },
    create: { email: adminEmail, password: adminPassword, role: 'ADMIN', isActive: true },
  });

  await prisma.user.upsert({
    where: { email: consultantEmail },
    update: { isActive: true, role: 'CONSULTANT', password: consultantPassword },
    create: {
      email: consultantEmail,
      password: consultantPassword,
      role: 'CONSULTANT',
      name: 'Consultant 1',
      isActive: true,
    },
  });

  console.log('✅ Admin user hazır:', adminEmail, ' / admin123');
  console.log('✅ Consultant user hazır:', consultantEmail, ' / pass123');
}

main()
  .catch((e) => {
    console.error('SEED ERROR:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
