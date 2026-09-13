import { readFileSync } from 'fs';
import { join } from 'path';
import { CloudRule } from './cloud-rule';

type Vector = {
  name: string;
  centavosPerCloud: number;
  maxClouds: number;
  outstandingCentavos: number;
  cloudCount: number;
  cloudScale: number;
};

const fixture = JSON.parse(
  readFileSync(join(__dirname, '../../../../shared/cloud-rule.vectors.json'), 'utf8'),
) as { minScale: number; cases: Vector[] };

describe('CloudRule (shared vectors)', () => {
  it('agrees with the Dart implementation on minScale', () => {
    expect(CloudRule.MIN_SCALE).toBe(fixture.minScale);
  });

  for (const v of fixture.cases) {
    it(v.name, () => {
      const rule = new CloudRule(v.centavosPerCloud, v.maxClouds);
      expect(rule.cloudsFor(v.outstandingCentavos)).toBe(v.cloudCount);
      expect(rule.scaleFor(v.cloudCount)).toBeCloseTo(v.cloudScale, 6);
    });
  }
});
