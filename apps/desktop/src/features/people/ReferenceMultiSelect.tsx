import { useMemo, useState, type KeyboardEvent } from 'react';
import { Button, TextInput, type FieldControlProps } from '../../ui';
import styles from './people.module.css';

export interface ReferenceOption {
  value: string;
  label: string;
  detail?: string;
}

export function ReferenceMultiSelect({
  control,
  values,
  options,
  loading = false,
  error,
  allowCustom = false,
  emptyLabel = 'No catalog options are available.',
  groupLabel = 'Available options',
  onChange,
}: {
  control: FieldControlProps;
  values: string[];
  options: ReferenceOption[];
  loading?: boolean;
  error?: string;
  allowCustom?: boolean;
  emptyLabel?: string;
  groupLabel?: string;
  onChange: (values: string[]) => void;
}) {
  const [search, setSearch] = useState('');
  const [custom, setCustom] = useState('');
  const selected = useMemo(() => new Set(values), [values]);
  const filtered = useMemo(() => {
    const needle = search.trim().toLocaleLowerCase();
    return options
      .filter(
        (option) =>
          !needle || `${option.label} ${option.value} ${option.detail ?? ''}`.toLocaleLowerCase().includes(needle),
      )
      .slice(0, 100);
  }, [options, search]);
  const knownValues = new Set(options.map((option) => option.value));
  const unknown = values.filter((value) => !knownValues.has(value));

  const toggle = (value: string) => {
    if (selected.has(value)) {
      onChange(values.filter((item) => item !== value));
      return;
    }
    if (values.length < 32) onChange([...values, value]);
  };

  const addCustom = () => {
    const value = custom.trim();
    if (!/^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$/.test(value) || selected.has(value) || values.length >= 32) return;
    onChange([...values, value]);
    setCustom('');
  };

  return (
    <div className={styles.referencePicker}>
      <TextInput
        {...control}
        type="search"
        value={search}
        onChange={(event) => setSearch(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === 'Enter') event.preventDefault();
        }}
        placeholder="Search available options"
      />
      <div className={styles.referenceMeta} aria-live="polite">
        {values.length} of 32 selected
      </div>
      {error ? (
        <p className={styles.referenceNotice} role="status">
          {error} Existing selections are preserved.
        </p>
      ) : null}
      {unknown.length > 0 ? (
        <fieldset className={styles.referenceGroup}>
          <legend className={styles.referenceGroupLabel}>Saved references outside the current catalog</legend>
          <ul className={styles.referenceOptions}>
            {unknown.map((value) => (
              <li key={value}>
                <label className={styles.referenceOption} aria-label={`${value}, not in the current catalog`}>
                  <input type="checkbox" checked onChange={() => toggle(value)} />
                  <span>
                    <strong>{value}</strong>
                    <small>Not in the current catalog · preserved until removed</small>
                  </span>
                </label>
              </li>
            ))}
          </ul>
        </fieldset>
      ) : null}
      <fieldset className={styles.referenceGroup}>
        <legend className={styles.referenceGroupLabel}>{loading ? 'Loading catalog…' : groupLabel}</legend>
        {filtered.length > 0 ? (
          <ul className={styles.referenceOptions}>
            {filtered.map((option) => (
              <li key={option.value}>
                <label className={styles.referenceOption} aria-label={option.label}>
                  <input
                    type="checkbox"
                    checked={selected.has(option.value)}
                    disabled={!selected.has(option.value) && values.length >= 32}
                    onChange={() => toggle(option.value)}
                  />
                  <span>
                    <strong>{option.label}</strong>
                    <small>{option.detail ?? option.value}</small>
                  </span>
                </label>
              </li>
            ))}
          </ul>
        ) : (
          <p className={styles.referenceEmpty}>{search ? 'No options match this search.' : emptyLabel}</p>
        )}
      </fieldset>
      {allowCustom ? (
        <div className={styles.referenceCustom}>
          <TextInput
            value={custom}
            onChange={(event) => setCustom(event.target.value)}
            maxLength={128}
            pattern="[A-Za-z0-9][A-Za-z0-9._:/-]*"
            placeholder="Add one reference ID"
            aria-label="Custom capability reference"
            disabled={values.length >= 32}
            onKeyDown={(event: KeyboardEvent<HTMLInputElement>) => {
              if (event.key === 'Enter') {
                event.preventDefault();
                addCustom();
              }
            }}
          />
          <Button type="button" size="sm" disabled={!custom.trim() || values.length >= 32} onClick={addCustom}>
            Add reference
          </Button>
        </div>
      ) : null}
    </div>
  );
}
