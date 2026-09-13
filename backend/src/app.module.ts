import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Month } from './months/entities/month.entity';
import { Payment } from './payments/entities/payment.entity';
import { MonthsModule } from './months/months.module';
import { PaymentsModule } from './payments/payments.module';
import { SkyModule } from './sky/sky.module';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      url: process.env.DATABASE_URL,
      entities: [Month, Payment],
      // Prototype only. Switch to migrations before anything real lands.
      synchronize: true,
    }),
    MonthsModule,
    PaymentsModule,
    SkyModule,
  ],
})
export class AppModule {}
