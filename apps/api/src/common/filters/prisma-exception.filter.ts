import { ArgumentsHost, Catch, ExceptionFilter, HttpStatus } from '@nestjs/common';
import { Response } from 'express';
import { Prisma } from '@prisma/client';

@Catch()
export class PrismaExceptionFilter implements ExceptionFilter {
  catch(exception: any, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();

    // Always log full exception in dev
    // eslint-disable-next-line no-console
    console.error('🔥 EXCEPTION:', exception);

    // Prisma known errors
    if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      return res.status(HttpStatus.BAD_REQUEST).json({
        statusCode: HttpStatus.BAD_REQUEST,
        error: 'PrismaClientKnownRequestError',
        code: exception.code,
        message: exception.message,
        meta: exception.meta,
      });
    }

    if (exception instanceof Prisma.PrismaClientValidationError) {
      return res.status(HttpStatus.BAD_REQUEST).json({
        statusCode: HttpStatus.BAD_REQUEST,
        error: 'PrismaClientValidationError',
        message: exception.message,
      });
    }

    // Nest HttpExceptions already have status
    const status = exception?.getStatus?.() ?? HttpStatus.INTERNAL_SERVER_ERROR;
    const message =
      exception?.response?.message ??
      exception?.message ??
      'Internal server error';

    return res.status(status).json({
      statusCode: status,
      message,
      error: exception?.name ?? 'Error',
    });
  }
}
