import { NestFactory } from '@nestjs/core';
import * as fs from 'fs';
import * as path from 'path';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';

type NodeInput = {
  pathKey: string;
  name: string;
  slug: string;
  parentPathKey?: string;
  depth: number;
  order: number;
};

const NODES: NodeInput[] = [
  { pathKey: 'emlak', name: 'Emlak', slug: 'emlak', depth: 0, order: 0 },
  { pathKey: 'emlak/konut', name: 'Konut', slug: 'konut', parentPathKey: 'emlak', depth: 1, order: 0 },
  { pathKey: 'emlak/konut/satilik', name: 'Satılık', slug: 'satilik', parentPathKey: 'emlak/konut', depth: 2, order: 0 },
  { pathKey: 'emlak/konut/kiralik', name: 'Kiralık', slug: 'kiralik', parentPathKey: 'emlak/konut', depth: 2, order: 1 },
  { pathKey: 'emlak/konut/satilik/daire', name: 'Daire', slug: 'daire', parentPathKey: 'emlak/konut/satilik', depth: 3, order: 0 },
  { pathKey: 'emlak/konut/kiralik/daire', name: 'Daire', slug: 'daire', parentPathKey: 'emlak/konut/kiralik', depth: 3, order: 0 },
  { pathKey: 'emlak/is-yeri', name: 'İş Yeri', slug: 'is-yeri', parentPathKey: 'emlak', depth: 1, order: 1 },
  { pathKey: 'emlak/is-yeri/devren-satilik', name: 'Devren Satılık', slug: 'devren-satilik', parentPathKey: 'emlak/is-yeri', depth: 2, order: 0 },
  { pathKey: 'emlak/is-yeri/devren-kiralik', name: 'Devren Kiralık', slug: 'devren-kiralik', parentPathKey: 'emlak/is-yeri', depth: 2, order: 1 },
  { pathKey: 'emlak/is-yeri/devren-satilik/cafe-restoran', name: 'Cafe & Restoran', slug: 'cafe-restoran', parentPathKey: 'emlak/is-yeri/devren-satilik', depth: 3, order: 0 },
  { pathKey: 'emlak/is-yeri/devren-satilik/dukkan-magaza', name: 'Dükkan & Mağaza', slug: 'dukkan-magaza', parentPathKey: 'emlak/is-yeri/devren-satilik', depth: 3, order: 1 },
  { pathKey: 'emlak/is-yeri/devren-satilik/ofis-buro', name: 'Ofis & Büro', slug: 'ofis-buro', parentPathKey: 'emlak/is-yeri/devren-satilik', depth: 3, order: 2 },
  { pathKey: 'emlak/is-yeri/devren-kiralik/cafe-restoran', name: 'Cafe & Restoran', slug: 'cafe-restoran', parentPathKey: 'emlak/is-yeri/devren-kiralik', depth: 3, order: 0 },
  { pathKey: 'emlak/is-yeri/devren-kiralik/dukkan-magaza', name: 'Dükkan & Mağaza', slug: 'dukkan-magaza', parentPathKey: 'emlak/is-yeri/devren-kiralik', depth: 3, order: 1 },
  { pathKey: 'emlak/is-yeri/devren-kiralik/ofis-buro', name: 'Ofis & Büro', slug: 'ofis-buro', parentPathKey: 'emlak/is-yeri/devren-kiralik', depth: 3, order: 2 },
];

const DAIRE_ATTRS = [
  { key: 'gross_m2', label: 'Brüt m²', type: 'NUMBER', required: true, order: 0 },
  { key: 'net_m2', label: 'Net m²', type: 'NUMBER', required: true, order: 1 },
  { key: 'room_count', label: 'Oda Sayısı', type: 'SELECT', required: true, order: 2, optionsJson: ['1+0', '1+1', '2+1', '3+1', '4+1', '5+1'] },
  { key: 'building_age', label: 'Bina Yaşı', type: 'SELECT', required: true, order: 3, optionsJson: ['0', '1-5', '6-10', '11-15', '16-20', '20+'] },
  { key: 'floor', label: 'Bulunduğu Kat', type: 'SELECT', required: true, order: 4, optionsJson: ['Zemin', '1', '2', '3', '4', '5+'] },
  { key: 'total_floors', label: 'Kat Sayısı', type: 'SELECT', required: true, order: 5, optionsJson: ['1', '2', '3', '4', '5', '6+'] },
  { key: 'heating', label: 'Isıtma', type: 'SELECT', required: true, order: 6, optionsJson: ['Kombi (Doğalgaz)', 'Merkezi', 'Soba', 'Yerden Isıtma'] },
] as const;

function parseCsvNodes(raw: string): NodeInput[] {
  const rows = raw
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#'));

  const parsed: NodeInput[] = [];
  for (const row of rows) {
    const parts = row.split(',').map((p) => p.trim());
    if (parts.length < 7) continue;
    const pathKey = parts[0];
    const isActiveRaw = parts[parts.length - 1];
    const orderRaw = parts[parts.length - 2];
    const depthRaw = parts[parts.length - 3];
    const parentPathKeyRaw = parts[parts.length - 4];
    const slug = parts[parts.length - 5];
    const name = parts
      .slice(1, parts.length - 5)
      .join(',')
      .trim()
      .replace(/^"(.*)"$/, '$1')
      .trim();
    const isActive = String(isActiveRaw).toLowerCase() === 'true';
    if (!isActive || !pathKey || !name || !slug) continue;
    const depth = Number(depthRaw);
    const order = Number(orderRaw);
    if (!Number.isFinite(depth) || !Number.isFinite(order)) continue;
    parsed.push({
      pathKey,
      name,
      slug,
      parentPathKey: parentPathKeyRaw || undefined,
      depth,
      order,
    });
  }
  return parsed;
}

function loadCsvNodes(): NodeInput[] {
  const csvPath =
    process.env.LISTINGS_CATEGORY_CSV_PATH ||
    path.resolve(process.cwd(), 'scripts/data/listings-categories.csv');
  if (!fs.existsSync(csvPath)) return [];
  const raw = fs.readFileSync(csvPath, 'utf8');
  const parsed = parseCsvNodes(raw);

  // Business rule: Devren Kiralık leaf seti, Devren Satılık ile birebir aynı olmalı.
  const hasDevrenKiralikRoot = parsed.some((n) => n.pathKey === 'emlak/is-yeri/devren-kiralik');
  if (!hasDevrenKiralikRoot) return parsed;

  const satilikLeaves = parsed.filter(
    (n) => n.parentPathKey === 'emlak/is-yeri/devren-satilik' && n.depth === 3,
  );

  const toAppend: NodeInput[] = [];
  const existing = new Set(parsed.map((n) => n.pathKey));
  for (const leaf of satilikLeaves) {
    const suffix = leaf.pathKey.replace('emlak/is-yeri/devren-satilik/', '');
    const clonedPathKey = `emlak/is-yeri/devren-kiralik/${suffix}`;
    if (existing.has(clonedPathKey)) continue;
    toAppend.push({
      pathKey: clonedPathKey,
      name: leaf.name,
      slug: leaf.slug,
      parentPathKey: 'emlak/is-yeri/devren-kiralik',
      depth: leaf.depth,
      order: leaf.order,
    });
    existing.add(clonedPathKey);
  }

  return [...parsed, ...toAppend];
}

async function upsertNodes(prisma: any) {
  const fromCsv = loadCsvNodes();
  const nodeList = fromCsv.length > 0 ? fromCsv : NODES;
  for (const node of nodeList) {
    let parentId: string | undefined;
    if (node.parentPathKey) {
      const parent = await prisma.categoryNode.findUnique({ where: { pathKey: node.parentPathKey } });
      parentId = parent?.id;
    }
    await prisma.categoryNode.upsert({
      where: { pathKey: node.pathKey },
      update: {
        name: node.name,
        slug: node.slug,
        depth: node.depth,
        order: node.order,
        isActive: true,
        parentId: parentId || null,
      },
      create: {
        pathKey: node.pathKey,
        name: node.name,
        slug: node.slug,
        depth: node.depth,
        order: node.order,
        isActive: true,
        parentId: parentId || null,
      },
    });
  }
}

async function upsertAttributesForLeaf(prisma: any, pathKey: string) {
  const leaf = await prisma.categoryNode.findUnique({ where: { pathKey } });
  if (!leaf?.id) throw new Error(`Category leaf not found: ${pathKey}`);

  for (const attr of DAIRE_ATTRS) {
    await prisma.attributeDefinition.upsert({
      where: { categoryLeafId_key: { categoryLeafId: leaf.id, key: attr.key } },
      update: {
        label: attr.label,
        type: attr.type,
        required: attr.required,
        order: attr.order,
        optionsJson: (attr as any).optionsJson || null,
      },
      create: {
        categoryLeafId: leaf.id,
        key: attr.key,
        label: attr.label,
        type: attr.type,
        required: attr.required,
        order: attr.order,
        optionsJson: (attr as any).optionsJson || null,
      },
    });
  }
}

async function run() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const prisma = app.get(PrismaService) as any;
  await upsertNodes(prisma);
  await upsertAttributesForLeaf(prisma, 'emlak/konut/satilik/daire');
  await upsertAttributesForLeaf(prisma, 'emlak/konut/kiralik/daire');
  console.log('✅ listings taxonomy + attributes seeded (idempotent)');
  await app.close();
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
