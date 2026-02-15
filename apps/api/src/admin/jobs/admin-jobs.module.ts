import { Module } from '@nestjs/common';
import { AllocationsModule } from '../../allocations/allocations.module';
import { AdminJobsController } from './admin-jobs.controller';
import { AdminJobsService } from './admin-jobs.service';

@Module({
  imports: [AllocationsModule],
  controllers: [AdminJobsController],
  providers: [AdminJobsService],
})
export class AdminJobsModule {}
