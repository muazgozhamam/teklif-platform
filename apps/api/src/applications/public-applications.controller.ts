import { Body, Controller, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { ApplicationsService } from './applications.service';

@Controller('public/applications')
export class PublicApplicationsController {
  constructor(private readonly applications: ApplicationsService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body() body: Record<string, unknown>) {
    return this.applications.createFromPublic({
      type: String(body?.type || ''),
      fullName: typeof body?.fullName === 'string' ? body.fullName : undefined,
      phone: typeof body?.phone === 'string' ? body.phone : undefined,
      email: typeof body?.email === 'string' ? body.email : undefined,
      city: typeof body?.city === 'string' ? body.city : undefined,
      district: typeof body?.district === 'string' ? body.district : undefined,
      notes: typeof body?.notes === 'string' ? body.notes : undefined,
      source: typeof body?.source === 'string' ? body.source : undefined,
      data: body?.data && typeof body.data === 'object' ? (body.data as Record<string, unknown>) : {},
    });
  }
}
