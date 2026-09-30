import { useOperation, useReport } from '../../data/commands';
import { envelopeText } from '../../lib/api';
import { insightsStatusTone, parseDiffRows, parseDoctorChecks, parseInsightsTools } from '../../lib/reports';
import {
  ConfirmAction,
  EmptyState,
  Grid,
  KeyValue,
  Mono,
  PageHeader,
  Panel,
  QueryView,
  Stack,
  StatusBadge,
  Table,
  useActionReceipt,
} from '../../ui';

/**
 * Insights: what does the toolkit report about itself?
 * Doctor checks, measured usage, the capability matrix presence, and plugin
 * diff. No health score, no invented cost.
 */
export default function Insights() {
  const doctor = useReport('doctor');
  const insights = useReport('insights');
  const matrix = useReport('matrix');
  const diff = useReport('diff');
  const fix = useOperation('doctorFix');
  const fixReceipt = useActionReceipt('Doctor fixes applied');

  const doctorRows = doctor.data ? parseDoctorChecks(envelopeText(doctor.data)) : [];
  const usageRows = insights.data ? parseInsightsTools(envelopeText(insights.data)) : [];
  const diffRows = diff.data ? parseDiffRows(envelopeText(diff.data)) : [];

  return (
    <>
      <PageHeader
        eyebrow="Insights"
        title="What the toolkit reports"
        lede="Doctor checks, measured sessions, and plugin drift. Cost and health scores are omitted. Knowledge and memory are not this archive."
      />
      <Stack>
        <Panel
          tone="manila"
          title="Doctor"
          meta="Checks from doctor, not a health score"
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
            {(envelope) =>
              doctorRows.length === 0 ? (
                <EmptyState title="Doctor returned no structured checks.">
                  {envelope.ok ? 'The report had no check rows.' : envelope.message || 'Doctor reported a failure.'}
                </EmptyState>
              ) : (
                <Table>
                  <thead>
                    <tr>
                      <th scope="col">Status</th>
                      <th scope="col">Check</th>
                      <th scope="col">Category</th>
                      <th scope="col">Detail</th>
                    </tr>
                  </thead>
                  <tbody>
                    {doctorRows.map((row) => (
                      <tr key={`${row.category}:${row.name}:${row.detail}`}>
                        <td>
                          <StatusBadge tone={row.status} label={row.status} />
                        </td>
                        <th scope="row">{row.name}</th>
                        <td>{row.category}</td>
                        <td>{row.detail}</td>
                      </tr>
                    ))}
                  </tbody>
                </Table>
              )
            }
          </QueryView>
        </Panel>
        <Grid>
          <Panel title="Usage by tool" meta="Measured sessions. Cost is unknown.">
            <QueryView query={insights} loading="Reading tool usage" errorTitle="Could not read tool usage">
              {() =>
                usageRows.length === 0 ? (
                  <EmptyState title="No usage rows.">
                    Session stores were missing or the report was not a tool list. Cost is unknown.
                  </EmptyState>
                ) : (
                  <Table>
                    <thead>
                      <tr>
                        <th scope="col">Tool</th>
                        <th scope="col">Status</th>
                        <th scope="col" data-align="end">
                          Sessions
                        </th>
                        <th scope="col">Cost</th>
                      </tr>
                    </thead>
                    <tbody>
                      {usageRows.map((row) => (
                        <tr key={row.tool}>
                          <th scope="row">{row.tool}</th>
                          <td>
                            <StatusBadge tone={insightsStatusTone(row.status)} label={row.status} />
                          </td>
                          <td data-align="end">{row.sessions}</td>
                          <td>Unknown</td>
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                )
              }
            </QueryView>
          </Panel>
          <Panel title="Capability matrix" meta="Whether the research matrix exists">
            <QueryView query={matrix} loading="Loading the capability matrix" errorTitle="Could not load the matrix">
              {(envelope) => {
                const found = envelope.data['found'];
                return (
                  <KeyValue
                    items={[
                      {
                        label: 'Available',
                        value:
                          found === 'true' ? (
                            <StatusBadge tone="ok" label="yes" />
                          ) : found === 'false' ? (
                            <StatusBadge tone="idle" label="no" />
                          ) : (
                            <StatusBadge tone="idle" label="unknown" />
                          ),
                      },
                      {
                        label: 'Path',
                        value: envelope.data['path'] ?? 'Unknown',
                        mono: true,
                      },
                    ]}
                  />
                );
              }}
            </QueryView>
          </Panel>
        </Grid>
        <Panel
          title="Plugin diff"
          meta={
            diff.data?.data['changed']
              ? `${diff.data.data['changed']} changed of ${diff.data.data['entries'] ?? 'unknown'} entries`
              : 'Generated plugins compared with installed copies'
          }
        >
          <QueryView query={diff} loading="Comparing plugins" errorTitle="Could not compare plugins">
            {(envelope) =>
              diffRows.length === 0 ? (
                <EmptyState title="Plugin diff returned no rows.">
                  {envelope.data['entries']
                    ? `${envelope.data['entries']} entries; row text unknown.`
                    : envelope.message}
                </EmptyState>
              ) : (
                <Table>
                  <thead>
                    <tr>
                      <th scope="col">Product</th>
                      <th scope="col">Target</th>
                      <th scope="col">Result</th>
                    </tr>
                  </thead>
                  <tbody>
                    {diffRows.map((row) => (
                      <tr key={`${row.product}:${row.target}:${row.result}`}>
                        <th scope="row">
                          <Mono>{row.product}</Mono>
                        </th>
                        <td>
                          <Mono>{row.target}</Mono>
                        </td>
                        <td>
                          <StatusBadge tone={row.ok ? 'ok' : 'warn'} label={row.result} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </Table>
              )
            }
          </QueryView>
        </Panel>
      </Stack>
    </>
  );
}
