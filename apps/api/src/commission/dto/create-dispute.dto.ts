export class CreateDisputeDto {
  dealId!: string;
  snapshotId?: string;
  againstUserId?: string;
  type?: 'ATTRIBUTION' | 'AMOUNT' | 'ROLE' | 'OTHER';
  note?: string;
  slaDays?: number;
  evidenceMetaJson?: Record<string, unknown>;
}
