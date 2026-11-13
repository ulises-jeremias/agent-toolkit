import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react';
import { useFocusBridge, useFocusStore, useFocusTimeline } from '../../data/focus';
import type { FocusApprovalDecision, FocusProviderStatus, FocusThread } from '../../types/focus';
import { Button, PixelIcon } from '../../ui';
import { approvalQuestion, MODE_OPTIONS, STATUS_LABEL } from './labels';
import { Markdown } from './Markdown';
import {
  buildTimeline,
  formatDuration,
  formatTokens,
  pendingApproval,
  pendingUserInput,
  type TimelineItem,
  type TimelineTurn,
  type ToolItem,
} from './timeline';
import { ToolDetail, ToolRow } from './ToolRow';
import styles from './focus.module.css';

function TurnEnd({ item }: { item: Extract<TimelineItem, { kind: 'turn-end' }> }) {
  const parts: string[] = [];
  if (item.outcome === 'completed') parts.push(item.durationMs ? `Done in ${formatDuration(item.durationMs)}` : 'Done');
  if (item.outcome === 'interrupted') parts.push(item.detail ?? 'Stopped');
  if (item.usage && item.usage.outputTokens > 0) parts.push(`${formatTokens(item.usage.outputTokens)} tokens written`);
  if (item.outcome === 'failed') {
    return (
      <div className={styles.turnFailed} role="alert">
        <strong>This turn failed.</strong>
        <pre>{item.detail ?? 'The provider gave no reason.'}</pre>
      </div>
    );
  }
  return (
    <p className={styles.turnEnd} data-outcome={item.outcome}>
      {parts.join(', ')}
    </p>
  );
}

function Reasoning({ text, streaming }: { text: string; streaming: boolean }) {
  return (
    <details className={styles.reasoning} open={streaming}>
      <summary>{streaming ? 'Thinking' : 'Thought process'}</summary>
      <p>{text}</p>
    </details>
  );
}

function Item({ item }: { item: TimelineItem }) {
  switch (item.kind) {
    case 'user':
      return (
        <div className={styles.userMessage}>
          <p>{item.text}</p>
        </div>
      );
    case 'assistant':
      return (
        <div className={styles.assistantMessage} data-streaming={item.streaming || undefined}>
          <Markdown source={item.text} />
        </div>
      );
    case 'reasoning':
      return <Reasoning text={item.text} streaming={item.streaming} />;
    case 'tool':
      return <ToolRow item={item} />;
    case 'notice':
      return (
        <p className={styles.notice} data-level={item.level} role={item.level === 'error' ? 'alert' : undefined}>
          {item.text}
        </p>
      );
    case 'user-input':
      return (
        <div className={styles.userInputRecord}>
          <strong>
            {item.pending
              ? 'Codex is waiting for your answer'
              : item.resolvedBy === 'user'
                ? 'Input request answered'
                : 'Input request dismissed'}
          </strong>
          {!item.pending
            ? item.questions.map((question) => (
                <p key={question.id}>
                  {question.header}: {question.question}
                </p>
              ))
            : null}
        </div>
      );
    case 'turn-end':
      return <TurnEnd item={item} />;
  }
}

function UserInputBar({
  request,
  providerLabel,
  onSubmit,
}: {
  request: Extract<TimelineItem, { kind: 'user-input' }>;
  providerLabel: string;
  onSubmit: (answers: Record<string, string[]>) => Promise<boolean>;
}) {
  const [values, setValues] = useState<Record<string, string>>({});
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);
  const answers = Object.fromEntries(
    request.questions.map((question) => {
      const selected = values[question.id] ?? '';
      const note = (notes[question.id] ?? '').trim();
      const value =
        question.options.length === 0
          ? note
            ? [`user_note: ${note}`]
            : []
          : [
              ...(selected ? [selected === '__other__' ? 'None of the above' : selected] : []),
              ...(note ? [`user_note: ${note}`] : []),
            ];
      return [question.id, value];
    }),
  );
  const ready = request.questions.every((question) =>
    question.options.length === 0
      ? Boolean(notes[question.id]?.trim())
      : Boolean(values[question.id] || notes[question.id]?.trim()),
  );
  return (
    <form
      className={`${styles.approval} ${styles.userInput}`}
      aria-label={`${providerLabel} asks a question`}
      onSubmit={(event) => {
        event.preventDefault();
        if (!ready || submitting) return;
        setSubmitting(true);
        void onSubmit(answers).then((accepted) => {
          if (!accepted) setSubmitting(false);
        });
      }}
    >
      <strong className={styles.approvalQuestion}>{providerLabel} needs your input</strong>
      {request.questions.map((question) => {
        return (
          <fieldset className={styles.userInputQuestion} key={question.id}>
            <legend>{question.header}</legend>
            <p>{question.question}</p>
            {question.options.length > 0 ? (
              <div className={styles.userInputOptions}>
                {question.options.map((option, index) => (
                  <div key={option.label}>
                    <input
                      id={`focus-option-${question.id}-${index}`}
                      type="radio"
                      aria-label={option.label}
                      aria-describedby={`focus-option-description-${question.id}-${index}`}
                      name={`focus-question-${question.id}`}
                      value={option.label}
                      checked={values[question.id] === option.label}
                      onChange={() => setValues((current) => ({ ...current, [question.id]: option.label }))}
                    />
                    <span>
                      <strong>{option.label}</strong>
                      <small id={`focus-option-description-${question.id}-${index}`}>{option.description}</small>
                    </span>
                  </div>
                ))}
                {question.isOther ? (
                  <div>
                    <input
                      id={`focus-option-${question.id}-other`}
                      type="radio"
                      aria-label="None of the above"
                      name={`focus-question-${question.id}`}
                      value="__other__"
                      checked={values[question.id] === '__other__'}
                      onChange={() => setValues((current) => ({ ...current, [question.id]: '__other__' }))}
                    />
                    <span>
                      <strong>None of the above</strong>
                      <small>Optionally add details below.</small>
                    </span>
                  </div>
                ) : null}
              </div>
            ) : null}
            <label className={styles.userInputAnswer}>
              <span>
                {question.options.length > 0
                  ? 'Notes (optional)'
                  : question.isSecret
                    ? 'Private answer'
                    : 'Your answer'}
              </span>
              <input
                type={question.isSecret ? 'password' : 'text'}
                autoComplete="off"
                onKeyDown={(event) => {
                  if (event.key === 'Enter' && event.nativeEvent.isComposing) event.preventDefault();
                }}
                value={notes[question.id] ?? ''}
                onChange={(event) => setNotes((current) => ({ ...current, [question.id]: event.target.value }))}
                required={question.options.length === 0}
              />
            </label>
          </fieldset>
        );
      })}
      <div className={styles.approvalActions}>
        <Button variant="primary" type="submit" disabled={!ready || submitting}>
          {submitting ? 'Sending…' : 'Continue'}
        </Button>
      </div>
    </form>
  );
}

function Turn({ turn }: { turn: TimelineTurn }) {
  return (
    <section className={styles.turn} aria-label={`Turn ${turn.turn}`}>
      {turn.items.map((item) => (
        <Item key={item.key} item={item} />
      ))}
    </section>
  );
}

function ApprovalBar({
  item,
  providerLabel,
  onDecide,
}: {
  item: ToolItem;
  providerLabel: string;
  onDecide: (decision: FocusApprovalDecision) => void;
}) {
  return (
    <div
      className={styles.approval}
      role="alertdialog"
      aria-label="Approval needed"
      aria-describedby="focus-approval-what"
    >
      <div className={styles.approvalText}>
        <p className={styles.approvalQuestion}>{approvalQuestion(providerLabel, item.toolKind, item.name)}</p>
        {/* A command is shown in full below; repeating its first line here adds nothing. */}
        <p id="focus-approval-what" className={item.toolKind === 'command' ? styles.srOnly : styles.approvalTitle}>
          {item.title}
        </p>
      </div>
      <ToolDetail item={{ ...item, output: '', children: [] }} />
      <div className={styles.approvalActions}>
        <Button variant="ghost" onClick={() => onDecide('deny')}>
          Don’t allow
        </Button>
        {item.approval?.canAllowForSession ? (
          <Button variant="secondary" onClick={() => onDecide('allow-session')}>
            Allow for this session
          </Button>
        ) : null}
        <Button variant="primary" onClick={() => onDecide('allow')}>
          Allow once
        </Button>
      </div>
    </div>
  );
}

export function Conversation({
  thread,
  provider,
  onError,
}: {
  thread: FocusThread;
  provider: FocusProviderStatus | undefined;
  onError: (message: string) => void;
}) {
  const bridge = useFocusBridge();
  const focusStore = useFocusStore();
  const timeline = useFocusTimeline(thread.id);
  const turns = useMemo(() => buildTimeline(timeline.events, timeline.live), [timeline.events, timeline.live]);
  const approval = pendingApproval(turns);
  const userInput = pendingUserInput(turns);
  const [draft, setDraft] = useState(() => focusStore.getDraft(thread.id));
  const scroller = useRef<HTMLDivElement>(null);
  const pinned = useRef(true);
  const composer = useRef<HTMLTextAreaElement>(null);
  const activeThreadId = useRef(thread.id);
  const running =
    thread.status === 'running' || thread.status === 'awaiting-approval' || thread.status === 'awaiting-input';
  const waitingForTurn = (running && !provider?.capabilities?.sendWhileRunning) || Boolean(approval || userInput);
  const providerLabel = provider?.label ?? 'The agent';

  // Follow new output only while the reader is already at the bottom.
  useLayoutEffect(() => {
    const element = scroller.current;
    if (element && pinned.current) element.scrollTop = element.scrollHeight;
  }, [turns]);

  useEffect(() => {
    activeThreadId.current = thread.id;
    setDraft(focusStore.getDraft(thread.id));
    pinned.current = true;
    composer.current?.focus();
  }, [focusStore, thread.id]);

  const run = useCallback(
    async (action: Promise<{ ok: true } | { ok: false; error: string }> | undefined) => {
      const result = await action;
      if (result && !result.ok) onError(result.error);
      return result?.ok === true;
    },
    [onError],
  );

  const send = async () => {
    const text = draft.trim();
    if (!text || !bridge || waitingForTurn) return;
    const threadId = thread.id;
    setDraft('');
    focusStore.setDraft(threadId, '');
    pinned.current = true;
    const sent = await run(bridge.send(threadId, text));
    if (!sent) {
      focusStore.setDraft(threadId, text);
      if (activeThreadId.current === threadId) setDraft(text);
    }
  };

  const stop = () => void run(bridge?.interrupt(thread.id));

  const onKeyDown = (event: KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key === 'Enter' && !event.shiftKey && !event.nativeEvent.isComposing) {
      event.preventDefault();
      void send();
    }
    if (event.key === 'Escape' && running) {
      event.preventDefault();
      stop();
    }
    // The conversation scrolls from the keyboard without leaving the message box.
    if (event.key === 'PageUp' || event.key === 'PageDown') {
      const element = scroller.current;
      if (!element) return;
      event.preventDefault();
      element.scrollBy({ top: (event.key === 'PageUp' ? -0.85 : 0.85) * element.clientHeight });
    }
  };

  const mode = MODE_OPTIONS.find((option) => option.id === thread.permissionMode);

  return (
    <div className={styles.conversation}>
      <div
        ref={scroller}
        className={styles.timeline}
        role="log"
        aria-label="Conversation"
        aria-live="polite"
        aria-relevant="additions"
        onScroll={(event) => {
          const element = event.currentTarget;
          pinned.current = element.scrollHeight - element.scrollTop - element.clientHeight < 48;
        }}
      >
        <div className={styles.timelineInner}>
          {!timeline.loaded ? <p className={styles.quiet}>Loading this session…</p> : null}
          {timeline.loaded && turns.length === 0 ? (
            <p className={styles.quiet}>
              Nothing here yet. Say what you want done in {thread.projectName ?? 'this folder'}.
            </p>
          ) : null}
          {turns.map((turn) => (
            <Turn key={turn.turn} turn={turn} />
          ))}
          {thread.status === 'running' && !approval ? (
            <p className={styles.working} role="status">
              <span className={styles.spinner} aria-hidden="true" />
              {providerLabel} is working
            </p>
          ) : null}
        </div>
      </div>

      {approval ? (
        <ApprovalBar
          item={approval}
          providerLabel={providerLabel}
          onDecide={(decision) =>
            void run(bridge?.respondApproval(thread.id, approval.approval?.requestId ?? '', decision))
          }
        />
      ) : null}
      {userInput ? (
        <UserInputBar
          key={userInput.requestId}
          request={userInput}
          providerLabel={providerLabel}
          onSubmit={(answers) => run(bridge?.respondUserInput(thread.id, userInput.requestId, answers))}
        />
      ) : null}

      <form
        className={styles.composer}
        onSubmit={(event) => {
          event.preventDefault();
          void send();
        }}
      >
        <label className={styles.srOnly} htmlFor="focus-composer">
          Message
        </label>
        <textarea
          id="focus-composer"
          ref={composer}
          className={styles.composerInput}
          value={draft}
          rows={Math.min(8, Math.max(2, draft.split('\n').length))}
          placeholder={
            approval
              ? 'Answer the request above to continue'
              : waitingForTurn
                ? 'Draft your next message. Send it when the agent finishes, or stop the current turn'
                : running
                  ? 'Add a note for the agent. It is delivered when the current step ends'
                  : 'Describe the next change'
          }
          disabled={Boolean(approval || userInput)}
          onChange={(event) => {
            const text = event.target.value;
            setDraft(text);
            focusStore.setDraft(thread.id, text);
          }}
          onKeyDown={onKeyDown}
        />
        <div className={styles.composerBar}>
          <p className={styles.composerMeta} title={mode?.hint}>
            <span data-status={thread.status}>{STATUS_LABEL[thread.status]}</span>
            <span>{mode?.label}</span>
            {thread.resolvedModel ? <span>{thread.resolvedModel}</span> : null}
          </p>
          <div className={styles.composerActions}>
            {running ? (
              <Button variant="secondary" onClick={stop} title="Stop the agent (Esc)">
                <PixelIcon name="stop" size={12} />
                Stop
              </Button>
            ) : null}
            <Button
              type="submit"
              variant="primary"
              disabled={!draft.trim() || Boolean(approval) || waitingForTurn}
              title="Send (Enter)"
            >
              <PixelIcon name="send" size={12} />
              Send
            </Button>
          </div>
        </div>
      </form>
    </div>
  );
}
