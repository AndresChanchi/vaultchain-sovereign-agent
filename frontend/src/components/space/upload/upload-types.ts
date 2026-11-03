/**
 * Upload step helpers — pure presentation logic.
 *
 * No UI, no hook calls. Every consumer (the three step components)
 * imports from here so the mapping stage → visible state lives in one
 * place.
 *
 * Why reorder the checklist
 *   The mockup shows Locked → Noted → Kept. That order is aspirational:
 *   it assumes the new contract's single atomic transaction, where all
 *   three complete together and the order is purely visual.
 *
 *   The current contract requires two transactions: Irys upload
 *   (Kept in many places) THEN contract register (Noted by the blind
 *   notary). Reordering the checklist to Locked → Kept → Noted makes
 *   the visual progression match the actual execution, so each item
 *   ticks exactly when its stage completes. Copy stays identical —
 *   only the order of the rows changes.
 *
 *   `funding` and `preparing` show "Waiting for approval…" between
 *   ticks because they need a wallet popup that has no visible
 *   progress state.
 */

import type { UploadStage } from "@hooks/vault/useUploadFlow";

/**
 * Cap on the number of files in a single upload batch. Matches the
 * landing hero's cap so the two entry points feel consistent.
 */
export const MAX_BATCH_SIZE = 10;

export type UploadStep = "review" | "progress" | "kept";

export type ChecklistItem = "locked" | "kept" | "noted";

/**
 * Checklist state — which rows are completed vs. which is in flight.
 *
 * Deliberately does NOT include `percent` — the numeric progress
 * needs `currentIndex` and `totalFiles`, which this helper does not
 * receive. `stageToPercent(stage, currentIndex, totalFiles)` returns
 * the numeric value; the two concerns stay separate.
 */
export type StageProgress = {
  /** Items already completed. Order = display order. */
  completed: ReadonlyArray<ChecklistItem>;
  /** Item currently in progress, or null when waiting for approval. */
  active: ChecklistItem | null;
};

/**
 * Weights per stage, summing to 100 per file. Empirically tuned:
 * uploading (Irys network) dominates, so it gets the largest share.
 */
const STAGE_WEIGHTS: Record<
  Exclude<UploadStage, "idle" | "kept" | "error">,
  number
> = {
  preparing: 2,
  hashing: 5,
  compressing: 15,
  encrypting: 12,
  funding: 10,
  uploading: 40,
  registering: 16,
};

const STAGES_IN_ORDER: ReadonlyArray<
  Exclude<UploadStage, "idle" | "kept" | "error">
> = [
  "preparing",
  "hashing",
  "compressing",
  "encrypting",
  "funding",
  "uploading",
  "registering",
];

const TOTAL_WEIGHT_PER_FILE = STAGES_IN_ORDER.reduce(
  (sum, s) => sum + STAGE_WEIGHTS[s],
  0,
);

/**
 * Convert the current stage + position into a 0-100 progress value.
 * Uses per-stage weights so the bar moves roughly in proportion to
 * how long each step actually takes.
 */
export function stageToPercent(
  stage: UploadStage,
  currentIndex: number,
  totalFiles: number,
): number {
  if (stage === "kept") return 100;
  if (stage === "idle" || stage === "error") return 0;
  if (totalFiles === 0) return 0;

  const stageIdx = STAGES_IN_ORDER.indexOf(stage);
  const completedWeight = STAGES_IN_ORDER.slice(0, Math.max(0, stageIdx))
    .reduce((sum, s) => sum + STAGE_WEIGHTS[s], 0);

  const baseFileFraction = currentIndex / totalFiles;
  const withinFileFraction = completedWeight / TOTAL_WEIGHT_PER_FILE;
  const fraction = baseFileFraction + withinFileFraction / totalFiles;

  return Math.min(100, Math.max(0, Math.round(fraction * 100)));
}

/**
 * Map the current stage to the checklist state. See "Why reorder the
 * checklist" in the file header.
 */
export function stageToChecklist(stage: UploadStage): StageProgress {
  switch (stage) {
    case "idle":
    case "error":
    case "preparing":
      return { completed: [], active: null };
    case "hashing":
    case "compressing":
    case "encrypting":
      return { completed: [], active: "locked" };
    case "funding":
      return { completed: ["locked"], active: null };
    case "uploading":
      return { completed: ["locked"], active: "kept" };
    case "registering":
      return { completed: ["locked", "kept"], active: "noted" };
    case "kept":
      return { completed: ["locked", "kept", "noted"], active: null };
  }
}

/** Which step component the parent dialog should render. */
export function stepFromStage(stage: UploadStage): UploadStep {
  if (stage === "idle") return "review";
  if (stage === "kept") return "kept";
  return "progress";
}

/**
 * Union of every dict key `errorToDictKey` can return. Typed as
 * literal union so `t(errorToDictKey(...))` gets validated against
 * `Path<Dictionary>` — an unknown key fails at build time.
 */
export type UploadErrorDictKey =
  | "space.upload.error.oauth"
  | "space.upload.error.unlock"
  | "space.upload.error.imageWorker"
  | "space.upload.error.irysInit"
  | "space.upload.error.funding"
  | "space.upload.error.irysUpload"
  | "space.upload.error.register"
  | "space.upload.error.wrongChain"
  | "space.upload.error.generic";

/**
 * Map the flow's error string (thrown as `Error.message` in
 * `useUploadFlow`) to the dict key that holds its translated copy.
 * Unknown errors fall through to `error.generic` — no crashes on
 * unhandled cases.
 */
export function errorToDictKey(error: string | null): UploadErrorDictKey {
  switch (error) {
    case "OAUTH_CANNOT_UPLOAD":
      return "space.upload.error.oauth";
    case "UNLOCK_FAILED":
      return "space.upload.error.unlock";
    case "IMAGE_WORKER_NOT_READY":
      return "space.upload.error.imageWorker";
    case "IRYS_INIT_FAILED":
      return "space.upload.error.irysInit";
    case "FUNDING_FAILED":
      return "space.upload.error.funding";
    case "IRYS_UPLOAD_FAILED":
      return "space.upload.error.irysUpload";
    case "REGISTER_FAILED":
      return "space.upload.error.register";
    case "WRONG_CHAIN":
      return "space.upload.error.wrongChain";
    case "WALLET_NOT_CONNECTED":
    case "PROVIDER_UNAVAILABLE":
      return "space.upload.error.oauth";
    default:
      return "space.upload.error.generic";
  }
}
