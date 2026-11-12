import readline from 'node:readline';
const write = (frame) => process.stdout.write(`${JSON.stringify(frame)}\n`);
const notify = (method, params) => write({ method, params });
process.on('SIGTERM', () => {});
readline.createInterface({ input: process.stdin }).on('line', (line) => {
  const frame = JSON.parse(line);
  const reply = (result) => write({ id: frame.id, result });
  if (frame.method === 'initialize') reply({});
  if (frame.method === 'thread/start' || frame.method === 'thread/resume') {
    if (frame.params.approvalsReviewer !== 'user') throw new Error('Approvals must be routed to the user');
    reply({ thread: { id: 'parent' }, model: 'test-model' });
  }
  if (frame.method === 'model/list') reply({ data: [] });
  if (frame.method === 'turn/start') {
    notify('turn/started', { threadId: 'parent', turn: { id: 'turn-1' } });
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
    if (text === 'unsupported')
      write({
        id: 'question',
        method: 'item/tool/requestUserInput',
        params: { threadId: 'parent', turnId: 'turn-1', itemId: 'q', questions: [] },
      });
    if (text === 'approval')
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
});
