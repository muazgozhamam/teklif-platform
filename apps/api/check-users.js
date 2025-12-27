const { PrismaClient } = require('@prisma/client');

async function main() {
  const prisma = new PrismaClient();

  const users = await prisma.user.findMany({
    select: { email: true, role: true },
  });

  console.table(users);
  await prisma.$disconnect();
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
