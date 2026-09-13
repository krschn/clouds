import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post } from '@nestjs/common';
import { MonthsService } from './months.service';
import { CreateMonthDto } from './dto/create-month.dto';
import { Month } from './entities/month.entity';

@Controller('months')
export class MonthsController {
  constructor(private readonly months: MonthsService) {}

  @Get()
  findAll(): Promise<Month[]> {
    return this.months.findAll();
  }

  @Get(':id')
  findOne(@Param('id', ParseUUIDPipe) id: string): Promise<Month> {
    return this.months.findOne(id);
  }

  @Post()
  create(@Body() dto: CreateMonthDto): Promise<Month> {
    return this.months.create(dto);
  }

  @Patch(':id/rule')
  updateRule(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: { centavosPerCloud?: number; maxClouds?: number },
  ): Promise<Month> {
    return this.months.updateRule(id, body);
  }
}
