// Runs the marketplace's own update verification against a PR head, so a
// release is known to pass before the [Verify]: issue is filed.
//
// The marketplace's validate-plugin-update.mjs can't be called as-is: it
// always inspects the default branch's HEAD, and a PR head is not that yet.
// inspectListedPluginSource passes snapshotCommit through to resolveSnapshot,
// so everything below is the marketplace's code, pinned to a different commit.
//
// Exit 0 means the check completed, whatever it found; the verdict is in
// result.json. Anything else means it could not say.

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

const marketplace = resolve(required("MARKETPLACE_DIR"));
const marketplaceSha = required("MARKETPLACE_SHA");
const pluginId = required("PLUGIN_ID");
const repoUrl = required("REPO_URL");
const commitSha = required("COMMIT_SHA").toLowerCase();
const outDir = resolve(required("OUT_DIR"));
const runUrl = process.env.RUN_URL || "";

const load = (name) => import(pathToFileURL(resolve(marketplace, "scripts", name)).href);
const { CatalogCheckError, inspectListedPluginSource } = await load("build-catalog.mjs");
const {
  PluginUpdateError,
  publicPluginUpdateFailure,
  resolvePluginUpdate,
  sourceForPluginUpdate,
} = await load("plugin-update.mjs");
const {
  buildSecurityBaselineDetails,
  runSecurityBaseline,
  SecurityBaselineError,
  verifiedPublicationDisposition,
} = await load("security-baseline.mjs");
const { parseGitHubRepository } = await load("github-repository.mjs");

function safeInline(value) {
  return String(value || "")
    .replace(/[`<>\r\n]+/g, " ")
    .replaceAll("@", "@​")
    .trim()
    .slice(0, 300);
}

const short = commitSha.slice(0, 7);
const registry = JSON.parse(await readFile(resolve(marketplace, "registry.json"), "utf8"));
const repository = parseGitHubRepository(repoUrl);
const request = Object.freeze({
  pluginId,
  repository: repository.slug.toLowerCase(),
  repoUrl: `https://github.com/${repository.slug}`,
  commitSha,
});

const result = { commitSha, marketplaceSha, compatibility: null, baseline: null, disposition: null };
const sections = [];

let update;
try {
  const source = sourceForPluginUpdate(registry, request);
  const inspection = await inspectListedPluginSource({ ...source, snapshotCommit: commitSha });
  // A PR whose head is already the listed snapshot changes nothing the
  // marketplace cares about; the upstream check rejects it only to stop a
  // no-op publication.
  update = resolvePluginUpdate(registry, request, inspection, { allowCurrentCommit: true });
} catch (error) {
  // repository-unreachable is GitHub failing to answer, not the PR failing a check.
  const verdict = error instanceof PluginUpdateError
    || (error instanceof CatalogCheckError && error.code !== "repository-unreachable");
  if (!verdict) throw error;
  const reason = error instanceof PluginUpdateError
    ? publicPluginUpdateFailure(error).reason
    : `\`${safeInline(error.code)}\`: ${safeInline(error.message)}`;
  result.compatibility = "needs-fixes";
  sections.push("### Compatibility", "", `❌ ${reason}`);
}

if (update) {
  result.compatibility = "validated";
  const ids = update.pluginIds.map((id) => `\`${safeInline(id)}\``).join(", ");
  sections.push(
    "### Compatibility",
    "",
    `✅ Same plugin set as the listing: ${ids}`,
    `✅ Quattro compatibility passed at \`${short}\``,
    "",
    "### Security baseline",
    "",
  );
  try {
    const baseline = await runSecurityBaseline(request.repoUrl, commitSha, {
      requiredPaths: [...new Set(update.manifests.flatMap((manifest) => manifest.entryPoints || []))].sort(),
      listedPlugins: update.manifests.map((manifest) => ({
        pluginId: manifest.id,
        manifestPathHint: manifest.path,
      })),
    });
    const disposition = verifiedPublicationDisposition(baseline);
    if (!disposition) throw new Error("The security baseline returned no publication disposition");
    result.baseline = baseline.outcome;
    result.disposition = disposition;
    sections.push(buildSecurityBaselineDetails(baseline, { headingLevel: 4, context: "update" }));
  } catch (error) {
    if (!(error instanceof SecurityBaselineError) || error.code !== "security-baseline-scan-limit") throw error;
    const path = safeInline(error.context?.path);
    result.baseline = "scan-error";
    sections.push(
      "⚠️ **The scan could not finish within the marketplace's limits.**",
      "",
      path
        ? `It stopped at \`${path}\`. The marketplace treats this as needing fixes.`
        : "The tree is too large to scan completely. The marketplace treats this as needing fixes.",
    );
  }
}

const marketplaceRef = `[${safeInline(required("MARKETPLACE_REPO"))}@${marketplaceSha.slice(0, 7)}](https://github.com/${required("MARKETPLACE_REPO")}/tree/${marketplaceSha})`;
const comment = [
  "<!-- omacontrol-marketplace-check -->",
  "## Marketplace update check",
  "",
  `What the marketplace's update verification says about \`${short}\`, the head of this PR.`,
  "",
  ...sections,
  "",
  `<sub>Checked with ${marketplaceRef}${runUrl ? ` · [run](${runUrl})` : ""}. Not a security audit.</sub>`,
  "",
].join("\n");

await mkdir(outDir, { recursive: true });
await writeFile(resolve(outDir, "comment.md"), comment);
await writeFile(resolve(outDir, "result.json"), `${JSON.stringify(result, null, 2)}\n`);
