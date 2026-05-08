import { Request, Response, NextFunction } from 'express';
import { getUserInfo } from '../services/github.js';
import { AppError } from './error.js';
import type { GitHubUser } from '../types/index.js';

// Augment Express Request
declare global {
  namespace Express {
    interface Request {
      user?: GitHubUser;
      token?: string;
    }
  }
}

// TODO: Consider caching validated tokens briefly (e.g., 5 minutes) to avoid
// hitting the GitHub API on every request. A simple Map<token, {user, expiresAt}>
// with TTL eviction would suffice for MVP+1.

export async function requireAuth(req: Request, _res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new AppError(401, 'Authorization header with Bearer token required', 'UNAUTHORIZED');
    }

    const token = authHeader.slice(7); // Remove "Bearer "

    // Validate token by fetching user info from GitHub
    const user = await getUserInfo(token);

    // Attach to request
    req.user = user;
    req.token = token;

    next();
  } catch (error) {
    if (error instanceof AppError) {
      next(error);
    } else {
      next(new AppError(401, 'Invalid or expired token', 'UNAUTHORIZED'));
    }
  }
}
