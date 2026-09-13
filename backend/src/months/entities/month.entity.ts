import { Column, Entity, Index, OneToMany, PrimaryGeneratedColumn } from 'typeorm';
import { Payment } from '../../payments/entities/payment.entity';

@Entity('months')
export class Month {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  /** First day of the month, e.g. 2026-09-01. */
  @Index({ unique: true })
  @Column({ type: 'date' })
  period: string;

  /**
   * Frozen at creation. See suggest-denomination.ts for why this is stored
   * rather than derived.
   */
  @Column({ type: 'int', default: 100_000 })
  centavosPerCloud: number;

  @Column({ type: 'int', default: 12 })
  maxClouds: number;

  @OneToMany(() => Payment, (p) => p.month, { cascade: ['insert'] })
  payments: Payment[];
}
