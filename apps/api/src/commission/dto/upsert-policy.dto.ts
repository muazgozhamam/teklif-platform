export class UpsertCommissionPolicyDto {
  name?: string;
  calcMethod?: 'PERCENTAGE' | 'FIXED';
  commissionRateBasisPoints?: number;
  fixedCommissionMinor?: string | number;
  currency?: string;
  hunterPercentBasisPoints!: number;
  consultantPercentBasisPoints!: number;
  brokerPercentBasisPoints!: number;
  systemPercentBasisPoints!: number;
  roundingRule?: 'ROUND_HALF_UP' | 'BANKERS';
  effectiveFrom?: string;
}

