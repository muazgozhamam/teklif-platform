import { Module } from '@nestjs/common';
import { PublicController } from './public.controller';
import { PublicChatService } from './public-chat.service';

@Module({
  controllers: [PublicController],
  providers: [PublicChatService],
})
export class PublicModule {}
