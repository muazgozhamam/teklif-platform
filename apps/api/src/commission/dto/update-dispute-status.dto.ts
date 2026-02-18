export class UpdateDisputeStatusDto {
  status!: 'UNDER_REVIEW' | 'ESCALATED' | 'RESOLVED_APPROVED' | 'RESOLVED_REJECTED';
  note?: string;
}
