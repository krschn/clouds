export class SkyDto {
  monthId: string;
  period: string;
  outstandingCentavos: number;
  centavosPerCloud: number;
  maxClouds: number;
  /** Derived server-side too, as a reconciliation anchor. See sky.service.ts. */
  cloudCount: number;
  cloudScale: number;
}
