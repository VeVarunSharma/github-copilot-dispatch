import { Octokit } from 'octokit';
import {
  Repository,
  GitHubUser,
  PullRequest,
  PullRequestDetail,
  PullRequestFile,
  CheckRun,
  PRComment,
  PRUser,
  PRState,
  ReviewEvent,
  MergeMethod,
  CheckConclusion,
} from '../types/index.js';

function createOctokit(token: string): Octokit {
  return new Octokit({ auth: token });
}

export async function getUserInfo(token: string): Promise<GitHubUser> {
  const octokit = createOctokit(token);
  const { data } = await octokit.rest.users.getAuthenticated();
  return {
    login: data.login,
    name: data.name ?? null,
    avatarUrl: data.avatar_url,
  };
}

export async function listUserRepos(
  token: string,
  options: { sort?: 'updated' | 'created' | 'full_name'; limit?: number } = {}
): Promise<Repository[]> {
  const octokit = createOctokit(token);
  const { sort = 'updated', limit = 30 } = options;

  const { data } = await octokit.rest.repos.listForAuthenticatedUser({
    sort: sort === 'full_name' ? 'full_name' : sort,
    per_page: limit,
    direction: 'desc',
  });

  return data.map((repo) => ({
    fullName: repo.full_name,
    name: repo.name,
    owner: repo.owner.login,
    description: repo.description ?? null,
    language: repo.language ?? null,
    updatedAt: repo.updated_at ?? new Date().toISOString(),
    isPrivate: repo.private,
  }));
}

export async function listPullRequests(
  token: string,
  owner: string,
  repo: string,
  options: { state?: 'open' | 'closed' | 'all'; limit?: number } = {}
): Promise<PullRequest[]> {
  const octokit = createOctokit(token);
  const { state = 'open', limit = 20 } = options;

  const { data } = await octokit.rest.pulls.list({
    owner,
    repo,
    state,
    per_page: limit,
    sort: 'updated',
    direction: 'desc',
  });

  return data.map((pr) => ({
    number: pr.number,
    title: pr.title,
    author: pr.user?.login ?? 'unknown',
    branch: pr.head.ref,
    baseBranch: pr.base.ref,
    state: pr.merged_at ? 'merged' : pr.state as PRState,
    additions: (pr as Record<string, unknown>).additions as number ?? 0,
    deletions: (pr as Record<string, unknown>).deletions as number ?? 0,
    changedFiles: (pr as Record<string, unknown>).changed_files as number ?? 0,
    ciStatus: null, // fetched separately via checks endpoint
    mergeable: (pr as Record<string, unknown>).mergeable as boolean | null ?? null,
    draft: pr.draft ?? false,
    assignees: (pr.assignees ?? []).map((u) => ({ login: u.login, avatarUrl: u.avatar_url })),
    reviewers: (pr.requested_reviewers ?? [])
      .filter((r) => 'login' in r)
      .map((u) => ({ login: (u as { login: string; avatar_url: string }).login, avatarUrl: (u as { login: string; avatar_url: string }).avatar_url })),
    createdAt: pr.created_at,
    updatedAt: pr.updated_at,
  }));
}

export async function getPullRequest(
  token: string,
  owner: string,
  repo: string,
  number: number
): Promise<PullRequestDetail> {
  const octokit = createOctokit(token);

  // Fetch PR, files, checks, and comments in parallel
  const [prResponse, filesResponse, comments, checksResult] = await Promise.all([
    octokit.rest.pulls.get({ owner, repo, pull_number: number }),
    octokit.rest.pulls.listFiles({ owner, repo, pull_number: number, per_page: 100 }),
    getPRComments(token, owner, repo, number),
    getPRChecks(token, owner, repo, number),
  ]);

  const pr = prResponse.data;
  const files: PullRequestFile[] = filesResponse.data.map((f) => ({
    filename: f.filename,
    status: f.status ?? 'modified',
    additions: f.additions,
    deletions: f.deletions,
  }));

  return {
    number: pr.number,
    title: pr.title,
    author: pr.user?.login ?? 'unknown',
    branch: pr.head.ref,
    baseBranch: pr.base.ref,
    state: pr.merged_at ? 'merged' : pr.state as PRState,
    additions: pr.additions,
    deletions: pr.deletions,
    changedFiles: pr.changed_files,
    ciStatus: checksResult.state,
    mergeable: pr.mergeable,
    draft: pr.draft ?? false,
    assignees: (pr.assignees ?? []).map((u) => ({ login: u.login, avatarUrl: u.avatar_url })),
    reviewers: (pr.requested_reviewers ?? [])
      .filter((r) => 'login' in r)
      .map((u) => ({ login: (u as { login: string; avatar_url: string }).login, avatarUrl: (u as { login: string; avatar_url: string }).avatar_url })),
    body: pr.body,
    files,
    checks: checksResult.checks,
    comments,
    createdAt: pr.created_at,
    updatedAt: pr.updated_at,
  };
}

export async function getPRComments(
  token: string,
  owner: string,
  repo: string,
  number: number
): Promise<PRComment[]> {
  const octokit = createOctokit(token);
  const { data } = await octokit.rest.issues.listComments({
    owner,
    repo,
    issue_number: number,
    per_page: 50,
  });

  return data.map((c) => ({
    id: c.id,
    author: c.user?.login ?? 'unknown',
    authorAvatarUrl: c.user?.avatar_url ?? '',
    body: c.body ?? '',
    createdAt: c.created_at,
  }));
}

export async function getPRChecks(
  token: string,
  owner: string,
  repo: string,
  number: number
): Promise<{ state: string; checks: CheckRun[] }> {
  const octokit = createOctokit(token);

  // First get the PR to find the head SHA
  const { data: pr } = await octokit.rest.pulls.get({ owner, repo, pull_number: number });
  const ref = pr.head.sha;

  // Get check runs for that ref
  const { data: checkRuns } = await octokit.rest.checks.listForRef({
    owner,
    repo,
    ref,
    per_page: 100,
  });

  const checks: CheckRun[] = checkRuns.check_runs.map((cr) => ({
    name: cr.name,
    status: cr.status,
    conclusion: cr.conclusion as CheckConclusion,
  }));

  // Determine combined state
  let state = 'neutral';
  if (checks.length > 0) {
    const anyFailing = checks.some((c) => c.conclusion === 'failure');
    const anyPending = checks.some((c) => c.status !== 'completed');
    if (anyFailing) state = 'failure';
    else if (anyPending) state = 'pending';
    else state = 'success';
  }

  return { state, checks };
}

export async function submitReview(
  token: string,
  owner: string,
  repo: string,
  number: number,
  event: ReviewEvent,
  body?: string
): Promise<void> {
  const octokit = createOctokit(token);
  await octokit.rest.pulls.createReview({
    owner,
    repo,
    pull_number: number,
    event,
    body: body ?? '',
  });
}

export async function mergePR(
  token: string,
  owner: string,
  repo: string,
  number: number,
  method: MergeMethod = 'squash'
): Promise<{ sha: string }> {
  const octokit = createOctokit(token);
  const { data } = await octokit.rest.pulls.merge({
    owner,
    repo,
    pull_number: number,
    merge_method: method,
  });
  return { sha: data.sha };
}

export async function addAssignees(
  token: string,
  owner: string,
  repo: string,
  number: number,
  assignees: string[]
): Promise<PRUser[]> {
  const octokit = createOctokit(token);
  const { data } = await octokit.rest.issues.addAssignees({
    owner,
    repo,
    issue_number: number,
    assignees,
  });
  return (data.assignees ?? []).map((u) => ({
    login: u.login,
    avatarUrl: u.avatar_url,
  }));
}

export async function removeAssignee(
  token: string,
  owner: string,
  repo: string,
  number: number,
  assignee: string
): Promise<void> {
  const octokit = createOctokit(token);
  await octokit.rest.issues.removeAssignees({
    owner,
    repo,
    issue_number: number,
    assignees: [assignee],
  });
}

export async function requestReviewers(
  token: string,
  owner: string,
  repo: string,
  number: number,
  reviewers: string[]
): Promise<PRUser[]> {
  const octokit = createOctokit(token);
  const { data } = await octokit.rest.pulls.requestReviewers({
    owner,
    repo,
    pull_number: number,
    reviewers,
  });
  return (data.requested_reviewers ?? []).map((u: any) => ({
    login: u.login,
    avatarUrl: u.avatar_url,
  }));
}

export async function removeReviewer(
  token: string,
  owner: string,
  repo: string,
  number: number,
  reviewer: string
): Promise<void> {
  const octokit = createOctokit(token);
  await octokit.rest.pulls.removeRequestedReviewers({
    owner,
    repo,
    pull_number: number,
    reviewers: [reviewer],
  });
}

export async function listCollaborators(
  token: string,
  owner: string,
  repo: string
): Promise<PRUser[]> {
  const octokit = createOctokit(token);
  const { data } = await octokit.rest.repos.listCollaborators({
    owner,
    repo,
    per_page: 100,
  });
  return data.map((u) => ({
    login: u.login,
    avatarUrl: u.avatar_url,
  }));
}
