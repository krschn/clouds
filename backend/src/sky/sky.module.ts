import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Month } from '../months/entities/month.entity';
import { SkyService } from './sky.service';
import { SkyController } from './sky.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Month])],
  controllers: [SkyController],
  providers: [SkyService],
  exports: [SkyService],
})
export class SkyModule {}
