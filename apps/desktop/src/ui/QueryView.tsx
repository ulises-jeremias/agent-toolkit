import type { UseQueryResult } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { envelopeText, type CommandEnvelope } from '../lib/api';
import { ErrorState, KeyValue, LoadingState, Report, StatusBadge } from './primitives';

/** One place that turns a query into loading / error / data, so every view handles all three. */
export function QueryView<T>({
  query,
  loading,
  errorTitle,
  children,
}: {
  query: UseQueryResult<T, Error>;
  loading: string;
  errorTitle?: string;
  children: (data: T) => ReactNode;
}) {
  if (query.isPending) return <LoadingState label={loading} />;
  if (query.isError) return <ErrorState title={errorTitle} error={query.error} onRetry={() => void query.refetch()} />;
  return <>{children(query.data)}</>;
}

// Fields the V envelope repeats verbatim: the raw JSON of the whole payload.
// Fields that only repeat the route: the subcommand name and the raw payload.
const REDUNDANT_FIELDS = new Set(['JSON', '__RAW_JSON', 'json', 'raw', 'subcommand']);

export function envelopeFields(envelope: CommandEnvelope): Array<[string, string]> {
  return Object.entries(envelope.data).filter(
    ([key, value]) => !REDUNDANT_FIELDS.has(key) && value !== '' && value !== envelope.message,
  );
}

/**
 * Renders an untyped command envelope honestly: its verdict, its output
 * verbatim, and any structured fields. Replaced per route as V gains typed
 * response schemas.
 */
export function CommandReport({
  envelope,
  label,
  failureLabel = 'Reported problems',
  hideFields = [],
}: {
  envelope: CommandEnvelope;
  label: string;
  failureLabel?: string;
  /** Fields the surrounding view already presents. */
  hideFields?: readonly string[];
}) {
  const fields = envelopeFields(envelope).filter(([key]) => !hideFields.includes(key));
  const message = envelopeText(envelope).trim();
  return (
    <>
      {!envelope.ok ? <StatusBadge tone="err" label={failureLabel} /> : null}
      {message === '' ? null : message.includes('\n') ? <Report text={message} label={label} /> : <p>{message}</p>}
      {fields.length > 0 ? (
        <KeyValue items={fields.map(([key, value]) => ({ label: key, value, mono: true }))} />
      ) : null}
      {message === '' && fields.length === 0 ? <p>The command returned no output.</p> : null}
    </>
  );
}
