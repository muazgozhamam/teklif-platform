import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { AppModule } from './app.module';

import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { PrismaExceptionFilter } from './common/filters/prisma-exception.filter';
import { ObservabilityService } from './observability/observability.service';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  const strictRaw = String(process.env.VALIDATION_STRICT_ENABLED ?? '1').trim().toLowerCase();
  const strictEnabled = ['1', 'true', 'yes', 'on'].includes(strictRaw);

  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: strictEnabled,
    }),
  );
  app.enableCors({
    origin: true,
    credentials: true,
  });

  const obs = app.get(ObservabilityService);
  const logEnabled = ['1', 'true', 'yes', 'on'].includes(
    String(process.env.OBS_REQUEST_LOG_ENABLED ?? '0').trim().toLowerCase(),
  );

  app.use((req: Request, res: Response, next: NextFunction) => {
    const started = Date.now();
    res.on('finish', () => {
      const durationMs = Number((Date.now() - started).toFixed(3));
      const path = String(req.path || req.url || '/').split('?')[0] || '/';
      const method = String(req.method || 'GET').toUpperCase();
      const status = Number(res.statusCode || 0);
      obs.record({
        ts: Date.now(),
        method,
        path,
        status,
        durationMs,
      });
      if (logEnabled) {
        // eslint-disable-next-line no-console
        console.log(
          JSON.stringify({
            type: 'request',
            ts: new Date().toISOString(),
            method,
            path,
            status,
            durationMs,
          }),
        );
      }
    });
    next();
  });

  // Global filters
  app.useGlobalFilters(new PrismaExceptionFilter());

  // Swagger
  const config = new DocumentBuilder()
    .setTitle('Emlak API')
    .setVersion('1.0.0')
    .build();

  const doc = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, doc);

  app.enableShutdownHooks();

  const port = Number(process.env.PORT ?? 3001);
  await app.listen(process.env.PORT || 3001);

  // eslint-disable-next-line no-console
  console.log(`API http://localhost:${port}`);
  // eslint-disable-next-line no-console
  console.log(`Swagger http://localhost:${port}/docs`);
}

bootstrap().catch((e) => {
  // eslint-disable-next-line no-console
  console.error('BOOTSTRAP ERROR:', e);
  process.exit(1);
});
