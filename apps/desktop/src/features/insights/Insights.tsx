import { useOperation, useReport } from '../../data/commands';
import { CommandReport, ConfirmAction, Grid, PageHeader, Panel, QueryView, Stack, useActionReceipt } from '../../ui';

/**
 * Insights: how healthy is the toolkit and what changed?
 * Doctor, usage across coding tools, the capability matrix and the diff
 * between generated plugins and their installed copies.
 */
export default function Insights() {
  const doctor = useReport('doctor');
  const insights = useReport('insights');
  const matrix = useReport('matrix');
  const diff = useReport('diff');
  const fix = useOperation('doctorFix');
  const fixReceipt = useActionReceipt('Doctor fixes applied');

  return (
    <>
      <PageHeader
        eyebrow="Insights"
        title="Health and usage"
        lede="What the toolkit reports about itself and the tools it configures."
      />
      <Stack>
        <Panel
          tone="manila"
          title="Doctor"
          meta="Engine, toolkit root, installed profiles and tool integrations"
          actions={
            <ConfirmAction
              label="Apply fixes"
              variant="primary"
              title="Run doctor --fix?"
              description="Doctor applies its automatic fix for each failing check in the report. Read the report first; the result is filed as a receipt."
              confirmLabel="Apply fixes"
              busy={fix.isPending}
              onConfirm={() => fix.mutate(undefined, fixReceipt)}
            />
          }
        >
          <QueryView query={doctor} loading="Running doctor" errorTitle="Doctor could not run">
            {(envelope) => <CommandReport envelope={envelope} label="Doctor report" failureLabel="Checks failing" />}
          </QueryView>
        </Panel>
        <Grid>
          <Panel title="Usage by tool" meta="Sessions found in each coding tool's local history">
            <QueryView query={insights} loading="Reading tool usage" errorTitle="Could not read tool usage">
              {(envelope) => <CommandReport envelope={envelope} label="Usage report" hideFields={['tool']} />}
            </QueryView>
          </Panel>
          <Panel title="Capability matrix">
            <QueryView query={matrix} loading="Loading the capability matrix" errorTitle="Could not load the matrix">
              {(envelope) => <CommandReport envelope={envelope} label="Capability matrix" hideFields={['found']} />}
            </QueryView>
          </Panel>
        </Grid>
        <Panel title="Plugin diff" meta="Generated plugins compared with the copies installed in each tool">
          <QueryView query={diff} loading="Comparing plugins" errorTitle="Could not compare plugins">
            {(envelope) => <CommandReport envelope={envelope} label="Plugin diff" failureLabel="Differences found" />}
          </QueryView>
        </Panel>
      </Stack>
    </>
  );
}
