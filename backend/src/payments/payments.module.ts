import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Payment } from './entities/payment.entity';
import { PaymentsService } from './payments.service';
import { PaymentsController } from './payments.controller';
import { MonthsModule } from '../months/months.module';
import { SkyModule } from '../sky/sky.module';

@Module({
  imports: [TypeOrmModule.forFeature([Payment]), MonthsModule, SkyModule],
  controllers: [PaymentsController],
  providers: [PaymentsService],
})
export class PaymentsModule {}
