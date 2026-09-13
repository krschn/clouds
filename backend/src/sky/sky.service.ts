import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Month } from '../months/entities/month.entity';
import { CloudRule } from './domain/cloud-rule';
import { SkyDto } from './dto/sky.dto';

@Injectable()
export class SkyService {
  constructor(
    @InjectRepository(Month) private readonly months: Repository<Month>,
  ) {}

  async forMonth(monthId: string): Promise<SkyDto> {
    const month = await this.months.findOne({
      where: { id: monthId },
      relations: { payments: true },
    });
    if (!month) throw new NotFoundException(`No month ${monthId}`);

    const rule = new CloudRule(month.centavosPerCloud, month.maxClouds);
    const outstanding = month.payments.reduce(
      (sum, p) => (p.clearedAt ? sum : sum + p.amountCentavos),
      0,
    );
    const cloudCount = rule.cloudsFor(outstanding);

    // cloudCount and cloudScale are sent even though the client derives them
    // itself. They are the reconciliation anchor: if the client's optimistic
    // count and the server's disagree after a sync, you have found a bug
    // rather than shipped one.
    return {
      monthId: month.id,
      period: month.period,
      outstandingCentavos: outstanding,
      centavosPerCloud: month.centavosPerCloud,
      maxClouds: month.maxClouds,
      cloudCount,
      cloudScale: rule.scaleFor(cloudCount),
    };
  }
}
