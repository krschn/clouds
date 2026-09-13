// Must be the first import: AppModule reads process.env.DATABASE_URL while its
// decorators evaluate, which happens as soon as the import below is resolved.
// Load .env any later and TypeORM gets an undefined connection string.
import 'dotenv/config';

import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Flutter web serves from a random localhost port, so the browser treats every
  // API call as cross-origin and preflights it. Native builds never hit this.
  // Wide open is fine while CORS_ORIGIN is unset and this is a local prototype;
  // set it to the real origin before anything ships.
  app.enableCors({
    origin: process.env.CORS_ORIGIN ?? true,
    credentials: true,
  });

  // whitelist strips unknown keys, forbidNonWhitelisted rejects them loudly.
  // Worth the strictness once third-party feeds start POSTing payments.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
