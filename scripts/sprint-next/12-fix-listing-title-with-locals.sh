#!/usr/bin/env bash
set -euo pipefail

# ÇALIŞMA KÖKÜ
cd ~/Desktop/teklif-platform

SVC="apps/api/src/listings/listings.service.ts"
test -f "$SVC" || { echo "ERR: missing $SVC"; exit 1; }

echo "==> Patching: $SVC"

python3 - <<'PY'
from pathlib import Path
import re

p = Path("apps/api/src/listings/listings.service.ts")
txt = p.read_text(encoding="utf-8")

# 0) deal.* referanslı title satırlarını temizle
txt = re.sub(r"\n\s*title:\s*\[deal\.city,\s*deal\.district,\s*deal\.type,\s*deal\.rooms\].*?\n", "\n", txt)

# 1) upsertFromDeal içinde "const data: any = {" bloğunu bul
m = re.search(r"(async\s+upsertFromDeal\s*\(.*?\)\s*\{\s*)(.*?)(\n\})", txt, flags=re.S)
if not m:
    raise SystemExit("ERR: cannot find upsertFromDeal()")

fn_head, fn_body, fn_tail = m.group(1), m.group(2), m.group(3)

# 2) data block'u yakala
m2 = re.search(r"const\s+data:\s*any\s*=\s*\{\s*(.*?)\s*\};", fn_body, flags=re.S)
if not m2:
    raise SystemExit("ERR: cannot find `const data: any = { ... };` inside upsertFromDeal")

data_body = m2.group(1)

# 3) data_body içinden city/district/type/rooms satırlarını bul
def find_expr(field):
    mm = re.search(rf"\b{field}\s*:\s*([^,\n]+)", data_body)
    return mm.group(1).strip() if mm else None

city_expr = find_expr("city")
district_expr = find_expr("district")
type_expr = find_expr("type")
rooms_expr = find_expr("rooms")

if not all([city_expr, district_expr, type_expr, rooms_expr]):
    raise SystemExit(f"ERR: could not locate all field expressions. city={city_expr}, district={district_expr}, type={type_expr}, rooms={rooms_expr}")

# 4) data objesinden (varsa) title satırını kaldır
data_body2 = re.sub(r"\btitle\s*:\s*[^,\n}]+,?\s*", "", data_body)

# 5) upsertFromDeal içinde data tanımından hemen önce local değişkenleri ekle
locals_block = (
    f"    const _city = {city_expr};\n"
    f"    const _district = {district_expr};\n"
    f"    const _type = {type_expr};\n"
    f"    const _rooms = {rooms_expr};\n"
    f"    const _title = [_city, _district, _type, _rooms].filter(Boolean).join(' - ') || 'İlan Taslağı';\n\n"
)

# data block'u güncelle: city/district/type/rooms'ı local'lerden set et + title ekle
# city: <expr>  -> city: _city (aynı şekilde)
def repl_field(body, field):
    return re.sub(rf"(\b{field}\s*:\s*)([^,\n]+)", rf"\1_{field}", body)

new_data_body = data_body2
new_data_body = repl_field(new_data_body, "city")
new_data_body = repl_field(new_data_body, "district")
new_data_body = repl_field(new_data_body, "type")
new_data_body = repl_field(new_data_body, "rooms")

# title ekle (sona yakın)
new_data_body = new_data_body.rstrip()
if new_data_body and not new_data_body.rstrip().endswith(","):
    new_data_body = new_data_body.rstrip() + ","
new_data_body = new_data_body + "\n      title: _title,\n"

new_data_block = f"const data: any = {{\n{new_data_body}\n    }};"

# fn_body içinde eski data block'u değiştir
fn_body2 = fn_body[:m2.start()] + new_data_block + fn_body[m2.end():]

# locals'ı data block'un hemen üstüne koy
insert_at = fn_body2.find("const data: any =")
if insert_at == -1:
    raise SystemExit("ERR: cannot re-find data block after rewrite")
fn_body3 = fn_body2[:insert_at] + locals_block + fn_body2[insert_at:]

# Fonksiyonu birleştir
out = txt[:m.start()] + fn_head + fn_body3 + fn_tail + txt[m.end():]
p.write_text(out, encoding="utf-8")
print("✅ upsertFromDeal: title now derived from locals (_city/_district/_type/_rooms)")
PY

echo
echo "==> Build"
cd apps/api
pnpm -s build

echo
echo "✅ ADIM 12 TAMAM"
