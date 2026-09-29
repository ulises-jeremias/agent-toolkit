import { ConfirmButton, EnvelopePanel, MutationResult, useExecuteMutation, useReadApi } from '../shared';
import { Panel } from '../../components/ui';

/**
 * Insights — what happened and what evidence/usage exists?
 * Insights report, capability matrix, diff surface, and Doctor (read + fix).
 */
export default function Insights() {
  const insights = useReadApi('/api/v1/insights');
  const matrix = useReadApi('/api/v1/matrix');
  const diff = useReadApi('/api/v1/diff');
  const doctor = useReadApi('/api/v1/doctor');
  const fix = useExecuteMutation('/api/v1/doctor/fix');

  return (
    <>
      <h1>Insights</h1>
      <EnvelopePanel title="Insights report" query={insights} />
      <EnvelopePanel title="Capability matrix" query={matrix} />
      <EnvelopePanel title="Diff surface" query={diff} />
      <EnvelopePanel
        title="Doctor"
        query={doctor}
        actions={
          <ConfirmButton
            label="Run doctor --fix"
            confirmLabel="Confirm fix"
            disabled={fix.isPending}
            onConfirm={() => fix.mutate()}
          />
        }
      />
      {(fix.data || fix.error) && (
        <Panel title="Fix result">
          <MutationResult result={fix.data} error={fix.error instanceof Error ? fix.error : undefined} />
        </Panel>
      )}
    </>
  );
}
