#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$ROOT_DIR/scripts"

cat > "$ROOT_DIR/scripts/match-doctor.sh" <<'SH'
#!/usr/bin/env bash
# ÇALIŞILACAK KÖK: ~/Desktop/teklif-platform
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
API_DIR="$ROOT_DIR/apps/api"

echo "==> ROOT: $ROOT_DIR"
echo "==> API : $API_DIR"
echo

if [ ! -d "$API_DIR" ]; then
  echo "HATA: apps/api bulunamadı: $API_DIR"
  exit 1
fi

cd "$API_DIR"

echo "==> DATABASE_URL kontrol"
if [ -z "${DATABASE_URL:-}" ]; then
  echo "HATA: DATABASE_URL environment'ta yok."
  echo "ÇÖZÜM (apps/api içinde):"
  echo "  set -a; source ./.env; set +a"
  echo "Sonra tekrar:"
  echo "  cd $ROOT_DIR && bash ./scripts/match-doctor.sh"
  exit 1
fi
echo "OK: DATABASE_URL set"
echo

echo "==> Prisma generate"
pnpm -s prisma generate
echo

echo "==> Match Doctor"
node "$ROOT_DIR/scripts/_match_doctor.mjs"
SH

cat > "$ROOT_DIR/scripts/_match_doctor.mjs" <<'NODE'
import fs from "fs";
import path from "path";
import process from "process";

const ROOT = process.cwd(); // scripts çalışırken ROOT = repo root beklenir
const API_DIR = path.join(ROOT, "apps", "api");
const schemaPath = path.join(API_DIR, "prisma", "schema.prisma");

function readSchema() {
  if (!fs.existsSync(schemaPath)) throw new Error("schema.prisma yok: " + schemaPath);
  return fs.readFileSync(schemaPath, "utf8");
}

function parseModels(schemaText) {
  const models = [];
  const re = /model\s+(\w+)\s*\{([\s\S]*?)\n\}/g;
  let m;
  while ((m = re.exec(schemaText))) {
    const name = m[1];
    const body = m[2];
    const fields = body.split("\n").map(l => l.trim()).filter(l => l && !l.startsWith("//"));
    models.push({ name, fields });
  }
  return models;
}

function parseEnums(schemaText) {
  const enums = {};
  const re = /enum\s+(\w+)\s*\{([\s\S]*?)\n\}/g;
  let m;
  while ((m = re.exec(schemaText))) {
    const name = m[1];
    const body = m[2];
    const vals = body.split("\n").map(l => l.trim()).filter(l => l && !l.startsWith("//")).map(l => l.split(/\s+/)[0]);
    enums[name] = vals;
  }
  return enums;
}

function findRoleEnum(enums) {
  for (const [k, vals] of Object.entries(enums)) {
    if (vals.some(v => /CONSULTANT/i.test(v))) return { enumName: k, values: vals };
  }
  return null;
}

function pickConsultantModel(models) {
  const byName = models.find(m => /consultant/i.test(m.name));
  if (byName) return byName;

  // Bu projede consultant = User.role = CONSULTANT gibi görünüyor
  const userLike = models.find(m =>
    m.name === "User" ||
    (m.fields.some(f => /^role\s+/.test(f)) && m.fields.some(f => /^email\s+/.test(f)))
  );
  return userLike ?? null;
}

function grepDealMatchLogic() {
  const dealsService = path.join(API_DIR, "src", "deals", "deals.service.ts");
  if (!fs.existsSync(dealsService)) return null;
  const txt = fs.readFileSync(dealsService, "utf8");
  const idx = txt.indexOf("No consultant available");
  if (idx === -1) return { found: false, snippet: null };
  const start = Math.max(0, idx - 700);
  const end = Math.min(txt.length, idx + 700);
  return { found: true, snippet: txt.slice(start, end) };
}

(async () => {
  const schema = readSchema();
  const models = parseModels(schema);
  const enums = parseEnums(schema);
  const roleEnum = findRoleEnum(enums);
  const consultantModel = pickConsultantModel(models);

  console.log("==> MODELS:", models.map(m => m.name).join(", "));
  console.log("==> Role enum:", roleEnum ? `${roleEnum.enumName} [${roleEnum.values.join(", ")}]` : "YOK");
  console.log("==> Consultant modeli tahmini:", consultantModel ? consultantModel.name : "YOK");
  console.log("");

  const logic = grepDealMatchLogic();
  if (logic?.found) {
    console.log("==> deals.service.ts içinde 'No consultant available' çevresi (snippet):");
    console.log("-----");
    console.log(logic.snippet);
    console.log("-----\n");
  } else {
    console.log("==> deals.service.ts içinde 'No consultant available' string'i bulunamadı (farklı dosyada olabilir).\n");
  }

  console.log("==> Not: PrismaClient ile sayım yapmıyorum; sende PrismaClient init (accelerate/adapter) farklı davranıyor.");
  console.log("==> Şimdi hedef: snippet'te consultant filtrelerini net görüp doğru seed kriterini yazmak.");
})();
NODE

chmod +x "$ROOT_DIR/scripts/match-doctor.sh" "$ROOT_DIR/scripts/install-match-doctor.sh"

echo "✅ install-match-doctor.sh hazır."
echo "Çalıştır:"
echo "  cd $ROOT_DIR && bash ./scripts/install-match-doctor.sh"
echo "Sonra:"
echo "  cd $ROOT_DIR && bash ./scripts/match-doctor.sh"
