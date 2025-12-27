import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';

async function main() {
  const app = await NestFactory.create(AppModule, { logger: false });
  await app.init();

  const server: any = app.getHttpServer();
  const router = server?._events?.request?._router;

  const routes: string[] = [];
  if (router?.stack) {
    for (const layer of router.stack) {
      if (layer?.route?.path) {
        const methods = Object.keys(layer.route.methods || {}).filter((m) => layer.route.methods[m]);
        routes.push(`${methods.join(',').toUpperCase()} ${layer.route.path}`);
      }
    }
  }

  routes.sort();
  for (const r of routes) console.log(r);

  await app.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
