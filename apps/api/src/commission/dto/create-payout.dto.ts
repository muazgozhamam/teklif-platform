export type PayoutAllocationInput = {
  allocationId: string;
  amountMinor: string | number;
};

export class CreatePayoutDto {
  paidAt!: string;
  method!: 'BANK_TRANSFER' | 'CASH' | 'OTHER';
  referenceNo?: string;
  currency?: string;
  allocations!: PayoutAllocationInput[];
  adminOverride?: boolean;
}
