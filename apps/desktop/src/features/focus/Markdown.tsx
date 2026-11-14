import { Fragment, memo, type ReactNode } from 'react';
import styles from './focus.module.css';

/**
 * Small, dependency-free Markdown renderer for assistant messages. It builds
 * React elements only (no HTML injection) and is tolerant of text that is
 * still streaming: an unclosed code fence renders as code.
 */

type Block =
  | { type: 'heading'; level: number; text: string }
  | { type: 'paragraph'; text: string }
  | { type: 'code'; lang: string; text: string }
  | { type: 'list'; ordered: boolean; items: string[] }
  | { type: 'quote'; text: string }
  | { type: 'table'; header: string[]; rows: string[][] }
  | { type: 'rule' };

const LIST_ITEM = /^\s{0,3}([-*+]|\d{1,3}[.)])\s+(.*)$/;
const TABLE_DIVIDER = /^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$/;

function cells(line: string): string[] {
  return line
    .trim()
    .replace(/^\||\|$/g, '')
    .split('|')
    .map((cell) => cell.trim());
}

export function parseBlocks(source: string): Block[] {
  const lines = source.replace(/\r\n?/g, '\n').split('\n');
  const blocks: Block[] = [];
  let index = 0;
  while (index < lines.length) {
    const line = lines[index] ?? '';
    if (!line.trim()) {
      index += 1;
      continue;
    }
    const fence = /^\s*(```|~~~)\s*([\w+#.-]*)/.exec(line);
    if (fence) {
      const body: string[] = [];
      index += 1;
      while (index < lines.length && !(lines[index] ?? '').trimStart().startsWith(fence[1] ?? '```')) {
        body.push(lines[index] ?? '');
        index += 1;
      }
      index += 1;
      blocks.push({ type: 'code', lang: fence[2] ?? '', text: body.join('\n') });
      continue;
    }
    const heading = /^\s{0,3}(#{1,6})\s+(.*)$/.exec(line);
    if (heading) {
      blocks.push({
        type: 'heading',
        level: heading[1]?.length ?? 1,
        text: (heading[2] ?? '').replace(/\s+#+\s*$/, ''),
      });
      index += 1;
      continue;
    }
    if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line)) {
      blocks.push({ type: 'rule' });
      index += 1;
      continue;
    }
    if (line.includes('|') && TABLE_DIVIDER.test(lines[index + 1] ?? '')) {
      const header = cells(line);
      const rows: string[][] = [];
      index += 2;
      while (index < lines.length && (lines[index] ?? '').includes('|') && (lines[index] ?? '').trim()) {
        rows.push(cells(lines[index] ?? ''));
        index += 1;
      }
      blocks.push({ type: 'table', header, rows });
      continue;
    }
    if (/^\s*>/.test(line)) {
      const body: string[] = [];
      while (index < lines.length && /^\s*>/.test(lines[index] ?? '')) {
        body.push((lines[index] ?? '').replace(/^\s*>\s?/, ''));
        index += 1;
      }
      blocks.push({ type: 'quote', text: body.join('\n') });
      continue;
    }
    const first = LIST_ITEM.exec(line);
    if (first) {
      const ordered = /\d/.test(first[1] ?? '');
      const items: string[] = [];
      while (index < lines.length) {
        const current = lines[index] ?? '';
        const match = LIST_ITEM.exec(current);
        if (match) {
          items.push(match[2] ?? '');
        } else if (current.trim() && /^\s{2,}/.test(current) && items.length > 0) {
          items[items.length - 1] += ` ${current.trim()}`;
        } else {
          break;
        }
        index += 1;
      }
      blocks.push({ type: 'list', ordered, items });
      continue;
    }
    const body: string[] = [];
    while (index < lines.length) {
      const current = lines[index] ?? '';
      if (!current.trim() || /^\s{0,3}(```|~~~|#{1,6}\s|>)/.test(current) || LIST_ITEM.test(current)) break;
      body.push(current);
      index += 1;
    }
    blocks.push({ type: 'paragraph', text: body.join('\n') });
  }
  return blocks;
}

const INLINE =
  /(`+)([^`]+?)\1|\*\*([^*]+?)\*\*|__([^_]+?)__|\*([^*\s][^*]*?)\*|\b_([^_\s][^_]*?)_\b|~~([^~]+?)~~|\[([^\]]+)\]\(([^)\s]+)\)/g;

function safeHref(href: string): string | null {
  return /^https?:\/\//i.test(href) ? href : null;
}

export function renderInline(text: string): ReactNode[] {
  const out: ReactNode[] = [];
  let cursor = 0;
  let key = 0;
  for (const match of text.matchAll(INLINE)) {
    const start = match.index ?? 0;
    if (start > cursor) out.push(text.slice(cursor, start));
    key += 1;
    if (match[2] !== undefined) out.push(<code key={key}>{match[2]}</code>);
    else if (match[3] !== undefined || match[4] !== undefined)
      out.push(<strong key={key}>{match[3] ?? match[4]}</strong>);
    else if (match[5] !== undefined || match[6] !== undefined) out.push(<em key={key}>{match[5] ?? match[6]}</em>);
    else if (match[7] !== undefined) out.push(<del key={key}>{match[7]}</del>);
    else if (match[8] !== undefined) {
      const href = safeHref(match[9] ?? '');
      out.push(
        href ? (
          <a key={key} href={href} target="_blank" rel="noreferrer">
            {match[8]}
          </a>
        ) : (
          <Fragment key={key}>{match[8]}</Fragment>
        ),
      );
    }
    cursor = start + match[0].length;
  }
  if (cursor < text.length) out.push(text.slice(cursor));
  return out;
}

function BlockView({ block }: { block: Block }) {
  switch (block.type) {
    case 'heading': {
      // Message headings never outrank the page: h1-h2 render as h3, the rest as h4.
      const Tag = block.level <= 2 ? 'h3' : 'h4';
      return <Tag>{renderInline(block.text)}</Tag>;
    }
    case 'code':
      return (
        <pre data-lang={block.lang || undefined}>
          <code>{block.text}</code>
        </pre>
      );
    case 'list': {
      const Tag = block.ordered ? 'ol' : 'ul';
      return (
        <Tag>
          {block.items.map((item, index) => (
            <li key={index}>{renderInline(item)}</li>
          ))}
        </Tag>
      );
    }
    case 'quote':
      return <blockquote>{renderInline(block.text)}</blockquote>;
    case 'table':
      return (
        <div className={styles.mdTable}>
          <table>
            <thead>
              <tr>
                {block.header.map((cell, index) => (
                  <th key={index}>{renderInline(cell)}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {block.rows.map((row, rowIndex) => (
                <tr key={rowIndex}>
                  {row.map((cell, index) => (
                    <td key={index}>{renderInline(cell)}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
    case 'rule':
      return <hr />;
    case 'paragraph':
      return <p>{renderInline(block.text)}</p>;
  }
}

export const Markdown = memo(function Markdown({ source }: { source: string }) {
  return (
    <div className={styles.markdown}>
      {parseBlocks(source).map((block, index) => (
        <BlockView key={index} block={block} />
      ))}
    </div>
  );
});
