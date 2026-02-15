import { Controller, Get } from '@nestjs/common';
import { ObservabilityService } from '../observability/observability.service';

@Controller('health')
export class HealthController {
  constructor(private readonly obs: ObservabilityService) {}

  @Get()
  health() {
    return { ok: true };
  }

  @Get('metrics')
  metrics() {
    return this.obs.snapshot();
  }
}
