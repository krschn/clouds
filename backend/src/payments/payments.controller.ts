import { Body, Controller, Param, ParseUUIDPipe, Post } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { CreatePaymentDto } from './dto/create-payment.dto';

@Controller('months/:monthId/payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Post()
  create(
    @Param('monthId', ParseUUIDPipe) monthId: string,
    @Body() dto: CreatePaymentDto,
  ) {
    return this.payments.create(monthId, dto);
  }

  @Post(':paymentId/clear')
  clear(
    @Param('monthId', ParseUUIDPipe) monthId: string,
    @Param('paymentId', ParseUUIDPipe) paymentId: string,
  ) {
    return this.payments.clear(monthId, paymentId);
  }
}
