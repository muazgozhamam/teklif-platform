import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

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

async function upsertNodes() {
  for (const node of NODES) {
    let parentId: string | undefined;
    if (node.parentPathKey) {
      const parent = await (prisma as any).categoryNode.findUnique({ where: { pathKey: node.parentPathKey } });
      parentId = parent?.id;
    }

    await (prisma as any).categoryNode.upsert({
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

async function upsertAttributesForLeaf(pathKey: string) {
  const leaf = await (prisma as any).categoryNode.findUnique({ where: { pathKey } });
  if (!leaf?.id) throw new Error(`Category leaf not found: ${pathKey}`);

  for (const attr of DAIRE_ATTRS) {
    await (prisma as any).attributeDefinition.upsert({
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

async function main() {
  await upsertNodes();
  await upsertAttributesForLeaf('emlak/konut/satilik/daire');
  await upsertAttributesForLeaf('emlak/konut/kiralik/daire');
  console.log('✅ listings taxonomy + attributes seeded (idempotent)');
}

main()
  .catch((err) => {
    console.error(err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

