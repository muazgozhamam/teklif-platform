#!/usr/bin/env bash
set -euo pipefail

API="$(pwd)/apps/api"

node - <<'NODE'
const { PrismaClient } = require('./apps/api/node_modules/@prisma/client');
const prisma = new PrismaClient();

(async () => {
  const email = 'consultant@local.test';

  const exists = await prisma.user.findUnique({ where: { email } });
  if (exists) {
    console.log('CONSULTANT already exists:', exists.id);
    return;
  }

  const bcrypt = require('bcrypt');
  const password = await bcrypt.hash('123456', 10);

  const user = await prisma.user.create({
    data: {
      email,
      password,
      name: 'Default Consultant',
      role: 'CONSULTANT',
    },
  });

  console.log('✅ CONSULTANT created:', user.id);
})()
.finally(() => prisma.$disconnect());
NODE
