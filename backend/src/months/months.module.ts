import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Month } from './entities/month.entity';
import { MonthsService } from './months.service';
import { MonthsController } from './months.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Month])],
  controllers: [MonthsController],
  providers: [MonthsService],
  exports: [MonthsService],
})
export class MonthsModule {}
