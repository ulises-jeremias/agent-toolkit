import { burnDownBarPercent, burnDownPoints } from './burnDown';
import styles from './operations.module.css';

/**
 * Token burn-down for one loop (#1102): one bar per recorded run, bar
 * height is budget left after that run, the top edge is the declared
 * budget. Runs that crossed the budget render in the error tone at
 * the baseline. The run table below the chart carries the same
 * numbers in text, so the chart never stands alone.
 */
export function BurnDownChart({
  runs,
  maxTokens,
}: {
  runs: readonly { id: string; tokens: number }[];
  maxTokens: number;
}) {
  const points = burnDownPoints(runs, maxTokens);
  const last = points.at(-1);
  const summary = last
    ? `Token burn-down across ${points.length} runs against a budget of ${maxTokens.toLocaleString()}: ${last.cumulative.toLocaleString()} recorded, ${Math.max(last.left, 0).toLocaleString()} left${last.over ? ' (over budget)' : ''}.`
    : '';
  return (
    <div className={styles.burnDown} role="img" aria-label={summary}>
      <div className={styles.burnDownPlot}>
        {points.map((point) => (
          <div key={point.id} className={styles.burnDownColumn}>
            <div
              className={styles.burnDownBar}
              data-over={point.over || undefined}
              style={{ height: `${Math.max(burnDownBarPercent(point, maxTokens), point.over ? 3 : 0)}%` }}
              title={`${point.id}: spent ${point.spent.toLocaleString()}, ${point.left.toLocaleString()} left`}
            />
          </div>
        ))}
      </div>
      <p className={styles.burnDownCaption}>
        Budget {maxTokens.toLocaleString()} tokens · {last?.cumulative.toLocaleString() ?? 0} recorded across{' '}
        {points.length} runs
        {last?.over ? ' · over budget' : ''}
      </p>
    </div>
  );
}
