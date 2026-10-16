import { useState } from 'react';
import { fireEvent, render, screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { Field } from '../../ui';
import { ReferenceMultiSelect, type ReferenceOption } from './ReferenceMultiSelect';

const options: ReferenceOption[] = [
  { value: 'reviewer', label: 'Code reviewer', detail: 'agents/reviewer' },
  { value: 'test-plan', label: 'Test plan', detail: 'skills/quality' },
];

function Picker({ initial = [], onSelection }: { initial?: string[]; onSelection?: (values: string[]) => void }) {
  const [values, setValues] = useState(initial);
  return (
    <Field label="Skills" hint="Choose known references.">
      {(control) => (
        <ReferenceMultiSelect
          control={control}
          values={values}
          options={options}
          onChange={(next) => {
            setValues(next);
            onSelection?.(next);
          }}
        />
      )}
    </Field>
  );
}

describe('ReferenceMultiSelect', () => {
  it('filters catalog entries and updates selections without comma parsing', async () => {
    const user = userEvent.setup();
    render(<Picker />);

    expect(screen.getByRole('group', { name: 'Available options' })).toBeInTheDocument();
    await user.type(screen.getByRole('searchbox', { name: 'Skills' }), 'test');
    expect(screen.getByText('Test plan')).toBeInTheDocument();
    expect(screen.queryByText('Code reviewer')).not.toBeInTheDocument();
    await user.click(screen.getByRole('checkbox', { name: /Test plan/ }));
    expect(screen.getByText('1 of 32 selected')).toBeInTheDocument();
  });

  it('keeps unrecognized imported values visible and lets the user remove them', async () => {
    const user = userEvent.setup();
    const onSelection = vi.fn();
    render(<Picker initial={['legacy-skill']} onSelection={onSelection} />);

    const legacy = screen.getByText('Saved references outside the current catalog').parentElement;
    expect(legacy).not.toBeNull();
    expect(within(legacy!).getByText('legacy-skill')).toBeInTheDocument();
    await user.click(within(legacy!).getByRole('checkbox', { name: /legacy-skill/ }));
    expect(onSelection).toHaveBeenLastCalledWith([]);
  });

  it('accepts one validated custom reference at a time, never comma-separated input', () => {
    const onSelection = vi.fn();
    render(
      <Field label="Capabilities">
        {(control) => (
          <ReferenceMultiSelect control={control} values={[]} options={[]} allowCustom onChange={onSelection} />
        )}
      </Field>,
    );

    fireEvent.change(screen.getByRole('textbox', { name: 'Custom capability reference' }), {
      target: { value: 'filesystem-read' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'Add reference' }));
    expect(onSelection).toHaveBeenCalledWith(['filesystem-read']);
  });

  it('does not submit the containing Person form when Enter is pressed in search', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn((event: React.FormEvent) => event.preventDefault());
    render(
      <form onSubmit={onSubmit}>
        <Picker />
        <button type="submit">Save Person</button>
      </form>,
    );

    const search = screen.getByRole('searchbox', { name: 'Skills' });
    await user.type(search, 'review');
    await user.keyboard('{Enter}');

    expect(onSubmit).not.toHaveBeenCalled();
    expect(screen.getByRole('button', { name: 'Save Person' })).toBeVisible();
  });
});
