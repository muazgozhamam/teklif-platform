export type DealStatus =
  | 'DRAFT'
  | 'QUALIFIED'
  | 'OFFER_SENT'
  | 'NEGOTIATING'
  | 'ACCEPTED'
  | 'REJECTED'
  | 'EXPIRED';

export type DealEvent =
  | 'QUESTIONS_COMPLETED'
  | 'BROKER_ASSIGNED'
  | 'OFFER_SENT'
  | 'OFFER_ACCEPTED'
  | 'OFFER_REJECTED'
  | 'EXPIRE'
  | 'REOPEN_NEGOTIATION';

export function nextStatus(current: DealStatus, event: DealEvent): DealStatus {
  // Minimal, deterministic transition map
  switch (event) {
    case 'QUESTIONS_COMPLETED':
      return current === 'DRAFT' ? 'QUALIFIED' : current;

    case 'BROKER_ASSIGNED':
      // broker atanması teklif sürecine hazırlık sayılır
      return current === 'QUALIFIED' ? 'OFFER_SENT' : current;

    case 'OFFER_SENT':
      return current === 'QUALIFIED' ? 'OFFER_SENT' : current;

    case 'REOPEN_NEGOTIATION':
      return current === 'OFFER_SENT' ? 'NEGOTIATING' : current;

    case 'OFFER_ACCEPTED':
      // OFFER_SENT veya NEGOTIATING -> ACCEPTED
      return (current === 'OFFER_SENT' || current === 'NEGOTIATING') ? 'ACCEPTED' : current;

    case 'OFFER_REJECTED':
      return (current === 'OFFER_SENT' || current === 'NEGOTIATING') ? 'REJECTED' : current;

    case 'EXPIRE':
      // DRAFT dışındaki her şey expire olabilir (senin iş kuralına göre revize edilebilir)
      return current === 'ACCEPTED' || current === 'REJECTED' ? current : 'EXPIRED';

    default:
      return current;
  }
}
