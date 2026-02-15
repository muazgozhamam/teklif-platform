import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditEntityType, Prisma, Role } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';

type ListAllocationsQuery = {
  take?: number;
  skip?: number;
  snapshotId?: string;
  beneficiaryUserId?: string;
  state?: string;
};

type ExportAllocationsQuery = {
  snapshotId?: string;
  beneficiaryUserId?: string;
  state?: string;
  onlyUnexported?: boolean;
};

@Injectable()
export class AllocationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  private approxEqual(a: number, b: number, epsilon = 0.01): boolean {
    return Math.abs(a - b) <= epsilon;
  }

  private assertSnapshotMathInvariant(snapshot: {
    id: string;
    totalCommission: Prisma.Decimal | number;
    hunterAmount: Prisma.Decimal | number;
    brokerAmount: Prisma.Decimal | number;
    consultantAmount: Prisma.Decimal | number;
    platformAmount: Prisma.Decimal | number;
  }) {
    const total = Number(snapshot.totalCommission);
    const parts =
      Number(snapshot.hunterAmount) +
      Number(snapshot.brokerAmount) +
      Number(snapshot.consultantAmount) +
      Number(snapshot.platformAmount);
    if (!this.approxEqual(parts, total)) {
      throw new ConflictException(
        `Snapshot invariant failed for ${snapshot.id}: parts(${parts}) != total(${total})`,
      );
    }
  }

  async generateAllocationsForSnapshot(
    snapshotId: string,
    actor?: { actorUserId?: string | null; actorRole?: string | null },
  ) {
    const sid = String(snapshotId ?? '').trim();
    if (!sid) throw new NotFoundException('Snapshot not found');

    const snapshot = await this.prisma.commissionSnapshot.findUnique({
      where: { id: sid },
      include: {
        deal: { select: { id: true, consultantId: true } },
      },
    });
    if (!snapshot) throw new NotFoundException('Snapshot not found');
    this.assertSnapshotMathInvariant(snapshot);

    const existing = await this.prisma.commissionAllocation.findMany({
      where: { snapshotId: sid },
      orderBy: { createdAt: 'asc' },
    });
    if (existing.length > 0) {
      return existing;
    }

    const consultantId = snapshot.deal?.consultantId ?? null;
    if (!consultantId) {
      return [];
    }

    // V1 deterministic-safe rule:
    // identity allocation only, consultant gets consultantAmount with 100%.
    const created = await this.prisma.commissionAllocation.create({
      data: {
        snapshotId: sid,
        beneficiaryUserId: consultantId,
        role: Role.CONSULTANT,
        percent: 100,
        amount: Number(snapshot.consultantAmount),
        state: 'PENDING',
      },
    });

    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? null,
      action: 'COMMISSION_ALLOCATED',
      entityType: AuditEntityType.COMMISSION,
      entityId: sid,
      metaJson: {
        snapshotId: sid,
        allocationId: created.id,
        beneficiaryUserId: consultantId,
        role: created.role,
        amount: created.amount,
      },
    });

    return [created];
  }

  async listAdmin(query: ListAllocationsQuery) {
    const take = Math.min(Math.max(Number(query.take ?? 50) || 50, 1), 100);
    const skip = Math.max(Number(query.skip ?? 0) || 0, 0);
    const snapshotId = String(query.snapshotId ?? '').trim();
    const beneficiaryUserId = String(query.beneficiaryUserId ?? '').trim();
    const stateRaw = String(query.state ?? '').trim().toUpperCase();
    const where: Prisma.CommissionAllocationWhereInput = {};
    if (snapshotId) where.snapshotId = snapshotId;
    if (beneficiaryUserId) where.beneficiaryUserId = beneficiaryUserId;
    if (stateRaw) where.state = stateRaw as 'PENDING' | 'APPROVED' | 'VOID';

    const [items, total] = await Promise.all([
      this.prisma.commissionAllocation.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take,
        skip,
        include: {
          snapshot: { select: { id: true, dealId: true, createdAt: true } },
          beneficiary: { select: { id: true, email: true, role: true } },
        },
      }),
      this.prisma.commissionAllocation.count({ where }),
    ]);
    return { items, total, take, skip };
  }

  async approve(
    id: string,
    actor?: { actorUserId?: string | null; actorRole?: string | null },
  ) {
    const existing = await this.prisma.commissionAllocation.findUnique({
      where: { id },
      select: { id: true, state: true, snapshotId: true, exportedAt: true },
    });
    if (!existing) throw new NotFoundException('Allocation not found');
    if (existing.exportedAt) {
      throw new ConflictException('Exported allocation is immutable and cannot be approved');
    }
    if (existing.state === 'APPROVED') {
      return this.prisma.commissionAllocation.findUnique({ where: { id } });
    }
    const updated = await this.prisma.commissionAllocation.update({
      where: { id },
      data: { state: 'APPROVED' },
    });
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? null,
      action: 'COMMISSION_ALLOCATION_APPROVED',
      entityType: AuditEntityType.COMMISSION,
      entityId: existing.snapshotId,
      metaJson: { allocationId: id, from: existing.state, to: 'APPROVED' },
    });
    return updated;
  }

  async void(
    id: string,
    actor?: { actorUserId?: string | null; actorRole?: string | null },
  ) {
    const existing = await this.prisma.commissionAllocation.findUnique({
      where: { id },
      select: { id: true, state: true, snapshotId: true, exportedAt: true },
    });
    if (!existing) throw new NotFoundException('Allocation not found');
    if (existing.exportedAt) {
      throw new ConflictException('Exported allocation is immutable and cannot be voided');
    }
    if (existing.state === 'VOID') {
      return this.prisma.commissionAllocation.findUnique({ where: { id } });
    }
    const updated = await this.prisma.commissionAllocation.update({
      where: { id },
      data: { state: 'VOID' },
    });
    await this.audit.log({
      actorUserId: actor?.actorUserId ?? null,
      actorRole: actor?.actorRole ?? null,
      action: 'COMMISSION_ALLOCATION_VOIDED',
      entityType: AuditEntityType.COMMISSION,
      entityId: existing.snapshotId,
      metaJson: { allocationId: id, from: existing.state, to: 'VOID' },
    });
    return updated;
  }

  private buildWhere(query: {
    snapshotId?: string;
    beneficiaryUserId?: string;
    state?: string;
    onlyUnexported?: boolean;
  }): Prisma.CommissionAllocationWhereInput {
    const snapshotId = String(query.snapshotId ?? '').trim();
    const beneficiaryUserId = String(query.beneficiaryUserId ?? '').trim();
    const stateRaw = String(query.state ?? '').trim().toUpperCase();
    const where: Prisma.CommissionAllocationWhereInput = {};
    if (snapshotId) where.snapshotId = snapshotId;
    if (beneficiaryUserId) where.beneficiaryUserId = beneficiaryUserId;
    if (stateRaw) where.state = stateRaw as 'PENDING' | 'APPROVED' | 'VOID';
    if (query.onlyUnexported) where.exportedAt = null;
    return where;
  }

  async listForExport(query: ExportAllocationsQuery) {
    const where = this.buildWhere(query);
    return this.prisma.commissionAllocation.findMany({
      where,
      orderBy: { createdAt: 'asc' },
      include: {
        snapshot: { select: { id: true, dealId: true } },
        beneficiary: { select: { id: true, email: true, role: true } },
      },
    });
  }

  private csvEscape(value: unknown): string {
    const raw = value == null ? '' : String(value);
    const needsQuotes = raw.includes(',') || raw.includes('"') || raw.includes('\n');
    const escaped = raw.replaceAll('"', '""');
    return needsQuotes ? `"${escaped}"` : escaped;
  }

  async exportCsv(query: ExportAllocationsQuery): Promise<{ csv: string; count: number }> {
    const rows = await this.listForExport(query);
    const header = [
      'id',
      'snapshotId',
      'dealId',
      'beneficiaryUserId',
      'beneficiaryEmail',
      'role',
      'percent',
      'amount',
      'state',
      'createdAt',
      'exportedAt',
      'exportBatchId',
    ];
    const lines = [header.join(',')];
    for (const row of rows) {
      lines.push(
        [
          row.id,
          row.snapshotId,
          row.snapshot?.dealId ?? '',
          row.beneficiaryUserId,
          row.beneficiary?.email ?? '',
          row.role,
          row.percent,
          row.amount,
          row.state,
          row.createdAt.toISOString(),
          row.exportedAt ? row.exportedAt.toISOString() : '',
          row.exportBatchId ?? '',
        ]
          .map((v) => this.csvEscape(v))
          .join(','),
      );
    }
    return { csv: `${lines.join('\n')}\n`, count: rows.length };
  }

  async markExported(
    ids: string[],
    actor?: { actorUserId?: string | null; actorRole?: string | null },
    exportBatchId?: string | null,
  ) {
    const uniqueIds = [...new Set((ids ?? []).map((x) => String(x ?? '').trim()).filter(Boolean))];
    if (uniqueIds.length === 0) return { requested: 0, newlyMarked: 0, alreadyExported: 0 };

    const existing = await this.prisma.commissionAllocation.findMany({
      where: { id: { in: uniqueIds } },
      select: { id: true, snapshotId: true, exportedAt: true, state: true },
    });
    const existingById = new Map(existing.map((x) => [x.id, x]));
    const invalidState = existing.filter((x) => x.exportedAt == null && x.state !== 'APPROVED').map((x) => x.id);
    const markable = existing.filter((x) => x.exportedAt == null && x.state === 'APPROVED').map((x) => x.id);
    const alreadyExported = existing.filter((x) => x.exportedAt != null).map((x) => x.id);
    if (invalidState.length > 0) {
      throw new BadRequestException(`Only APPROVED allocations can be exported. Invalid ids: ${invalidState.join(',')}`);
    }

    if (markable.length > 0) {
      const now = new Date();
      await this.prisma.commissionAllocation.updateMany({
        where: { id: { in: markable }, exportedAt: null },
        data: { exportedAt: now, exportBatchId: exportBatchId ? String(exportBatchId).trim() || null : null },
      });

      const bySnapshot = new Map<string, string[]>();
      for (const id of markable) {
        const snapshotId = existingById.get(id)?.snapshotId;
        if (!snapshotId) continue;
        if (!bySnapshot.has(snapshotId)) bySnapshot.set(snapshotId, []);
        bySnapshot.get(snapshotId)?.push(id);
      }

      for (const [snapshotId, allocationIds] of bySnapshot.entries()) {
        await this.audit.log({
          actorUserId: actor?.actorUserId ?? null,
          actorRole: actor?.actorRole ?? null,
          action: 'COMMISSION_ALLOCATION_EXPORTED',
          entityType: AuditEntityType.COMMISSION,
          entityId: snapshotId,
          metaJson: {
            snapshotId,
            allocationIds,
            exportBatchId: exportBatchId ?? null,
            count: allocationIds.length,
          },
        });
      }
    }

    return {
      requested: uniqueIds.length,
      found: existing.length,
      newlyMarked: markable.length,
      alreadyExported: alreadyExported.length,
      invalidState: invalidState.length,
      missing: uniqueIds.length - existing.length,
    };
  }

  async validateSnapshotIntegrity(snapshotId: string) {
    const sid = String(snapshotId ?? '').trim();
    if (!sid) throw new NotFoundException('Snapshot not found');

    const snapshot = await this.prisma.commissionSnapshot.findUnique({
      where: { id: sid },
      include: { allocations: true },
    });
    if (!snapshot) throw new NotFoundException('Snapshot not found');

    const total = Number(snapshot.totalCommission);
    const parts =
      Number(snapshot.hunterAmount) +
      Number(snapshot.brokerAmount) +
      Number(snapshot.consultantAmount) +
      Number(snapshot.platformAmount);
    const mathOk = this.approxEqual(parts, total);

    const activeAllocations = snapshot.allocations.filter((a) => a.state !== 'VOID');
    const activeAllocationAmount = activeAllocations.reduce((sum, row) => sum + Number(row.amount), 0);
    const consultantAmount = Number(snapshot.consultantAmount);
    const allocationVsConsultantOk = this.approxEqual(activeAllocationAmount, consultantAmount);

    const exportedRows = snapshot.allocations.filter((a) => a.exportedAt != null);
    const exportedWithBatch = exportedRows.filter((a) => String(a.exportBatchId ?? '').trim().length > 0);
    const exportBatchIntegrityOk = exportedRows.length === exportedWithBatch.length;

    return {
      snapshotId: sid,
      checks: {
        mathOk,
        allocationVsConsultantOk,
        exportBatchIntegrityOk,
      },
      totals: {
        totalCommission: total,
        partsSum: parts,
        consultantAmount,
        activeAllocationAmount,
      },
      counts: {
        allocations: snapshot.allocations.length,
        activeAllocations: activeAllocations.length,
        exportedAllocations: exportedRows.length,
      },
      ok: mathOk && allocationVsConsultantOk && exportBatchIntegrityOk,
    };
  }
}
