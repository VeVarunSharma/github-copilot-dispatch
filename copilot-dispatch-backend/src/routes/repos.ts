import { Router, Request, Response, NextFunction } from 'express';
import { listUserRepos } from '../services/github.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

// All repos routes require auth
router.use(requireAuth);

// GET /api/repos — list authenticated user's repositories
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const sort = (req.query.sort as string) || 'updated';
    const limit = parseInt(req.query.limit as string) || 30;

    const repositories = await listUserRepos(req.token!, {
      sort: sort as 'updated' | 'created' | 'full_name',
      limit,
    });

    res.json({ repositories });
  } catch (error) {
    next(error);
  }
});

export default router;
