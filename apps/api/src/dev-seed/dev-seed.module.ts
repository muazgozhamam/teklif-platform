import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { DevSeedService } from './dev-seed.service';

@Module({
  imports: [PrismaModule],
  providers: [DevSeedService],
})
export class DevSeedModule {}
