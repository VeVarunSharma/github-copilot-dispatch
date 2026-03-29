import { randomUUID } from 'node:crypto';
import type { Session, SessionSummary, SessionEvent, SessionStatus, SessionEventType } from '../types/index.js';

class SessionStore {
  private sessions = new Map<string, Session>();

  create(params: {
    userId: string;
    repo: string;
    prompt: string;
    model: string;
  }): Session {
    const now = new Date().toISOString();
    const session: Session = {
      id: `sess_${randomUUID().slice(0, 8)}`,
      userId: params.userId,
      status: 'pending',
      repo: params.repo,
      prompt: params.prompt,
      model: params.model,
      events: [],
      pullRequestUrl: null,
      error: null,
      createdAt: now,
      updatedAt: now,
    };
    this.sessions.set(session.id, session);
    return session;
  }

  get(id: string): Session | undefined {
    return this.sessions.get(id);
  }

  getAll(userId: string, options?: { status?: SessionStatus; limit?: number }): SessionSummary[] {
    const { status, limit = 20 } = options ?? {};

    const results: SessionSummary[] = [];
    for (const session of this.sessions.values()) {
      if (session.userId !== userId) continue;
      if (status && session.status !== status) continue;
      results.push({
        id: session.id,
        status: session.status,
        repo: session.repo,
        prompt: session.prompt,
        model: session.model,
        eventCount: session.events.length,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
      });
    }

    // Sort by updatedAt descending
    results.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
    return results.slice(0, limit);
  }

  updateStatus(id: string, status: SessionStatus): void {
    const session = this.sessions.get(id);
    if (!session) return;
    session.status = status;
    session.updatedAt = new Date().toISOString();
    if (status === 'failed' || status === 'cancelled') {
      session.error = session.error ?? `Session ${status}`;
    }
  }

  appendEvent(id: string, event: Omit<SessionEvent, 'index'>): void {
    const session = this.sessions.get(id);
    if (!session) return;
    session.events.push({
      ...event,
      index: session.events.length,
    });
    session.updatedAt = new Date().toISOString();
  }

  getEventsSince(id: string, sinceIndex: number): SessionEvent[] {
    const session = this.sessions.get(id);
    if (!session) return [];
    return session.events.filter((e) => e.index > sinceIndex);
  }

  setPullRequestUrl(id: string, url: string): void {
    const session = this.sessions.get(id);
    if (!session) return;
    session.pullRequestUrl = url;
    session.updatedAt = new Date().toISOString();
  }

  delete(id: string): boolean {
    return this.sessions.delete(id);
  }
}

export const sessionStore = new SessionStore();
