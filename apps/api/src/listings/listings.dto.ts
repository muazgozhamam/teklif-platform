export type CreateListingDto = {
  title: string;
  description?: string;
  price?: number;
  currency?: string;

  city?: string;
  district?: string;
  type?: string;
  rooms?: string;
};

export type UpdateListingDto = Partial<CreateListingDto> & {
  status?: 'DRAFT' | 'PUBLISHED' | 'ARCHIVED';
};
