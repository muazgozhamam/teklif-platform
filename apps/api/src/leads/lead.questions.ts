export type LeadQuestion = { key: string; question: string };

// Basit, genişletilebilir akış.
// Sonraki adımda: initialText'e göre (NLP) bazılarını otomatik dolduracağız.
export const LEAD_QUESTIONS: LeadQuestion[] = [
  { key: 'city', question: 'Hangi şehirde?' },
  { key: 'district', question: 'Hangi ilçe/mahalle?' },
  { key: 'type', question: 'Kiralık mı satılık mı? (kiralık/satılık)' },
  { key: 'rooms', question: 'Kaç oda? (örn: 2+1, 3+1)' },
];
