import { Plugin } from "@opencode/plugin";

// RTK OpenCode plugin (V2) — rewrites shell commands to use rtk for token savings.
// Requires: rtk >= 0.23.0 in PATH.
//
// This is a thin delegating plugin: all rewrite logic lives in `rtk rewrite`,
// which is the single source of truth (src/discover/registry.rs).
// To add or change rewrite rules, edit the Rust registry — not this file.

/** `rtk rewrite` prints the rewritten command and exits 3; exits 1 with no output when nothing matches. */
async function rewrite(command: string): Promise<string | undefined> {
  try {
    const proc = Bun.spawn(["rtk", "rewrite", command], {
      stdin: "ignore",
      stdout: "pipe",
      stderr: "ignore",
    });
    const [stdout] = await Promise.all([
      new Response(proc.stdout).text(),
      proc.exited,
    ]);
    const rewritten = stdout.trim();
    return rewritten && rewritten !== command ? rewritten : undefined;
  } catch {
    // rtk rewrite failed — pass through unchanged
    return undefined;
  }
}

export default Plugin.define({
  id: "rtk",
  async setup(ctx) {
    if (!Bun.which("rtk")) {
      console.warn("[rtk] rtk binary not found in PATH — plugin disabled");
      return;
    }

    await ctx.shell.hook("create.before", async (event) => {
      const rewritten = await rewrite(event.command);
      if (rewritten) event.command = rewritten;
    });
  },
});
