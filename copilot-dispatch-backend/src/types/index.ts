import { Request } from 'express';

// Session status enum
export type SessionStatus = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';

// Session event types
export type SessionEventType =
  | 'status_change'
  | 'message_delta'
  | 'message_complete'
  | 'tool_call'
  | 'tool_result'
  | 'error'
  | 'pr_opened';

// A single event in a session timeline
export interface SessionEvent {
  index: number;
  type: SessionEventType;
  content: string;
  timestamp: string; // ISO 8601
}

// Full session object
export interface Session {
  id: string;
  userId: string;
  status: SessionStatus;
  repo: string; // "owner/repo"
  prompt: string;
  model: string;
  events: SessionEvent[];
  pullRequestUrl: string | null;
  error: string | null;
  createdAt: string; // ISO 8601
  updatedAt: string; // ISO 8601
}

// Session list item (lightweight, for GET /api/sessions)
export interface SessionSummary {
  id: string;
  status: SessionStatus;
  repo: string;
  prompt: string;
  model: string;
  eventCount: number;
  createdAt: string;
  updatedAt: string;
}

// Repository
export interface Repository {
  fullName: string;
  name: string;
  owner: string;
  description: string | null;
  language: string | null;
  updatedAt: string;
  isPrivate: boolean;
}

// User
export interface GitHubUser {
  login: string;
  name: string | null;
  avatarUrl: string;
}

// API Request types
export interface CreateSessionRequest {
  repo: string;
  prompt: string;
  model?: string;
}

export interface SendMessageRequest {
  message: string;
}

export interface PollTokenRequest {
  deviceCode: string;
}

// API Response types
export interface DeviceCodeResponse {
  userCode: string;
  verificationUri: string;
  expiresIn: number;
  interval: number;
  deviceCode: string; // sent to client so it can poll
}

export interface TokenResponse {
  accessToken: string;
  tokenType: string;
  scope: string;
}

export interface AuthPendingResponse {
  status: 'authorization_pending';
}

export interface ErrorResponse {
  error: string;
  message: string;
  statusCode: number;
}

// Express request augmentation
export interface AuthenticatedRequest extends Request {
  user?: GitHubUser;
  token?: string;
}

// ─── Pull Request Types ───

export type PRState = 'open' | 'closed' | 'merged';

export type ReviewEvent = 'APPROVE' | 'REQUEST_CHANGES' | 'COMMENT';

export type MergeMethod = 'merge' | 'squash' | 'rebase';

export type CheckConclusion = 'success' | 'failure' | 'neutral' | 'cancelled' | 'skipped' | 'timed_out' | 'action_required' | null;

export interface PRUser {
  login: string;
  avatarUrl: string;
}

export interface PullRequest {
  number: number;
  title: string;
  author: string;
  branch: string;
  baseBranch: string;
  state: PRState;
  additions: number;
  deletions: number;
  changedFiles: number;
  ciStatus: string | null; // 'success' | 'failure' | 'pending' | null
  mergeable: boolean | null;
  draft: boolean;
  assignees: PRUser[];
  reviewers: PRUser[];
  createdAt: string;
  updatedAt: string;
}

export interface PullRequestFile {
  filename: string;
  status: string; // 'added' | 'modified' | 'removed' | 'renamed'
  additions: number;
  deletions: number;
}

export interface CheckRun {
  name: string;
  status: string; // 'queued' | 'in_progress' | 'completed'
  conclusion: CheckConclusion;
}

export interface PRComment {
  id: number;
  author: string;
  authorAvatarUrl: string;
  body: string;
  createdAt: string;
}

export interface PullRequestDetail extends PullRequest {
  body: string | null;
  files: PullRequestFile[];
  checks: CheckRun[];
  comments: PRComment[];
}

// PR API request types
export interface SubmitReviewRequest {
  event: ReviewEvent;
  body?: string;
}

export interface MergePRRequest {
  mergeMethod?: MergeMethod;
}

export interface AddAssigneesRequest {
  assignees: string[];
}

export interface RequestReviewersRequest {
  reviewers: string[];
}
