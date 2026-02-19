export type ListingScope = 'own' | 'all';

export type ListListingsQuery = {
  q?: string;
  categoryPathKey?: string;
  city?: string;
  district?: string;
  neighborhood?: string;
  priceMin?: string;
  priceMax?: string;
  bbox?: string;
  take?: string;
  skip?: string;
  status?: 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
  scope?: ListingScope;
};

export type CreateListingDto = {
  categoryLeafId?: string;
  categoryPathKey?: string;
  title?: string;
  description?: string;
  priceAmount?: string | number;
  currency?: string;
  city?: string;
  district?: string;
  neighborhood?: string;
  lat?: number;
  lng?: number;
  privacyMode?: 'EXACT' | 'APPROXIMATE' | 'HIDDEN';

  // backward compatibility
  type?: string;
  rooms?: string;
  consultantId?: string;
};

export type UpdateListingDto = Partial<CreateListingDto> & {
  status?: 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
  sahibindenUrl?: string;
};

export type UpsertListingAttributesDto = {
  attributes: Array<{
    key: string;
    value: unknown;
  }>;
};

export type UpdateSahibindenDto = {
  sahibindenUrl?: string;
  markExported?: boolean;
};

export type PublishListingDto = {
  force?: boolean;
};

