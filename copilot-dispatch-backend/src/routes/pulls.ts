import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { AppError } from '../middleware/error.js';
import {
  listPullRequests,
  getPullRequest,
  getPRChecks,
  submitReview,
  mergePR,
  addAssignees,
  removeAssignee,
  requestReviewers,
  removeReviewer,
  listCollaborators,
} from '../services/github.js';
import type {
  SubmitReviewRequest,
  MergePRRequest,
  ReviewEvent,
  MergeMethod,
  AddAssigneesRequest,
  RequestReviewersRequest,
} from '../types/index.js';

const router = Router({ mergeParams: true });
router.use(requireAuth);

// GET / — list PRs for a repo
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const owner = req.params.owner as string;
    const repo = req.params.repo as string;
    const state = (req.query.state as string) || 'open';
    const limit = parseInt(req.query.limit as string) || 20;

    const pullRequests = await listPullRequests(req.token!, owner, repo, {
      state: state as 'open' | 'closed' | 'all',
      limit,
    });

    res.json({ pullRequests });
  } catch (error) {
    next(error);
  }
});

// GET /collaborators — list repo collaborators for user picker
router.get('/collaborators', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const owner = req.params.owner as string;
    const repo = req.params.repo as string;
    const collaborators = await listCollaborators(req.token!, owner, repo);
    res.json({ collaborators });
  } catch (error) {
    next(error);
  }
});

// GET /:number — get PR detail (files, checks, comments)
router.get('/:number', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const owner = req.params.owner as string;
    const repo = req.params.repo as string;
    const prNumber = parseInt(req.params.number as string);
    if (isNaN(prNumber)) {
      throw new AppError(400, 'Invalid PR number', 'VALIDATION_ERROR');
    }

    const pr = await getPullRequest(req.token!, owner, repo, prNumber);
    res.json(pr);
  } catch (error) {
    next(error);
  }
});

// POST /:number/review — submit a review
router.post('/:number/review', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const owner = req.params.owner as string;
    const repo = req.params.repo as string;
    const prNumber = parseInt(req.params.number as string);
    if (isNaN(prNumber)) {
      throw new AppError(400, 'Invalid PR number', 'VALIDATION_ERROR');
    }

    const { event, body } = req.body as SubmitReviewRequest;
    if (!event) {
      throw new AppError(400, 'event is required (APPROVE, REQUEST_CHANGES, or COMMENT)', 'VALIDATION_ERROR');
    }

    const validEvents: ReviewEvent[] = ['APPROVE', 'REQUEST_CHANGES', 'COMMENT'];
    if (!validEvents.includes(event)) {
      throw new AppError(400, `event must be one of: ${validEvents.join(', ')}`, 'VALIDATION_ERROR');
    }

    if (event === 'REQUEST_CHANGES' && !body) {
      throw new AppError(400, 'body is required when requesting changes', 'VALIDATION_ERROR');
    }

    await submitReview(req.token!, owner, repo, prNumber, event, body);
    res.json({ status: 'review_submitted', event });
  } catch (error) {
    next(error);
  }
});

// PUT /:number/merge — merge a PR
router.put('/:number/merge', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const owner = req.params.owner as string;
    const repo = req.params.repo as string;
    const prNumber = parseInt(req.params.number as string);
    if (isNaN(prNumber)) {
      throw new AppError(400, 'Invalid PR number', 'VALIDATION_ERROR');
    }

    const { mergeMethod } = (req.body as MergePRRequest) ?? {};
    const method: MergeMethod = mergeMethod || 'squash';

    const validMethods: MergeMethod[] = ['merge', 'squash', 'rebase'];
    if (!validMethods.includes(method)) {
      throw new AppError(400, `mergeMethod must be one of: ${validMethods.join(', ')}`, 'VALIDATION_ERROR');
    }

    const result = await mergePR(req.token!, owner, repo, prNumber, method);
    res.json({ status: 'merged', sha: result.sha });
  } catch (error) {
    if (error instanceof Error && error.message.includes('405')) {
      next(new AppError(409, 'Pull request is not mergeable', 'MERGE_CONFLICT'));
    } else {
      next(error);
    }
  }
});

// GET /:number/checks — get CI/CD check status
router.get('/:number/checks', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const owner = req.params.owner as string;
    const repo = req.params.repo as string;
    const prNumber = parseInt(req.params.number as string);
    if (isNaN(prNumber)) {
      throw new AppError(400, 'Invalid PR number', 'VALIDATION_ERROR');
    }

    const result = await getPRChecks(req.token!, owner, repo, prNumber);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

// POST /:number/assignees — add assignees
router.post('/:number/assignees', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const owner = req.params.owner as string;
    const repo = req.params.repo as string;
    const prNumber = parseInt(req.params.number as string);
    if (isNaN(prNumber)) throw new AppError(400, 'Invalid PR number', 'VALIDATION_ERROR');

    const { assignees } = req.body as AddAssigneesRequest;
    if (!assignees || !assignees.length) {
      throw new AppError(400, 'assignees array is required', 'VALIDATION_ERROR');
    }

    const updated = await addAssignees(req.token!, owner, repo, prNumber, assignees);
    res.json({ status: 'assignees_updated', assignees: updated });
  } catch (error) {
    next(error);
  }
});

// DELETE /:number/assignees/:login — remove assignee
router.delete('/:number/assignees/:login', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const owner = req.params.owner as string;
    const repo = req.params.repo as string;
    const prNumber = parseInt(req.params.number as string);
    if (isNaN(prNumber)) throw new AppError(400, 'Invalid PR number', 'VALIDATION_ERROR');
    const login = req.params.login as string;

    await removeAssignee(req.token!, owner, repo, prNumber, login);
    res.json({ status: 'assignee_removed' });
  } catch (error) {
    next(error);
  }
});

// POST /:number/reviewers — request reviewers
router.post('/:number/reviewers', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const owner = req.params.owner as string;
    const repo = req.params.repo as string;
    const prNumber = parseInt(req.params.number as string);
    if (isNaN(prNumber)) throw new AppError(400, 'Invalid PR number', 'VALIDATION_ERROR');

    const { reviewers } = req.body as RequestReviewersRequest;
    if (!reviewers || !reviewers.length) {
      throw new AppError(400, 'reviewers array is required', 'VALIDATION_ERROR');
    }

    const updated = await requestReviewers(req.token!, owner, repo, prNumber, reviewers);
    res.json({ status: 'reviewers_requested', reviewers: updated });
  } catch (error) {
    next(error);
  }
});

// DELETE /:number/reviewers/:login — remove reviewer
router.delete('/:number/reviewers/:login', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const owner = req.params.owner as string;
    const repo = req.params.repo as string;
    const prNumber = parseInt(req.params.number as string);
    if (isNaN(prNumber)) throw new AppError(400, 'Invalid PR number', 'VALIDATION_ERROR');
    const login = req.params.login as string;

    await removeReviewer(req.token!, owner, repo, prNumber, login);
    res.json({ status: 'reviewer_removed' });
  } catch (error) {
    next(error);
  }
});

export default router;
