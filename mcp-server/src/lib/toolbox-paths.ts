import { execFile } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { existsSync } from "node:fs";

const __dirname = dirname(fileURLToPath(import.meta.url));
// From src/lib/ or dist/lib/ → mcp-server/ → repo root
const TOOLBOX_ROOT = resolve(__dirname, "..", "..", "..");

export function localScript(name: string): string {
  return join(TOOLBOX_ROOT, "local", name);
}

export function systemScript(name: string): string {
  return join(TOOLBOX_ROOT, "system", name);
}

export function hasToolboxScripts(): boolean {
  return existsSync(localScript("cytrus-domain.sh"));
}

interface ExecResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

/**
 * Run a local toolbox script (from local/ directory) via bash.
 * These scripts run locally and SSH into the server themselves.
 */
export function execLocalScript(
  scriptPath: string,
  args: string[] = [],
  timeoutMs = 120_000
): Promise<ExecResult> {
  return new Promise((resolve) => {
    execFile(
      "bash",
      [scriptPath, ...args],
      { timeout: timeoutMs },
      (error, stdout, stderr) => {
        resolve({
          stdout: stdout?.toString() ?? "",
          stderr: stderr?.toString() ?? "",
          exitCode: error
            ? (typeof error.code === "number" ? error.code : 1)
            : 0,
        });
      }
    );
  });
}
