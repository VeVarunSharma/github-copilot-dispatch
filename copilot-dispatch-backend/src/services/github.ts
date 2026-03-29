import { Octokit } from 'octokit';
import { Repository, GitHubUser } from '../types/index.js';

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
