import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Payment } from './entities/payment.entity';
import { CreatePaymentDto } from './dto/create-payment.dto';
import { MonthsService } from '../months/months.service';
import { SkyService } from '../sky/sky.service';
import { SkyDto } from '../sky/dto/sky.dto';

@Injectable()
export class PaymentsService {
  constructor(
    @InjectRepository(Payment) private readonly payments: Repository<Payment>,
    private readonly months: MonthsService,
    private readonly sky: SkyService,
  ) {}

  async create(monthId: string, dto: CreatePaymentDto): Promise<Payment> {
    const month = await this.months.findOne(monthId);

    if (dto.externalRef) {
      const existing = await this.payments.findOne({
        where: { externalRef: dto.externalRef },
      });
      // Replayed webhook: return what we already have instead of duplicating.
      if (existing) return existing;
    }

    return this.payments.save(
      this.payments.create({
        label: dto.label,
        amountCentavos: dto.amountCentavos,
        source: dto.source ?? 'manual',
        externalRef: dto.externalRef ?? null,
        clearedAt: null,
        month,
      }),
    );
  }

  /**
   * Returns the fresh sky alongside the payment so the client can reconcile
   * its optimistic state in the same round trip.
   */
  async clear(monthId: string, paymentId: string): Promise<{ payment: Payment; sky: SkyDto }> {
    const payment = await this.payments.findOne({
      where: { id: paymentId },
      relations: { month: true },
    });
    if (!payment) throw new NotFoundException(`No payment ${paymentId}`);
    if (payment.month.id !== monthId) {
      throw new NotFoundException(`Payment ${paymentId} is not in month ${monthId}`);
    }
    if (payment.clearedAt) {
      throw new ConflictException('Payment already cleared');
    }

    payment.clearedAt = new Date();
    await this.payments.save(payment);

    return { payment, sky: await this.sky.forMonth(monthId) };
  }
}
