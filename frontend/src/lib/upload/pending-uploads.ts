/**
 * Pending uploads — file persistence across OAuth redirect.
 *
 * The upload flow from the landing can require a login redirect
 * (OAuth) between Review and Progress. The user's `File[]` would
 * otherwise be lost the moment the page navigates to the provider.
 *
 * `sessionStorage` cannot hold `File`/`Blob` objects efficiently
 * (base64 inflation), so `localStorage` is out. **IndexedDB** stores
 * blobs natively via structured clone, survives the redirect, and
 * lives until explicitly cleared or the tab's storage is purged.
 *
 * TTL — one hour
 *   Files are ephemeral UX state, not data the user expects to keep.
 *   If the user abandons the flow (never completes login, closes the
 *   tab, walks away), one hour is generous. After that, they should
 *   pick again — the files are gone from the browser but they may
 *   still have them on disk. No surprise persistence.
 *
 *   `loadPendingUploads` checks the TTL and clears the entry when
 *   expired. Combined with `clearPendingUploads` on successful flow
 *   start, IndexedDB never holds upload files longer than one hour.
 *
 * File round-trip
 *   Browsers serialize `File` in IndexedDB but the reconstructed
 *   object may lose `File.prototype` (varies by engine). The wrapper
 *   stores `{ name, type, lastModified, blob }` and rebuilds
 *   `new File([blob], name, { type, lastModified })` on read. Works
 *   everywhere.
 *
 * Failure modes
 *   Quota exceeded, private-mode restrictions, storage disabled — all
 *   surface as `savePendingUploads` silently doing nothing or
 *   `loadPendingUploads` returning `null`. The user picks files again
 *   after login. Degradation, not breakage.
 */

const DB_NAME = "kipio-uploads";
const STORE_NAME = "pending";
const RECORD_KEY = "current";
const TTL_MS = 60 * 60 * 1000; // 1 hour

type StoredFile = {
  name: string;
  type: string;
  lastModified: number;
  blob: Blob;
};

type PendingRecord = {
  id: typeof RECORD_KEY;
  savedAt: number;
  files: StoredFile[];
};

function openDB(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => {
      if (!req.result.objectStoreNames.contains(STORE_NAME)) {
        req.result.createObjectStore(STORE_NAME, { keyPath: "id" });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function savePendingUploads(files: File[]): Promise<void> {
  if (typeof indexedDB === "undefined") return;
  if (files.length === 0) return;
  try {
    const stored: StoredFile[] = [];
    for (const f of files) {
      const buffer = await f.arrayBuffer();
      stored.push({
        name: f.name,
        type: f.type,
        lastModified: f.lastModified,
        blob: new Blob([buffer], { type: f.type }),
      });
    }
    const record: PendingRecord = {
      id: RECORD_KEY,
      savedAt: Date.now(),
      files: stored,
    };
    const db = await openDB();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readwrite");
      tx.objectStore(STORE_NAME).put(record);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  } catch {
    // Quota, private mode, disabled — the login flow will just lose
    // the files. User picks again after auth.
  }
}

export async function loadPendingUploads(): Promise<File[] | null> {
  if (typeof indexedDB === "undefined") return null;
  try {
    const db = await openDB();
    const record = await new Promise<PendingRecord | undefined>(
      (resolve, reject) => {
        const tx = db.transaction(STORE_NAME, "readonly");
        const req = tx.objectStore(STORE_NAME).get(RECORD_KEY);
        req.onsuccess = () => resolve(req.result as PendingRecord | undefined);
        req.onerror = () => reject(req.error);
      },
    );
    db.close();

    if (!record) return null;
    if (Date.now() - record.savedAt > TTL_MS) {
      await clearPendingUploads();
      return null;
    }

    return record.files.map(
      (f) =>
        new File([f.blob], f.name, {
          type: f.type,
          lastModified: f.lastModified,
        }),
    );
  } catch {
    return null;
  }
}

export async function clearPendingUploads(): Promise<void> {
  if (typeof indexedDB === "undefined") return;
  try {
    const db = await openDB();
    await new Promise<void>((resolve, reject) => {
      const tx = db.transaction(STORE_NAME, "readwrite");
      tx.objectStore(STORE_NAME).delete(RECORD_KEY);
      tx.oncomplete = () => resolve();
      tx.onerror = () => reject(tx.error);
    });
    db.close();
  } catch {
    // Ignore.
  }
}
