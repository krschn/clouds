import { Column, Entity, Index, ManyToOne, PrimaryGeneratedColumn } from 'typeorm';
import { Month } from '../../months/entities/month.entity';

@Entity('payments')
export class Payment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  label: string;

  /**
   * Integer centavos. `int` and not `bigint` on purpose: TypeORM returns
   * bigint columns as STRINGS, which breaks the first reduce() you write.
   * int tops out around 21 million pesos, which is plenty here.
   */
  @Column({ type: 'int' })
  amountCentavos: number;

  /**
   * Nullable timestamp rather than a boolean. A reconciliation feed will
   * eventually want to know *when* something cleared, and you cannot retrofit
   * that onto a bool without a migration and a guess.
   */
  @Column({ type: 'timestamptz', nullable: true })
  clearedAt: Date | null;

  /** 'manual' for now; 'gcash', 'bank-feed', etc. later. */
  @Column({ default: 'manual' })
  source: string;

  /**
   * Idempotency key for external feeds. The partial unique index is the single
   * most important line in this file: without it a replayed webhook creates a
   * duplicate bill and the user's sky silently gains clouds they do not owe.
   */
  @Index({ unique: true, where: '"externalRef" IS NOT NULL' })
  @Column({ type: 'varchar', nullable: true })
  externalRef: string | null;

  @ManyToOne(() => Month, (m) => m.payments, { onDelete: 'CASCADE' })
  month: Month;
}
