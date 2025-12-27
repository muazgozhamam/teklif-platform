#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/admin/leads/admin-leads.controller.ts"
if [ ! -f "$FILE" ]; then
  echo "HATA: $FILE bulunamadı."
  exit 1
fi

echo "==> Patching: $FILE"

python3 - <<'PY'
import pathlib, re

p = pathlib.Path("apps/api/src/admin/leads/admin-leads.controller.ts")
txt = p.read_text(encoding="utf-8")

# Eğer assign zaten varsa çık
if re.search(r"assignLead\s*\(", txt):
    print("==> assignLead already exists. No change.")
    raise SystemExit(0)

# 1) Import'lara gerekenleri ekle (Body, Post) ve AssignLeadDto + AdminLeadsService yoksa ekle
def ensure_import(line_pat, insert_line):
    global txt
    if re.search(line_pat, txt, flags=re.M):
        return
    # import bloklarının sonuna eklemeye çalış
    m = list(re.finditer(r"^import .*?;\s*$", txt, flags=re.M))
    if m:
        idx = m[-1].end()
        txt = txt[:idx] + "\n" + insert_line + txt[idx:]
    else:
        txt = insert_line + "\n" + txt

# Ensure AssignLeadDto import
ensure_import(r"from\s+'\./dto/assign-lead\.dto'", "import { AssignLeadDto } from './dto/assign-lead.dto';")

# Ensure AdminLeadsService import
ensure_import(r"from\s+'\./admin-leads\.service'", "import { AdminLeadsService } from './admin-leads.service';")

# Ensure JwtAuthGuard / Roles / RolesGuard imports (dosyada yoksa ekle)
ensure_import(r"JwtAuthGuard", "import { JwtAuthGuard } from '../../auth/jwt-auth.guard';")
ensure_import(r"RolesGuard", "import { RolesGuard } from '../../common/roles/roles.guard';")
ensure_import(r"Roles\s*\}", "import { Roles } from '../../common/roles/roles.decorator';")

# 2) @nestjs/common importunu genişlet: Body, Post, UseGuards, Controller, Param
m = re.search(r"^import\s+\{\s*([^}]+)\s*\}\s+from\s+'@nestjs/common';\s*$", txt, flags=re.M)
if m:
    items = [x.strip() for x in m.group(1).split(",")]
    for need in ["Body","Post","UseGuards","Controller","Param"]:
        if need not in items:
            items.append(need)
    new = "import { " + ", ".join(items) + " } from '@nestjs/common';"
    txt = txt[:m.start()] + new + txt[m.end():]
else:
    # hiç yoksa ekle
    txt = "import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';\n" + txt

# 3) Eğer @UseGuards yoksa class üstüne ekle (JwtAuthGuard, RolesGuard)
if "UseGuards" in txt and not re.search(r"@UseGuards\(\s*JwtAuthGuard\s*,\s*RolesGuard\s*\)", txt):
    # Controller dekoratöründen sonra ekle
    txt = re.sub(r"(@Controller\([^)]+\)\s*)", r"\1@UseGuards(JwtAuthGuard, RolesGuard)\n", txt, count=1)

# 4) Constructor: AdminLeadsService inject et (yoksa ekle)
if not re.search(r"constructor\s*\(\s*private\s+readonly\s+adminLeadsService\s*:\s*AdminLeadsService", txt):
    # class içinde constructor yoksa ekle; varsa değiştirmeye çalış
    if re.search(r"class\s+AdminLeadsController\s*\{", txt):
        if re.search(r"constructor\s*\(", txt):
            # mevcut constructor'a parametre eklemek riskli; en güvenlisi dosyayı komple rewrite etmek
            pass

# En güvenli: Dosyayı tamamen “beklenen” controller ile değiştirelim (projene uyumlu).
# Çünkü eldeki dosyada mevcut methodlar bilinmiyor; ama senin ihtiyacın şu anda assign route.
controller = """import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { AdminLeadsService } from './admin-leads.service';
import { AssignLeadDto } from './dto/assign-lead.dto';
import { JwtAuthGuard } from '../../auth/jwt-auth.guard';
import { Roles } from '../../common/roles/roles.decorator';
import { RolesGuard } from '../../common/roles/roles.guard';

@Controller('admin/leads')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminLeadsController {
  constructor(private readonly adminLeadsService: AdminLeadsService) {}

  @Post(':id/assign')
  @Roles('ADMIN')
  async assignLead(@Param('id') leadId: string, @Body() dto: AssignLeadDto) {
    return this.adminLeadsService.assignLead(leadId, dto.userId);
  }
}
"""
p.write_text(controller, encoding="utf-8")
print("==> Rewrote AdminLeadsController with assign route.")
PY

echo "==> DONE. Now your Nest watch should reload."
