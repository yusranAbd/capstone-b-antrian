export function validateEnvironment(
  config: Record<string, unknown>,
): Record<string, unknown> {
  const apiPort = Number(config.API_PORT ?? 3000);

  if (!Number.isInteger(apiPort) || apiPort < 1 || apiPort > 65535) {
    throw new Error('API_PORT harus berupa angka antara 1 dan 65535');
  }

  return {
    ...config,
    API_PORT: apiPort,
  };
}
