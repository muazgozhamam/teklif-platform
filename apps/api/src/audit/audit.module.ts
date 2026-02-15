import { Global, Module } from '@nestjs/common';
import { AuditController } from './audit.controller';
import { AdminAuditController } from './admin-audit.controller';
import { AuditService } from './audit.service';

@Global()
@Module({
  controllers: [AuditController, AdminAuditController],
  providers: [AuditService],
  exports: [AuditService],
})
export class AuditModule {}
