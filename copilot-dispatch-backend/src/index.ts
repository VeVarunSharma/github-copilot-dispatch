import express from "express";
import cors from "cors";
import helmet from "helmet";
import { config } from "./config/index.js";
import { errorHandler, requestLogger } from "./middleware/error.js";
import authRouter from "./routes/auth.js";
import reposRouter from "./routes/repos.js";
import sessionsRouter from "./routes/sessions.js";
import { initCopilotClient } from "./services/copilot.js";

const app = express();

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(requestLogger);

// Routes
app.use("/api/auth", authRouter);
app.use("/api/repos", reposRouter);
app.use("/api/sessions", sessionsRouter);

// Health check
app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", service: "copilot-dispatch" });
});

// Error handling (must be last)
app.use(errorHandler);

async function start() {
  await initCopilotClient();
  app.listen(config.PORT, () => {
    console.log(
      `🚀 Copilot Dispatch backend running on port ${config.PORT} [${config.NODE_ENV}]`
    );
  });
}

start().catch((err) => {
  console.error("Failed to start server:", err);
  process.exit(1);
});

export default app;
