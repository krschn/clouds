import { Controller, Get, Param, ParseUUIDPipe } from '@nestjs/common';
import { SkyService } from './sky.service';
import { SkyDto } from './dto/sky.dto';

@Controller('months/:monthId/sky')
export class SkyController {
  constructor(private readonly sky: SkyService) {}

  @Get()
  get(@Param('monthId', ParseUUIDPipe) monthId: string): Promise<SkyDto> {
    return this.sky.forMonth(monthId);
  }
}
