import { Module } from '@nestjs/common';
import { OrgModule } from '../../org/org.module';
import { AdminOrgController } from './admin-org.controller';

@Module({
  imports: [OrgModule],
  controllers: [AdminOrgController],
})
export class AdminOrgModule {}

