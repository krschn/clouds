import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Month } from './entities/month.entity';
import { CreateMonthDto } from './dto/create-month.dto';
import { suggestCentavosPerCloud } from './domain/suggest-denomination';

@Injectable()
export class MonthsService {
  constructor(
    @InjectRepository(Month) private readonly months: Repository<Month>,
  ) {}

  findAll(): Promise<Month[]> {
    return this.months.find({
      relations: { payments: true },
      order: { period: 'ASC' },
    });
  }

  async findOne(id: string): Promise<Month> {
    const m = await this.months.findOne({
      where: { id },
      relations: { payments: true },
    });
    if (!m) throw new NotFoundException(`No month ${id}`);
    return m;
  }

  create(dto: CreateMonthDto): Promise<Month> {
    const month = this.months.create({
      period: dto.period,
      centavosPerCloud:
        dto.centavosPerCloud ??
        suggestCentavosPerCloud(dto.expectedTotalCentavos ?? 0),
      maxClouds: dto.maxClouds ?? 12,
      payments: [],
    });
    return this.months.save(month);
  }

  /**
   * Changing the denominator redraws the user's whole sky, so the client is
   * expected to confirm before calling this.
   */
  async updateRule(
    id: string,
    patch: Partial<Pick<Month, 'centavosPerCloud' | 'maxClouds'>>,
  ): Promise<Month> {
    const month = await this.findOne(id);
    Object.assign(month, patch);
    return this.months.save(month);
  }
}
