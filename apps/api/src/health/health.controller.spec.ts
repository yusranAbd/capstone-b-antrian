import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service';
import { HealthController } from './health.controller';

describe('HealthController', () => {
  let controller: HealthController;

  const prismaMock = {
    isHealthy: jest.fn().mockResolvedValue(true),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const module: TestingModule = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        {
          provide: PrismaService,
          useValue: prismaMock,
        },
      ],
    }).compile();

    controller = module.get<HealthController>(HealthController);
  });

  it('mengembalikan status API dan database', async () => {
    const result = await controller.check();

    expect(result.status).toBe('ok');
    expect(result.service).toBe('capstone-antrean-api');
    expect(result.database).toBe('connected');
    expect(result.timestamp).toBeDefined();

    expect(prismaMock.isHealthy).toHaveBeenCalledTimes(1);
  });
});
