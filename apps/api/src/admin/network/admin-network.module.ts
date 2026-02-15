import { Module } from '@nestjs/common';
import { AdminNetworkController } from './admin-network.controller';
import { NetworkModule } from '../../network/network.module';

@Module({
  imports: [NetworkModule],
  controllers: [AdminNetworkController],
})
export class AdminNetworkModule {}

