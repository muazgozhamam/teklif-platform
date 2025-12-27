#!/usr/bin/env bash
set -euo pipefail

FILE="apps/api/src/leads/leads.service.ts"

if [ ! -f "$FILE" ]; then
  echo "File not found: $FILE"
  exit 1
fi

# 1) Ensure Prisma import exists
if ! grep -q "from '@prisma/client'" "$FILE"; then
  # Insert after LeadStatus import line
  awk '
    {print}
    /from ..\/common\/lead\.enums.;/ {
      print "import { Prisma } from '\''@prisma/client'\'';"
    }
  ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
  echo "Added Prisma import."
else
  echo "Prisma import already present."
fi

# 2) Ensure AttributionUser type exists (file scope)
if ! grep -q "type AttributionUser = Prisma.UserGetPayload" "$FILE"; then
  awk '
    BEGIN{inserted=0}
    {
      print
      if (!inserted && $0 ~ /import \{ Prisma \} from '\''@prisma\/client'\'';/) {
        print ""
        print "type AttributionUser = Prisma.UserGetPayload<{"
        print "  select: { id: true; role: true; invitedById: true; email: true; name: true };"
        print "}>;"
        inserted=1
      }
    }
  ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
  echo "Added AttributionUser type."
else
  echo "AttributionUser type already present."
fi

# 3) Type the 'user' variable in buildAttributionPath
# Replace only the first occurrence inside the file.
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("apps/api/src/leads/leads.service.ts")
s = p.read_text(encoding="utf-8")

# Replace: const user = await this.prisma.user.findUnique({
# With:    const user: AttributionUser | null = await this.prisma.user.findUnique({
pattern = r"const\s+user\s*=\s*await\s+this\.prisma\.user\.findUnique\(\{"
repl = r"const user: AttributionUser | null = await this.prisma.user.findUnique({"

new_s, n = re.subn(pattern, repl, s, count=1)
if n == 0:
    print("No matching 'const user = await this.prisma.user.findUnique({' line found. No change.")
else:
    p.write_text(new_s, encoding="utf-8")
    print("Typed 'user' variable (1 replacement).")
PY

echo "Done. Now restart API:"
echo "  cd apps/api && pnpm dev"
