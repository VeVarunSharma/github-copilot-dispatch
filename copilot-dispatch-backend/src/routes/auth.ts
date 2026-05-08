import { Router, Request, Response } from "express";
import { config } from "../config/index.js";

const router = Router();

// POST /device-code — initiate GitHub Device Code Flow
router.post("/device-code", async (_req: Request, res: Response) => {
  // Dev mode: return mock device code when OAuth credentials are placeholders
  if (!config.GITHUB_CLIENT_ID || config.GITHUB_CLIENT_ID === 'placeholder_client_id') {
    console.log('[Auth] Dev mode: returning mock device code');
    res.json({
      userCode: 'MOCK-1234',
      verificationUri: 'https://github.com/login/device',
      expiresIn: 900,
      interval: 5,
      deviceCode: 'mock_device_code',
    });
    return;
  }

  try {
    const response = await fetch("https://github.com/login/device/code", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        client_id: config.GITHUB_CLIENT_ID,
        scope: "repo user read:org",
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("GitHub device code error:", response.status, errorText);
      // Fall back to dev mode if GitHub rejects (e.g. Device Flow not enabled)
      if (process.env.GH_TOKEN) {
        console.log('[Auth] Device flow failed, falling back to dev mode with GH_TOKEN');
        res.json({
          userCode: 'DEV-MODE',
          verificationUri: 'https://github.com/login/device',
          expiresIn: 900,
          interval: 5,
          deviceCode: 'mock_device_code',
        });
        return;
      }
      res.status(response.status).json({ error: "Failed to request device code. Enable Device Flow in your GitHub OAuth App settings." });
      return;
    }

    const data = (await response.json()) as {
      device_code: string;
      user_code: string;
      verification_uri: string;
      expires_in: number;
      interval: number;
    };

    res.json({
      userCode: data.user_code,
      verificationUri: data.verification_uri,
      expiresIn: data.expires_in,
      interval: data.interval,
      deviceCode: data.device_code,
    });
  } catch (error) {
    console.error("Device code request failed:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// POST /poll-token — poll for access token during device flow
router.post("/poll-token", async (req: Request, res: Response) => {
  const { deviceCode } = req.body as { deviceCode?: string; device_code?: string };
  const code = deviceCode || (req.body as { device_code?: string }).device_code;

  if (!code) {
    res.status(400).json({ error: "deviceCode is required" });
    return;
  }

  // Dev mode: auto-approve with mock device code
  if (code === 'mock_device_code') {
    // In dev mode, use the GH_TOKEN env var or prompt to set one
    const devToken = process.env.GH_TOKEN;
    if (devToken) {
      console.log('[Auth] Dev mode: auto-approving with GH_TOKEN');
      res.status(200).json({
        accessToken: devToken,
        tokenType: 'bearer',
        scope: 'repo,user,read:org',
      });
    } else {
      console.log('[Auth] Dev mode: no GH_TOKEN set, returning pending');
      res.status(202).json({ status: 'authorization_pending' });
    }
    return;
  }

  try {
    const response = await fetch("https://github.com/login/oauth/access_token", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        client_id: config.GITHUB_CLIENT_ID,
        device_code: code,
        grant_type: "urn:ietf:params:oauth:grant-type:device_code",
      }),
    });

    const data = (await response.json()) as {
      access_token?: string;
      token_type?: string;
      scope?: string;
      error?: string;
      error_description?: string;
    };

    if (data.access_token) {
      res.status(200).json({
        accessToken: data.access_token,
        tokenType: data.token_type,
        scope: data.scope,
      });
      return;
    }

    if (data.error === "authorization_pending" || data.error === "slow_down") {
      res.status(202).json({ status: data.error });
      return;
    }

    if (data.error === "expired_token") {
      res.status(410).json({ error: "expired_token", message: data.error_description });
      return;
    }

    res.status(400).json({ error: data.error, message: data.error_description });
  } catch (error) {
    console.error("Token polling failed:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// GET /user — fetch authenticated GitHub user profile
router.get("/user", async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing or invalid Authorization header" });
    return;
  }

  const token = authHeader.slice(7);

  try {
    const response = await fetch("https://api.github.com/user", {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github+json",
        "User-Agent": "copilot-dispatch-backend",
      },
    });

    if (!response.ok) {
      res.status(response.status).json({ error: "GitHub API request failed" });
      return;
    }

    const data = (await response.json()) as {
      login: string;
      name: string | null;
      avatar_url: string;
    };

    res.json({
      login: data.login,
      name: data.name,
      avatarUrl: data.avatar_url,
    });
  } catch (error) {
    console.error("User fetch failed:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

export default router;
