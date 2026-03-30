import { describe, expect, it, vi, beforeEach } from 'vitest';

const controllerSpies = {
  ensureCardCreated: vi.fn().mockResolvedValue(undefined),
  onDeliver: vi.fn().mockResolvedValue(undefined),
  onToolPayload: vi.fn().mockResolvedValue(undefined),
  onToolStart: vi.fn().mockResolvedValue(undefined),
  onCompactionStart: vi.fn().mockResolvedValue(undefined),
  onCompactionEnd: vi.fn().mockResolvedValue(undefined),
  onAssistantMessageStart: vi.fn().mockResolvedValue(undefined),
  onReasoningEnd: vi.fn().mockResolvedValue(undefined),
  onReasoningStream: vi.fn().mockResolvedValue(undefined),
  onPartialReply: vi.fn().mockResolvedValue(undefined),
  onError: vi.fn().mockResolvedValue(undefined),
  onIdle: vi.fn().mockResolvedValue(undefined),
  onModelSelected: vi.fn(),
  markFullyComplete: vi.fn(),
  abortCard: vi.fn().mockResolvedValue(undefined),
  shouldSkipForUnavailable: vi.fn().mockReturnValue(false),
  terminateIfUnavailable: vi.fn().mockReturnValue(false),
};

vi.mock('openclaw/plugin-sdk/channel-runtime', () => ({
  createReplyPrefixContext: () => ({
    responsePrefix: '',
    responsePrefixContextProvider: () => null,
    onModelSelected: vi.fn(),
  }),
  createTypingCallbacks: () => ({
    onReplyStart: vi.fn().mockResolvedValue(undefined),
    onIdle: vi.fn().mockResolvedValue(undefined),
    onCleanup: vi.fn().mockResolvedValue(undefined),
  }),
}));

vi.mock('openclaw/plugin-sdk/channel-feedback', () => ({
  logTypingFailure: vi.fn(),
}));

vi.mock('../src/core/accounts', () => ({
  createAccountScopedConfig: vi.fn(),
  getLarkAccount: () => ({ accountId: 'default', config: { streaming: true, replyMode: 'streaming' } }),
}));

vi.mock('../src/core/footer-config', () => ({
  resolveFooterConfig: () => ({
    status: false,
    elapsed: false,
    tokens: false,
    cache: false,
    context: false,
    model: false,
  }),
}));

vi.mock('../src/core/lark-client', () => ({
  LarkClient: {
    runtime: {
      channel: {
        text: {
          resolveTextChunkLimit: () => 4000,
          resolveChunkMode: () => 'paragraph',
          resolveMarkdownTableMode: () => 'plain',
          convertMarkdownTables: (text: string) => text,
          chunkTextWithMode: (text: string) => (text ? [text] : []),
        },
        reply: {
          createReplyDispatcherWithTyping: (hooks: {
            deliver: unknown;
            onError: unknown;
            onIdle: unknown;
            onReplyStart?: unknown;
          }) => ({
            dispatcher: {
              deliver: hooks.deliver,
              onError: hooks.onError,
              onIdle: hooks.onIdle,
              onReplyStart: hooks.onReplyStart,
            },
            replyOptions: {},
            markDispatchIdle: vi.fn(),
          }),
          resolveHumanDelayConfig: () => null,
        },
      },
    },
  },
}));

vi.mock('../src/core/lark-logger', () => ({
  larkLogger: () => ({ debug: vi.fn(), info: vi.fn(), warn: vi.fn(), error: vi.fn() }),
}));

vi.mock('../src/card/card-error', () => ({
  isCardTableLimitError: () => false,
}));

vi.mock('../src/card/reply-mode', () => ({
  resolveReplyMode: () => 'streaming',
  expandAutoMode: ({ mode }: { mode: string }) => mode,
  shouldUseCard: () => false,
}));

vi.mock('../src/messaging/outbound/typing', () => ({
  addTypingIndicator: vi.fn().mockResolvedValue(null),
  removeTypingIndicator: vi.fn().mockResolvedValue(undefined),
}));

vi.mock('../src/messaging/outbound/send', () => ({
  sendMessageFeishu: vi.fn(),
  sendMarkdownCardFeishu: vi.fn(),
}));

vi.mock('../src/messaging/outbound/deliver', () => ({
  sendMediaLark: vi.fn(),
}));

vi.mock('../src/card/unavailable-guard', () => ({
  UnavailableGuard: class {
    shouldSkip() { return false; }
    terminate() { return false; }
    get isTerminated() { return false; }
  },
}));

vi.mock('../src/card/streaming-card-controller', () => ({
  StreamingCardController: class {
    cardMessageId = 'om_card';
    isTerminated = false;
    isAborted = false;
    ensureCardCreated = controllerSpies.ensureCardCreated;
    onDeliver = controllerSpies.onDeliver;
    onToolPayload = controllerSpies.onToolPayload;
    onToolStart = controllerSpies.onToolStart;
    onCompactionStart = controllerSpies.onCompactionStart;
    onCompactionEnd = controllerSpies.onCompactionEnd;
    onAssistantMessageStart = controllerSpies.onAssistantMessageStart;
    onReasoningEnd = controllerSpies.onReasoningEnd;
    onReasoningStream = controllerSpies.onReasoningStream;
    onPartialReply = controllerSpies.onPartialReply;
    onError = controllerSpies.onError;
    onIdle = controllerSpies.onIdle;
    onModelSelected = controllerSpies.onModelSelected;
    markFullyComplete = controllerSpies.markFullyComplete;
    abortCard = controllerSpies.abortCard;
    shouldSkipForUnavailable = controllerSpies.shouldSkipForUnavailable;
    terminateIfUnavailable = controllerSpies.terminateIfUnavailable;
  },
}));

import { createFeishuReplyDispatcher } from '../src/card/reply-dispatcher';

beforeEach(() => {
  vi.clearAllMocks();
});

describe('reply-dispatcher streaming callbacks', () => {
  it('wires streaming process callbacks into the controller', async () => {
    const result = createFeishuReplyDispatcher({
      cfg: {} as never,
      agentId: 'main',
      sessionKey: 'session-test',
      chatId: 'chat-test',
      replyToMessageId: 'om_reply',
      accountId: 'default',
      replyInThread: false,
      chatType: 'p2p',
      skipTyping: true,
    });

    const replyOptions = result.replyOptions as Record<string, (...args: unknown[]) => unknown>;

    await replyOptions.onToolStart?.({ name: 'exec', phase: 'start' });
    await replyOptions.onCompactionStart?.();
    await replyOptions.onCompactionEnd?.();
    await replyOptions.onAssistantMessageStart?.();
    await replyOptions.onReasoningEnd?.();
    replyOptions.onModelSelected?.({ provider: 'openai-codex', model: 'gpt-5.3-codex', thinkLevel: 'high' });

    expect(controllerSpies.onToolStart).toHaveBeenCalledWith({ name: 'exec', phase: 'start' });
    expect(controllerSpies.onCompactionStart).toHaveBeenCalled();
    expect(controllerSpies.onCompactionEnd).toHaveBeenCalled();
    expect(controllerSpies.onAssistantMessageStart).toHaveBeenCalled();
    expect(controllerSpies.onReasoningEnd).toHaveBeenCalled();
    expect(controllerSpies.onModelSelected).toHaveBeenCalledWith({
      provider: 'openai-codex',
      model: 'gpt-5.3-codex',
      thinkLevel: 'high',
    });
  });

  it('routes tool deliveries to tool payload handler instead of normal deliver', async () => {
    const result = createFeishuReplyDispatcher({
      cfg: {} as never,
      agentId: 'main',
      sessionKey: 'session-test',
      chatId: 'chat-test',
      replyToMessageId: 'om_reply',
      accountId: 'default',
      replyInThread: false,
      chatType: 'p2p',
      skipTyping: true,
    });

    const dispatcher = result.dispatcher as unknown as {
      deliver: (payload: Record<string, unknown>, info: { kind: string }) => Promise<void>;
    };

    await dispatcher.deliver({ text: 'tool summary' }, { kind: 'tool' });

    expect(controllerSpies.onToolPayload).toHaveBeenCalledWith({ text: 'tool summary' });
    expect(controllerSpies.onDeliver).not.toHaveBeenCalled();
  });

  it('creates the streaming card on reply start before partial events arrive', async () => {
    const result = createFeishuReplyDispatcher({
      cfg: {} as never,
      agentId: 'main',
      sessionKey: 'session-test',
      chatId: 'chat-test',
      replyToMessageId: 'om_reply',
      accountId: 'default',
      replyInThread: false,
      chatType: 'group',
      skipTyping: true,
    });

    const dispatcher = result.dispatcher as unknown as {
      onReplyStart?: () => Promise<void>;
    };

    await dispatcher.onReplyStart?.();

    expect(controllerSpies.ensureCardCreated).toHaveBeenCalledTimes(1);
  });
});
