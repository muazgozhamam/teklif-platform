import { truncateToTwoSentences } from './sentenceLimit';
import type { ChatIntent } from './funnelState';

export const INTENT_CLASSIFY_PROMPT_TR = `Aşağıdaki kullanıcı mesajını intent kategorilerinden birine ayır:
CONSULTANT_APPLY, HUNTER_APPLY, OWNER_SELL, OWNER_RENT, INVESTOR, GENERIC.
Türkçe anahtarlar: danışman, avcı, iş ortağı, portföy, ilan, sat, kira.
JSON döndür: {"intent":"...","confidence":0-1,"nextQuestion":"..."}.`;

export function classifyIntentTr(text: string): { intent: ChatIntent; confidence: number } {
  const t = text.toLocaleLowerCase('tr-TR');

  if (/danışman|danisman|emlak danışman|portföy almak|portfoy almak/.test(t)) {
    return { intent: 'CONSULTANT_APPLY', confidence: 0.92 };
  }

  if (/avcı|avci|hunter|iş ortağı|is ortagi|müşteri bul|musteri bul|lead bul/.test(t)) {
    return { intent: 'HUNTER_APPLY', confidence: 0.92 };
  }

  if (/yatırım|yatirim|yatırımcı|yatirimci|getiri|değer artışı|deger artisi/.test(t)) {
    return { intent: 'INVESTOR', confidence: 0.88 };
  }

  if (/kiraya ver|kiraya vermek|kiralama|kiralık|kiralik/.test(t)) {
    return { intent: 'OWNER_RENT', confidence: 0.84 };
  }

  if (/satmak|satılık|satilik|satış|satis|evimi sat|mülk sat|mulk sat|ilan aç|ilan ac/.test(t)) {
    return { intent: 'OWNER_SELL', confidence: 0.84 };
  }

  if (/ev|daire|arsa|tarla|mülk|mulk|emlak|portföy|portfoy|ilan/.test(t)) {
    return { intent: 'GENERIC', confidence: 0.6 };
  }

  return { intent: 'GENERIC', confidence: 0.35 };
}

export function buildClarifyQuestion(intent: ChatIntent) {
  if (intent === 'CONSULTANT_APPLY') {
    return truncateToTwoSentences('Süper, danışman başvurusu için kısa bir form açabilirim. Çalışmak istediğin il ve deneyim seviyeni paylaşır mısın?');
  }
  if (intent === 'HUNTER_APPLY') {
    return truncateToTwoSentences('Harika, iş ortağı süreci için seni hızlıca başlatabiliriz. Hangi ilde aktif olduğunu paylaşır mısın?');
  }
  if (intent === 'OWNER_RENT') {
    return truncateToTwoSentences('Kiralama talebini doğru eşleştirmek için mülk tipini netleştirelim. Hangi il/ilçede ve mülk türü nedir?');
  }
  if (intent === 'OWNER_SELL') {
    return truncateToTwoSentences('Satış sürecini hızlı başlatmak için temel bilgileri alalım. Hangi il/ilçede ve mülk türü nedir?');
  }
  if (intent === 'INVESTOR') {
    return truncateToTwoSentences('Yatırım talebin için uygun eşleşme çıkarabiliriz. Hangi bölgede ve hangi mülk tipine odaklanıyorsun?');
  }
  return truncateToTwoSentences('Seni doğru sürece almak için niyetini netleştirelim. Satış, kiralama, danışmanlık veya iş ortaklığından hangisiyle ilerlemek istersin?');
}

export function reminderToCompleteForm() {
  return truncateToTwoSentences('Devam etmek için önce açılan formu tamamlaman gerekiyor. Formu gönderdiğinde bir sonraki adıma hemen geçeceğiz.');
}

export function openingFormMessage(intent: ChatIntent) {
  if (intent === 'CONSULTANT_APPLY') return truncateToTwoSentences('Sana uygun danışman başvuru formunu açıyorum. Lütfen kısa formu tamamla, hemen değerlendirmeye alalım.');
  if (intent === 'HUNTER_APPLY') return truncateToTwoSentences('Sana uygun iş ortağı başvuru formunu açıyorum. Lütfen kısa formu tamamla, süreci başlatalım.');
  if (intent === 'INVESTOR') return truncateToTwoSentences('Yatırım talep formunu açıyorum. Formu tamamladıktan sonra uygun fırsat akışıyla devam edeceğiz.');
  return truncateToTwoSentences('Mülk sahibi talep formunu açıyorum. Formu tamamladıktan sonra sana uygun eşleştirmeyi başlatacağız.');
}

export function submittedMessage(intent: ChatIntent) {
  if (intent === 'CONSULTANT_APPLY') return truncateToTwoSentences('Teşekkürler, danışman başvurun alındı. Ekibimiz kısa sürede değerlendirme adımı için seninle iletişime geçecek.');
  if (intent === 'HUNTER_APPLY') return truncateToTwoSentences('Teşekkürler, iş ortağı başvurun alındı. Uygunluk kontrolünden sonra bir sonraki adımı paylaşacağız.');
  if (intent === 'INVESTOR') return truncateToTwoSentences('Teşekkürler, yatırım talebin alındı. Profiline uygun fırsatlarla kısa sürede dönüş yapacağız.');
  return truncateToTwoSentences('Teşekkürler, mülk talebin alındı. Ekibimiz en uygun eşleşme için kısa sürede dönüş yapacak.');
}

export function resolveFormIntent(intent: ChatIntent): Exclude<ChatIntent, 'GENERIC'> {
  if (intent === 'GENERIC') return 'OWNER_SELL';
  return intent;
}
