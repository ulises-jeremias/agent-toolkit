import { useOperation, useReport } from '../../data/commands';
import { CommandReport, ConfirmAction, Panel, QueryView, useActionReceipt } from '../../ui';

/** Doctor on Operations: the report is data even when ok is false; fixes run after confirm. */
export function DoctorPanel() {
  const doctor = useReport('doctor');
  const fix = useOperation('doctorFix');
  const receipt = useActionReceipt('Doctor fixes applied');

  return (
    <Panel
      tone="notice"
      title="Doctor"
      meta="Toolkit data, profiles and tool integrations"
      actions={
        <ConfirmAction
          label="Apply fixes"
          variant="primary"
          title="Run doctor --fix?"
          description="Doctor applies its automatic fix for each failing check in the report. Read the report first; the result is filed as a receipt."
          confirmLabel="Apply fixes"
          busy={fix.isPending}
          onConfirm={() => fix.mutate(undefined, receipt)}
        />
      }
    >
      <QueryView query={doctor} loading="Running doctor" errorTitle="Doctor could not run">
        {(envelope) => <CommandReport envelope={envelope} label="Doctor report" failureLabel="Checks failing" />}
      </QueryView>
    </Panel>
  );
}
