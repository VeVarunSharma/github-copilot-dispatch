// Dynamic import to handle environments where the SDK can't load (e.g. Node < 23.4)
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let CopilotClientClass: any = null;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
let approveAllFn: any = null;

import type { SessionEvent, SessionEventType } from '../types/index.js';

// Active SDK sessions keyed by our internal session ID
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const activeSdkSessions = new Map<string, any>();

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let client: any = null;
let sdkAvailable = false;

export async function initCopilotClient(): Promise<void> {
  try {
    const sdk = await import('@github/copilot-sdk');
    CopilotClientClass = sdk.CopilotClient;
    approveAllFn = sdk.approveAll;
    client = new CopilotClientClass();
    await client.start();
    sdkAvailable = true;
    console.log('[Copilot] Client initialized');
  } catch (error) {
    sdkAvailable = false;
    console.warn('[Copilot] SDK not available — agent sessions will return mock data.');
    console.warn('[Copilot] To enable the SDK, upgrade to Node.js 23.4+ (required for node:sqlite).');
    if (error instanceof Error) {
      console.warn(`[Copilot] Error: ${error.message}`);
    }
  }
}

export async function stopCopilotClient(): Promise<void> {
  if (client) {
    await client.stop();
    client = null;
    console.log('[Copilot] Client stopped');
  }
}

interface CreateSessionOptions {
  sessionId: string;
  model?: string;
  prompt: string;
  onEvent: (event: Omit<SessionEvent, 'index'>) => void;
  onStatusChange: (status: 'running' | 'completed' | 'failed') => void;
}

// Map SDK event types to our simplified SessionEventType
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapSdkEventType(sdkType: string): SessionEventType | null {
  switch (sdkType) {
    case 'assistant.message_delta':
    case 'assistant.streaming_delta':
      return 'message_delta';
    case 'assistant.message':
      return 'message_complete';
    case 'tool.execution_start':
      return 'tool_call';
    case 'tool.execution_complete':
      return 'tool_result';
    case 'session.error':
      return 'error';
    default:
      return null;
  }
}

// Extract displayable content from an SDK event
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function extractContent(event: any): string {
  const data = event.data as Record<string, unknown> | undefined;
  if (!data) return '';

  if (typeof data === 'string') return data;

  // assistant.message_delta / assistant.streaming_delta
  if ('deltaContent' in data && typeof data.deltaContent === 'string') return data.deltaContent;
  // assistant.message
  if ('content' in data && typeof data.content === 'string') return data.content;
  // tool.execution_start
  if ('name' in data && typeof data.name === 'string') return data.name;
  // tool.execution_complete
  if ('result' in data && typeof data.result === 'string') return data.result;
  // session.error
  if ('message' in data && typeof data.message === 'string') return data.message;

  return '';
}

// Simulate agent work when SDK is not available
async function runMockSession(options: CreateSessionOptions): Promise<void> {
  const { sessionId, prompt, onEvent, onStatusChange } = options;

  onStatusChange('running');
  onEvent({ type: 'status_change', content: 'Session started (mock mode)', timestamp: new Date().toISOString() });

  const steps = [
    { delay: 1000, type: 'tool_call' as const, content: `Analyzing: "${prompt}"` },
    { delay: 1500, type: 'message_delta' as const, content: 'Looking at the repository structure...' },
    { delay: 1000, type: 'tool_call' as const, content: 'Reading relevant files' },
    { delay: 2000, type: 'message_delta' as const, content: 'Implementing changes...' },
    { delay: 1500, type: 'message_complete' as const, content: 'Changes complete. This is a mock session — upgrade to Node.js 23.4+ to enable the real Copilot SDK.' },
  ];

  for (const step of steps) {
    await new Promise(resolve => setTimeout(resolve, step.delay));
    onEvent({ type: step.type, content: step.content, timestamp: new Date().toISOString() });
  }

  onStatusChange('completed');
  onEvent({ type: 'status_change', content: 'Session completed', timestamp: new Date().toISOString() });
  activeSdkSessions.delete(sessionId);
}

export async function createAgentSession(options: CreateSessionOptions): Promise<void> {
  if (!sdkAvailable || !client) {
    // Fall back to mock session
    return runMockSession(options);
  }

  const { sessionId, model = 'claude-sonnet-4', prompt, onEvent, onStatusChange } = options;

  try {
    const session = await client.createSession({
      model,
      onPermissionRequest: approveAllFn,
      streaming: true,
    });

    activeSdkSessions.set(sessionId, session);

    onStatusChange('running');
    onEvent({
      type: 'status_change',
      content: 'Session started',
      timestamp: new Date().toISOString(),
    });

    // Subscribe to all SDK events and relay relevant ones
    session.on((event: any) => {
      const mappedType = mapSdkEventType(event.type);

      if (mappedType) {
        onEvent({
          type: mappedType,
          content: extractContent(event),
          timestamp: event.timestamp ?? new Date().toISOString(),
        });
      }

      if (event.type === 'session.error') {
        onStatusChange('failed');
        activeSdkSessions.delete(sessionId);
      }
    });

    // session.idle signals the agent finished processing
    session.on('session.idle', () => {
      onStatusChange('completed');
      onEvent({
        type: 'status_change',
        content: 'Session completed',
        timestamp: new Date().toISOString(),
      });
      activeSdkSessions.delete(sessionId);
    });

    // Send the initial prompt (fire-and-forget; events arrive via handlers)
    await session.send({ prompt });
  } catch (error) {
    onStatusChange('failed');
    onEvent({
      type: 'error',
      content: error instanceof Error ? error.message : 'Failed to create session',
      timestamp: new Date().toISOString(),
    });
  }
}

export async function sendMessageToSession(sessionId: string, message: string): Promise<void> {
  const session = activeSdkSessions.get(sessionId);
  if (!session) {
    throw new Error(`No active SDK session found for ${sessionId}`);
  }
  await session.send({ prompt: message });
}

export async function cancelAgentSession(sessionId: string): Promise<void> {
  const session = activeSdkSessions.get(sessionId);
  if (session) {
    try {
      await session.abort();
      await session.disconnect();
    } catch {
      // Session may already be stopped
    }
    activeSdkSessions.delete(sessionId);
  }
}

export function hasActiveSession(sessionId: string): boolean {
  return activeSdkSessions.has(sessionId);
}
