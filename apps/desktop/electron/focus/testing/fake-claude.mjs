// Scripted stand-in for `claude -p --input-format stream-json` used by the
// Focus runtime tests. It speaks the same NDJSON frames the real CLI was
// measured to emit (see docs/desktop/RESCUE.md) and nothing else.
import fs from 'node:fs';
import readline from 'node:readline';

const argv = process.argv.slice(2);
const resumeIndex = argv.indexOf('--resume');
const sessionId = resumeIndex >= 0 ? argv[resumeIndex + 1] : 'sess-fake-1';
if (process.env.FAKE_CLAUDE_LOG) fs.appendFileSync(process.env.FAKE_CLAUDE_LOG, `${JSON.stringify(argv)}\n`);
if (sessionId === 'gone') {
  // The real CLI refuses a session id it no longer has, before announcing a session.
  process.stderr.write('No conversation found with session ID: gone\n');
  process.exit(1);
}

const out = (frame) => process.stdout.write(`${JSON.stringify(frame)}\n`);
const waiting = new Map();
let ticker = null;
let initialised = false;

function init() {
  if (initialised) return;
  initialised = true;
  out({ type: 'system', subtype: 'init', session_id: sessionId, model: 'fake-model-1', permissionMode: 'default' });
}

function streamText(messageId, index, text) {
  out({
    type: 'stream_event',
    api_message_id: messageId,
    parent_tool_use_id: null,
    event: { type: 'content_block_start', index, content_block: { type: 'text' } },
  });
  for (const part of text.match(/.{1,6}/gs) ?? []) {
    out({
      type: 'stream_event',
      api_message_id: messageId,
      parent_tool_use_id: null,
      event: { type: 'content_block_delta', index, delta: { type: 'text_delta', text: part } },
    });
  }
  out({ type: 'assistant', parent_tool_use_id: null, message: { id: messageId, content: [{ type: 'text', text }] } });
}

function result(extra = {}) {
  out({
    type: 'result',
    subtype: 'success',
    is_error: false,
    duration_ms: 12,
    total_cost_usd: 0.01,
    usage: { input_tokens: 10, output_tokens: 5 },
    session_id: sessionId,
    ...extra,
  });
}

function onUser(text) {
  init();
  if (text.includes('crash')) {
    process.stderr.write('fake provider exploded\n');
    process.exit(3);
  }
  if (text.includes('twice')) {
    // A queued message: the provider finishes one turn, then starts the next by itself.
    streamText('msg_first', 0, 'first answer');
    result();
    setTimeout(() => {
      streamText('msg_second', 0, 'second answer');
      setTimeout(() => result(), Number(process.env.FAKE_CLAUDE_SECOND_TURN_MS ?? 0));
    }, 40);
    return;
  }
  if (text.includes('withdraw')) {
    const input = { command: 'rm -rf build' };
    out({
      type: 'assistant',
      parent_tool_use_id: null,
      message: { id: 'msg_w', content: [{ type: 'tool_use', id: 'toolu_w', name: 'Bash', input }] },
    });
    out({
      type: 'control_request',
      request_id: 'perm_w',
      request: { subtype: 'can_use_tool', tool_name: 'Bash', input, tool_use_id: 'toolu_w' },
    });
    setTimeout(() => {
      out({ type: 'control_cancel_request', request_id: 'perm_w' });
      streamText('msg_w2', 0, 'Never mind.');
      result();
    }, 30);
    return;
  }
  if (text.includes('long')) {
    let n = 0;
    out({
      type: 'stream_event',
      api_message_id: 'msg_long',
      parent_tool_use_id: null,
      event: { type: 'content_block_start', index: 0, content_block: { type: 'text' } },
    });
    ticker = setInterval(() => {
      n += 1;
      out({
        type: 'stream_event',
        api_message_id: 'msg_long',
        parent_tool_use_id: null,
        event: { type: 'content_block_delta', index: 0, delta: { type: 'text_delta', text: `chunk${n} ` } },
      });
    }, 15);
    return;
  }
  if (text.includes('edit')) {
    streamText('msg_1', 0, 'I will fix it.');
    const input = { file_path: `${process.cwd()}/math.js`, old_string: 'a - b', new_string: 'a + b' };
    out({
      type: 'assistant',
      parent_tool_use_id: null,
      message: { id: 'msg_1', content: [{ type: 'tool_use', id: 'toolu_1', name: 'Edit', input }] },
    });
    out({
      type: 'control_request',
      request_id: 'perm_1',
      request: {
        subtype: 'can_use_tool',
        tool_name: 'Edit',
        input,
        tool_use_id: 'toolu_1',
        permission_suggestions: [
          { type: 'setMode', mode: 'acceptEdits', destination: 'session' },
          { type: 'addRules', rules: [{ toolName: 'Edit' }], behavior: 'allow', destination: 'userSettings' },
        ],
      },
    });
    waiting.set('perm_1', (response) => {
      const allowed = response.behavior === 'allow';
      out({
        type: 'user',
        message: {
          role: 'user',
          content: [
            {
              type: 'tool_result',
              tool_use_id: 'toolu_1',
              is_error: !allowed,
              content: allowed
                ? `updated${response.updatedPermissions ? ` (rules kept: ${response.updatedPermissions.map((rule) => rule.destination).join(',')})` : ''}`
                : response.message,
            },
          ],
        },
      });
      streamText('msg_2', 0, allowed ? 'Fixed.' : 'I could not make the edit.');
      result();
    });
    return;
  }
  streamText('msg_echo', 0, `echo:${text}`);
  result();
}

readline.createInterface({ input: process.stdin }).on('line', (line) => {
  let frame;
  try {
    frame = JSON.parse(line);
  } catch {
    return;
  }
  if (frame.type === 'control_request' && frame.request?.subtype === 'initialize') {
    out({
      type: 'control_response',
      response: {
        subtype: 'success',
        request_id: frame.request_id,
        response: {
          models: [
            { value: 'default', displayName: 'Default (fake)', description: 'Fake 1' },
            { value: 'small', displayName: 'Small' },
          ],
        },
      },
    });
    return;
  }
  if (frame.type === 'control_request' && frame.request?.subtype === 'interrupt') {
    if (ticker) clearInterval(ticker);
    ticker = null;
    out({
      type: 'control_response',
      response: { subtype: 'success', request_id: frame.request_id, response: { still_queued: [] } },
    });
    if (!process.env.FAKE_CLAUDE_IGNORE_INTERRUPT) result({ subtype: 'error_during_execution', is_error: true });
    return;
  }
  if (frame.type === 'control_response') {
    const resolve = waiting.get(frame.response?.request_id);
    waiting.delete(frame.response?.request_id);
    resolve?.(frame.response.response);
    return;
  }
  if (frame.type === 'user') onUser(frame.message.content.map((part) => part.text ?? '').join(''));
});
