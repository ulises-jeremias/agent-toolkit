import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { Markdown, parseBlocks } from './Markdown';

describe('parseBlocks', () => {
  it('reads headings, lists, code fences, quotes, tables and rules', () => {
    const blocks = parseBlocks(
      ['# Title', '', 'Intro line', 'continues', '', '- one', '- two', '  wrapped', '', '1. first', '2. second', '', '```ts', 'const a = 1;', '```', '', '> quoted', '', '| a | b |', '| --- | --- |', '| 1 | 2 |', '', '---'].join('\n'),
    );
    expect(blocks.map((block) => block.type)).toEqual(['heading', 'paragraph', 'list', 'list', 'code', 'quote', 'table', 'rule']);
    expect(blocks[2]).toEqual({ type: 'list', ordered: false, items: ['one', 'two wrapped'] });
    expect(blocks[3]).toMatchObject({ ordered: true, items: ['first', 'second'] });
    expect(blocks[4]).toEqual({ type: 'code', lang: 'ts', text: 'const a = 1;' });
    expect(blocks[6]).toEqual({ type: 'table', header: ['a', 'b'], rows: [['1', '2']] });
  });

  it('treats an unclosed fence as code so streaming text does not flicker', () => {
    expect(parseBlocks('```js\nconst a =')).toEqual([{ type: 'code', lang: 'js', text: 'const a =' }]);
  });
});

describe('Markdown', () => {
  it('renders inline code, emphasis and safe links as elements', () => {
    render(<Markdown source={'Use `npm test` and **never** skip [the docs](https://example.com/docs).'} />);
    expect(screen.getByText('npm test').tagName).toBe('CODE');
    expect(screen.getByText('never').tagName).toBe('STRONG');
    const link = screen.getByRole('link', { name: 'the docs' });
    expect(link).toHaveAttribute('href', 'https://example.com/docs');
    expect(link).toHaveAttribute('rel', 'noreferrer');
  });

  it('never turns a script or file URL into a link, and never injects HTML', () => {
    const { container } = render(
      <Markdown source={'[click](javascript:alert(1)) and [file](file:///etc/passwd) <img src=x onerror=alert(1)>'} />,
    );
    expect(screen.queryByRole('link')).toBeNull();
    expect(container.querySelector('img')).toBeNull();
    expect(container.textContent).toContain('<img src=x onerror=alert(1)>');
  });

  it('keeps message headings below the page heading', () => {
    render(<Markdown source={'# Big\n\n### Small'} />);
    expect(screen.getByRole('heading', { name: 'Big' }).tagName).toBe('H3');
    expect(screen.getByRole('heading', { name: 'Small' }).tagName).toBe('H4');
  });
});
