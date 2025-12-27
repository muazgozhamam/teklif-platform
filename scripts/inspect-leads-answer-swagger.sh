#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3001}"

# Swagger JSON'u indir ve node'a STDIN ile ver (argümanla taşımıyoruz)
curl -sS "$BASE_URL/docs-json" | node - <<'NODE'
let buf = '';
process.stdin.on('data', (c) => (buf += c));
process.stdin.on('end', () => {
  try {
    const j = JSON.parse(buf);
    const paths = j.paths || {};

    // Nest swagger bazen :id, bazen {id} yazar; ikisini de yakalayalım
    const key = Object.keys(paths).find(
      (p) =>
        (p.includes('/leads/') || p.startsWith('/leads')) &&
        p.includes('/answer')
    );

    if (!key) {
      console.log('HATA: swagger’da /leads/.../answer bulunamadı');
      process.exit(1);
    }

    console.log('FOUND PATH:', key);

    const obj = paths[key];
    console.log('\n==> Methods:', Object.keys(obj).join(', ').toUpperCase());

    const method =
      obj.put || obj.post || obj.patch || obj.get || obj.delete;

    if (!method) {
      console.log('HATA: bu path altında method objesi yok');
      process.exit(1);
    }

    console.log('\n==> requestBody:');
    console.dir(method.requestBody, { depth: 12 });

    console.log('\n==> parameters:');
    console.dir(method.parameters || [], { depth: 8 });
  } catch (e) {
    console.error('HATA: docs-json parse edilemedi:', e?.message || e);
    process.exit(1);
  }
});
NODE
