import readline from 'node:readline';
import { spawn } from 'node:child_process';
const write = (frame) => process.stdout.write(`${JSON.stringify(frame)}\n`);
const notify = (method, params) => write({ method, params });
process.on('SIGTERM', () => {});
const grandchildFlagIndex = process.argv.indexOf('--spawn-grandchild');
if (grandchildFlagIndex >= 0) {
  const pidFile = process.argv[grandchildFlagIndex + 1];
  const mutationFile = process.argv[grandchildFlagIndex + 2];
  spawn(
    '/bin/sh',
    ['-c', 'sleep 60 & echo $! > "$1"; while :; do printf x >> "$2"; sleep 0.05; done', '--', pidFile, mutationFile],
    { stdio: 'ignore' },
  );
}
readline.createInterface({ input: process.stdin }).on('line', (line) => {
  const frame = JSON.parse(line);
  const reply = (result) => write({ id: frame.id, result });
  if (frame.method === 'initialize') {
    if (process.argv.includes('--hang-initialize')) return;
    reply({});
  }
  if (frame.method === 'thread/start' || frame.method === 'thread/resume') {
    if (frame.params.approvalsReviewer !== 'user') throw new Error('Approvals must be routed to the user');
    reply({ thread: { id: 'parent' }, model: 'test-model' });
  }
  if (frame.method === 'model/list') reply({ data: [] });
  if (frame.method === 'turn/start') {
    notify('turn/started', { threadId: 'parent', turn: { id: 'turn-1' } });
    if (process.argv.includes('--hang-turn-start')) return;
    reply({ turn: { id: 'turn-1' } });
    const text = frame.params.input[0].text;
    if (text === 'scope') {
      write({
        id: 'child-approval',
        method: 'item/commandExecution/requestApproval',
        params: { threadId: 'child', turnId: 'child-turn', itemId: 'cmd', command: 'rm file' },
      });
      write({
        id: 'stale-approval',
        method: 'item/commandExecution/requestApproval',
        params: { threadId: 'parent', turnId: 'stale-turn', itemId: 'cmd', command: 'rm file' },
      });
      notify('item/agentMessage/delta', {
        threadId: 'child',
        turnId: 'child-turn',
        itemId: 'child-message',
        delta: 'private child text',
      });
      notify('item/completed', {
        threadId: 'child',
        turnId: 'child-turn',
        item: { type: 'agentMessage', id: 'child-message', text: 'private child text' },
      });
      notify('turn/completed', { threadId: 'child', turn: { id: 'child-turn', status: 'completed' } });
      notify('turn/completed', { threadId: 'parent', turn: { id: 'stale-turn', status: 'completed' } });
      notify('item/completed', {
        threadId: 'parent',
        turnId: 'turn-1',
        item: { type: 'agentMessage', id: 'parent-message', text: 'parent text' },
      });
      notify('turn/completed', { threadId: 'parent', turn: { id: 'turn-1', status: 'completed' } });
    }
    if (text === 'usage') {
      notify('thread/tokenUsage/updated', {
        threadId: 'parent',
        turnId: 'turn-1',
        tokenUsage: {
          last: { inputTokens: 80, cachedInputTokens: 20, outputTokens: 30 },
          total: { inputTokens: 800, cachedInputTokens: 200, outputTokens: 300 },
        },
      });
      notify('turn/completed', { threadId: 'parent', turn: { id: 'turn-1', status: 'completed' } });
    }
    if (text === 'unsupported')
      write({
        id: 'question',
        method: 'item/tool/requestUserInput',
        params: { threadId: 'parent', turnId: 'turn-1', itemId: 'q', isBlocking: true, questions: [] },
      });
    if (text === 'question')
      write({
        id: 'question',
        method: 'item/tool/requestUserInput',
        params: {
          threadId: 'parent',
          turnId: 'turn-1',
          itemId: 'q',
          isBlocking: true,
          questions: [{ id: 'purpose', header: 'Purpose', question: 'Enter the private value', isSecret: true }],
        },
      });
    if (text === 'approval' || text === 'approval-limited' || text === 'approval-unsupported')
      write({
        id: 'approval',
        method: 'item/commandExecution/requestApproval',
        params: {
          threadId: 'parent',
          turnId: 'turn-1',
          itemId: 'cmd',
          kind: 'writeStdin',
          command: 'yes',
          networkApprovalContext: { host: 'example.test' },
          additionalPermissions: { network: { enabled: true } },
          availableDecisions:
            text === 'approval-limited'
              ? ['accept', 'decline']
              : text === 'approval-unsupported'
                ? ['accept', 'cancel']
                : [
                    'accept',
                    'acceptForSession',
                    'decline',
                    { acceptWithExecpolicyAmendment: { execpolicy_amendment: ['echo yes'] } },
                  ],
        },
      });
  }
  if (frame.method === 'turn/interrupt') write({ id: frame.id, error: { code: -1, message: 'interrupt failed' } });
  if (frame.id === 'question' && frame.error)
    notify('turn/completed', { threadId: 'parent', turn: { id: 'turn-1', status: 'completed' } });
  if (frame.id === 'approval' && frame.result) {
    notify('item/completed', {
      threadId: 'parent',
      turnId: 'turn-1',
      item: { type: 'agentMessage', id: 'answer', text: frame.result.decision },
    });
    notify('turn/completed', { threadId: 'parent', turn: { id: 'turn-1', status: 'completed' } });
  }
  if (frame.id === 'question' && frame.result) {
    const expected = frame.result.answers?.purpose?.answers?.[0] === 'user_note: private token';
    if (expected) {
      notify('item/completed', {
        threadId: 'parent',
        turnId: 'turn-1',
        item: { type: 'agentMessage', id: 'answer', text: 'received' },
      });
    }
    notify('turn/completed', {
      threadId: 'parent',
      turn: { id: 'turn-1', status: expected ? 'completed' : 'failed' },
    });
  }
});
