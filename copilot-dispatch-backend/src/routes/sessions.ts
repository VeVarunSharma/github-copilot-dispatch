import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { AppError } from '../middleware/error.js';
import { sessionStore } from '../services/sessionStore.js';
import { createAgentSession, sendMessageToSession, cancelAgentSession } from '../services/copilot.js';
import type { CreateSessionRequest, SendMessageRequest, SessionStatus } from '../types/index.js';

const router = Router();
router.use(requireAuth);

// POST /api/sessions — create a new agent session
router.post('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { repo, prompt, model } = req.body as CreateSessionRequest;

    if (!repo || !prompt) {
      throw new AppError(400, 'repo and prompt are required', 'VALIDATION_ERROR');
    }

    const session = sessionStore.create({
      userId: req.user!.login,
      repo,
      prompt,
      model: model || 'claude-sonnet-4.5',
    });

    // Start the Copilot agent session asynchronously
    createAgentSession({
      sessionId: session.id,
      model: session.model,
      prompt,
      onEvent: (event) => {
        sessionStore.appendEvent(session.id, event);
      },
      onStatusChange: (status) => {
        sessionStore.updateStatus(session.id, status);
      },
    }).catch((error) => {
      console.error(`[Sessions] Agent session error for ${session.id}:`, error);
      sessionStore.updateStatus(session.id, 'failed');
    });

    res.status(201).json(sessionStore.get(session.id));
  } catch (error) {
    next(error);
  }
});

// GET /api/sessions — list active/recent sessions
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const status = req.query.status as SessionStatus | undefined;
    const limit = parseInt(req.query.limit as string) || 20;

    const sessions = sessionStore.getAll(req.user!.login, { status, limit });
    res.json({ sessions });
  } catch (error) {
    next(error);
  }
});

// GET /api/sessions/:id — get session detail + events
router.get('/:id', async (req: Request<{ id: string }>, res: Response, next: NextFunction) => {
  try {
    const session = sessionStore.get(req.params.id);

    if (!session) {
      throw new AppError(404, 'Session not found', 'NOT_FOUND');
    }

    if (session.userId !== req.user!.login) {
      throw new AppError(403, 'Not authorized to view this session', 'FORBIDDEN');
    }

    // Support incremental event polling with sinceEvent query param
    const sinceEvent = req.query.sinceEvent !== undefined
      ? parseInt(req.query.sinceEvent as string)
      : undefined;

    if (sinceEvent !== undefined) {
      const newEvents = sessionStore.getEventsSince(session.id, sinceEvent);
      res.json({
        ...session,
        events: newEvents,
      });
    } else {
      res.json(session);
    }
  } catch (error) {
    next(error);
  }
});

// POST /api/sessions/:id/send — send follow-up message
router.post('/:id/send', async (req: Request<{ id: string }>, res: Response, next: NextFunction) => {
  try {
    const session = sessionStore.get(req.params.id);

    if (!session) {
      throw new AppError(404, 'Session not found', 'NOT_FOUND');
    }

    if (session.userId !== req.user!.login) {
      throw new AppError(403, 'Not authorized', 'FORBIDDEN');
    }

    if (session.status !== 'running') {
      throw new AppError(400, 'Session is not running', 'SESSION_NOT_ACTIVE');
    }

    const { message } = req.body as SendMessageRequest;
    if (!message) {
      throw new AppError(400, 'message is required', 'VALIDATION_ERROR');
    }

    await sendMessageToSession(session.id, message);
    res.json({ status: 'message_sent' });
  } catch (error) {
    next(error);
  }
});

// DELETE /api/sessions/:id — cancel/stop session
router.delete('/:id', async (req: Request<{ id: string }>, res: Response, next: NextFunction) => {
  try {
    const session = sessionStore.get(req.params.id);

    if (!session) {
      throw new AppError(404, 'Session not found', 'NOT_FOUND');
    }

    if (session.userId !== req.user!.login) {
      throw new AppError(403, 'Not authorized', 'FORBIDDEN');
    }

    await cancelAgentSession(session.id);
    sessionStore.updateStatus(session.id, 'cancelled');

    res.json({ id: session.id, status: 'cancelled' });
  } catch (error) {
    next(error);
  }
});

export default router;
