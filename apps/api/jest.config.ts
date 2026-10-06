import type { Config } from 'jest';
import { pathsToModuleNameMapper } from 'ts-jest';
import ts from 'typescript';

// Path aliases (e.g. the ones added by `nest g library`) live in tsconfig.json,
// so read them here instead of being duplicated here.
const { config: tsconfig } = ts.readConfigFile(
  './tsconfig.json',
  ts.sys.readFile,
);

const paths = tsconfig?.compilerOptions?.paths ?? {};

const config: Config = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: '.',
  testRegex: '.*\\.spec\\.ts$',

  transform: {
    '^.+\\.(t|j)s$': 'ts-jest',
  },

  moduleNameMapper: {
    // Prisma generated client imports .js while Jest executes the .ts source.
    '^(\\.{1,2}/.*)\\.js$': '$1',

    // TypeScript path aliases.
    ...pathsToModuleNameMapper(paths, {
      prefix: '<rootDir>/',
    }),
  },

  collectCoverageFrom: [
    'src/**/*.(t|j)s',
    '!libs/**/*.(t|j)s',
    '!apps/**/*.(t|j)s',
  ],

  coverageDirectory: './coverage',
  testEnvironment: 'node',
};

export default config;
