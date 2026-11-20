/**
 * Upload step helpers — pure presentation logic.
 *
 * No UI, no hook calls.
 *
 * Why reorder the checklist
 *   The mockup shows Locked → Noted → Kept. That order assumes the
 *   new contract's single atomic transaction, where all three
 *   complete together. The current contract requires two transactions:
 *   Irys upload (Kept) THEN contract register (Noted). Reordering to
 *   Locked → Kept → Noted makes the visual progression match reality.
 *
 * `UploadStep` — 5 states
 *   review   first step; file picker + price + Continue
 *   login    shown when the user has no session; "Log in" opens the
 *            login modal (which stacks on top)
 *   pay      shown when the session is OAuth; methods visible but
 *            only Wallet leads somewhere (switch to a wallet)
 *   progress the pipeline is running (or errored)
 *   kept     success confirmation
 */

import type { UploadStage } from "@hooks/vault/useUploadFlow";

export const MAX_BATCH_SIZE = 10;

export type UploadStep = "review" | "login" | "pay" | "progress" | "kept";

export type ChecklistItem = "locked" | "kept" | "noted";

export type StageProgress = {
  completed: ReadonlyArray<ChecklistItem>;
  active: ChecklistItem | null;
};

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

export type UploadErrorDictKey =
  | "space.upload.error.oauth"
  | "space.upload.error.unlock"
  | "space.upload.error.walletUnauthorized"
  | "space.upload.error.imageWorker"
  | "space.upload.error.irysInit"
  | "space.upload.error.funding"
  | "space.upload.error.irysUpload"
  | "space.upload.error.register"
  | "space.upload.error.duplicate"
  | "space.upload.error.wrongChain"
  | "space.upload.error.generic";

export function errorToDictKey(error: string | null): UploadErrorDictKey {
  switch (error) {
    case "OAUTH_CANNOT_UPLOAD":
      return "space.upload.error.oauth";
    case "UNLOCK_FAILED":
      return "space.upload.error.unlock";
    case "WALLET_UNAUTHORIZED":
      return "space.upload.error.walletUnauthorized";
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
    case "ASSET_ALREADY_IN_VAULT":
      return "space.upload.error.duplicate";
    case "WRONG_CHAIN":
      return "space.upload.error.wrongChain";
    case "WALLET_NOT_CONNECTED":
    case "PROVIDER_UNAVAILABLE":
      return "space.upload.error.oauth";
    default:
      return "space.upload.error.generic";
  }
}
