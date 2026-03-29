import { CopilotClient, CopilotSession, approveAll } from '@github/copilot-sdk';
import type { SessionEvent as SdkSessionEvent } from '@github/copilot-sdk';
import type { SessionEvent, SessionEventType } from '../types/index.js';

// Active SDK sessions keyed by our internal session ID
const activeSdkSessions = new Map<string, CopilotSession>();

let client: CopilotClient | null = null;

export async function initCopilotClient(): Promise<void> {
  client = new CopilotClient();
  await client.start();
  console.log('[Copilot] Client initialized');
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
function extractContent(event: SdkSessionEvent): string {
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

export async function createAgentSession(options: CreateSessionOptions): Promise<void> {
  if (!client) {
    throw new Error('Copilot client not initialized');
  }

  const { sessionId, model = 'claude-sonnet-4', prompt, onEvent, onStatusChange } = options;

  try {
    const session = await client.createSession({
      model,
      onPermissionRequest: approveAll,
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
    session.on((event: SdkSessionEvent) => {
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
