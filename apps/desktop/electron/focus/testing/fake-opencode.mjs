import readline from 'node:readline';

const write = (frame) => process.stdout.write(`${JSON.stringify({ jsonrpc: '2.0', ...frame })}\n`);
const notify = (method, params) => write({ method, params });
let sessionId = 'ses_fake_focus_1';
let promptRequestId = null;

readline.createInterface({ input: process.stdin }).on('line', (line) => {
  const frame = JSON.parse(line);
  const reply = (result) => write({ id: frame.id, result });
  if (frame.method === 'initialize') {
    reply({ protocolVersion: 1, agentCapabilities: { loadSession: true, sessionCapabilities: { resume: {} } } });
  } else if (frame.method === 'session/new') {
    reply({ sessionId });
    notify('session/update', {
      sessionId,
      update: {
        sessionUpdate: 'config_option_update',
        configOptions: [{ id: 'model', category: 'model', options: [{ value: 'test/provider-model', name: 'Test' }] }],
      },
    });
  } else if (frame.method === 'session/load') {
    sessionId = frame.params.sessionId;
    reply({ sessionId });
  } else if (frame.method === 'session/set_config_option') {
    if (frame.params.configId !== 'model') throw new Error('Only model selection is accepted in this fixture');
    reply({});
  } else if (frame.method === 'session/prompt') {
    promptRequestId = frame.id;
    const text = frame.params.prompt?.[0]?.text;
    if (text === 'approval') {
      notify('session/update', {
        sessionId,
        update: {
          sessionUpdate: 'tool_call',
          toolCallId: 'tool-write-1',
          title: 'Writing a file',
          name: 'command_execution',
          kind: 'execute',
          rawInput: { command: 'touch result.txt' },
          status: 'pending',
        },
      });
      write({
        id: 'permission-1',
        method: 'session/request_permission',
        params: {
          sessionId,
          toolCall: {
            toolCallId: 'tool-write-1',
            title: 'Run touch result.txt',
            name: 'command_execution',
            kind: 'execute',
            rawInput: { command: 'touch result.txt' },
          },
          options: [
            { optionId: 'once', name: 'Allow once', kind: 'allow_once' },
            { optionId: 'reject', name: 'Reject', kind: 'reject_once' },
            { optionId: 'always', name: 'Always allow', kind: 'allow_always' },
          ],
        },
      });
    } else if (text === 'question' || text === 'secret-question') {
      write({
        id: 'question-1',
        method: 'elicitation/create',
        params: {
          sessionId,
          mode: 'form',
          message: text === 'secret-question' ? 'Enter the API key.' : 'Choose a color.',
          requestedSchema: {
            type: 'object',
            properties: {
              [text === 'secret-question' ? 'api_key' : 'color']:
                text === 'secret-question'
                  ? { type: 'string', title: 'API key', format: 'password' }
                  : {
                      type: 'string',
                      title: 'Color',
                      oneOf: [
                        { const: 'blue', title: 'Blue' },
                        { const: 'red', title: 'Red' },
                      ],
                    },
              ...(text === 'question' ? { color_custom: { type: 'string' } } : {}),
            },
            required: ['color'],
          },
        },
      });
    } else if (text === 'hold') {
      return;
    } else if (text === 'failure') {
      write({
        id: frame.id,
        error: {
          code: -32603,
          message: 'Insufficient balance. See https://provider.example/billing/work_12345678901234567890',
        },
      });
    } else {
      const response = text === 'queued one' ? 'QUEUED_ONE' : text === 'queued two' ? 'QUEUED_TWO' : 'ACP_OK';
      notify('session/update', {
        sessionId,
        update: { sessionUpdate: 'agent_message_chunk', content: { type: 'text', text: response } },
      });
      reply({ stopReason: 'end_turn', usage: { inputTokens: 3, outputTokens: 2 } });
    }
  } else if (frame.method === 'session/cancel') {
    reply({});
    if (promptRequestId !== null) {
      write({ id: promptRequestId, result: { stopReason: 'cancelled' } });
      promptRequestId = null;
    }
  } else if (frame.id === 'permission-1') {
    const accepted = frame.result?.outcome?.optionId === 'once';
    notify('session/update', {
      sessionId,
      update: {
        sessionUpdate: 'tool_call_update',
        toolCallId: 'tool-write-1',
        status: accepted ? 'completed' : 'failed',
        content: [{ type: 'content', content: { type: 'text', text: accepted ? 'Created result.txt' : 'Rejected' } }],
      },
    });
    notify('session/update', {
      sessionId,
      update: {
        sessionUpdate: 'agent_message_chunk',
        content: { type: 'text', text: accepted ? 'Allowed once.' : 'Not allowed.' },
      },
    });
    write({ id: promptRequestId, result: { stopReason: 'end_turn' } });
    promptRequestId = null;
  } else if (frame.id === 'question-1') {
    const accepted = frame.result?.action === 'accept' && frame.result.content?.color === 'blue';
    notify('session/update', {
      sessionId,
      update: {
        sessionUpdate: 'agent_message_chunk',
        content: { type: 'text', text: accepted ? 'Blue selected.' : 'Question cancelled.' },
      },
    });
    write({ id: promptRequestId, result: { stopReason: 'end_turn' } });
    promptRequestId = null;
  }
});
