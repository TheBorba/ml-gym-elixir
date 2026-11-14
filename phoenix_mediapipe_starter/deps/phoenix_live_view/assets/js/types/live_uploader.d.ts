/**
 * Why a form submit was dropped because of its uploads:
 *
 * - `entry-errors`: upload inputs carry entries with errors
 * - `preflight-rejected`: the server rejected the entries in the preflight
 * - `preflight-failed`: the preflight push failed (error reply or timeout)
 * - `upload-failed`: an upload failed after the preflight
 * - `awaiting-preflight`: entries still need a preflight after the uploads
 * - `entries-removed`: the entries a scheduled submit waited for are gone
 *
 * @typedef {"entry-errors" | "preflight-rejected" | "preflight-failed" | "upload-failed" | "awaiting-preflight" | "entries-removed"} BlockedSubmitReason
 */
export default class LiveUploader {
    static genFileRef(file: any): any;
    static getEntryDataURL(inputEl: any, ref: any): string;
    static hasUploadsInProgress(formEl: any): boolean;
    static inputsWithUploadErrors(formEl: any): HTMLInputElement[];
    static serializeUploads(inputEl: any): {};
    static clearFiles(inputEl: any): void;
    static untrackFile(inputEl: any, file: any): void;
    /**
     * @param {HTMLInputElement} inputEl
     * @param {Array<File|Blob>} files
     * @param {DataTransfer} [dataTransfer]
     */
    static trackFiles(inputEl: HTMLInputElement, files: Array<File | Blob>, dataTransfer?: DataTransfer): void;
    static activeFileInputs(formEl: any): HTMLInputElement[];
    static activeFiles(input: any): any;
    static inputsAwaitingPreflight(formEl: any): HTMLInputElement[];
    static filesAwaitingPreflight(input: any): any;
    static markPreflightInProgress(entries: any): void;
    constructor(inputEl: any, view: any, onComplete: any);
    autoUpload: any;
    view: any;
    onComplete: any;
    _entries: UploadEntry[];
    numEntriesInProgress: number;
    isAutoUpload(): any;
    entries(): UploadEntry[];
    cancel(): void;
    initAdapterUpload(resp: any, onError: any, liveSocket: any): void;
}
/**
 * Why a form submit was dropped because of its uploads:
 *
 * - `entry-errors`: upload inputs carry entries with errors
 * - `preflight-rejected`: the server rejected the entries in the preflight
 * - `preflight-failed`: the preflight push failed (error reply or timeout)
 * - `upload-failed`: an upload failed after the preflight
 * - `awaiting-preflight`: entries still need a preflight after the uploads
 * - `entries-removed`: the entries a scheduled submit waited for are gone
 */
export type BlockedSubmitReason = "entry-errors" | "preflight-rejected" | "preflight-failed" | "upload-failed" | "awaiting-preflight" | "entries-removed";
import UploadEntry from "./upload_entry";
