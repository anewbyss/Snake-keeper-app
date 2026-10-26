// Rendering and formatting helpers.

class Raw {
  constructor(html) { this.html = html; }
  toString() { return this.html; }
}

export const raw = (html) => new Raw(html);

export function esc(text) {
  return String(text).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

function render(value) {
  if (value == null || value === false) return "";
  if (value instanceof Raw) return value.html;
  if (Array.isArray(value)) return value.map(render).join("");
  return esc(value);
}

/** Template tag that escapes interpolated values (use `raw()` or nested `h` for markup). */
export function h(strings, ...values) {
  let out = strings[0];
  values.forEach((v, i) => { out += render(v) + strings[i + 1]; });
  return new Raw(out);
}

// MARK: Dates

const DAY = 86400000;

function startOfDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

export function daysBetween(start, end = new Date()) {
  return Math.round((startOfDay(end) - startOfDay(new Date(start))) / DAY);
}

export function addDays(iso, days) {
  const d = new Date(iso);
  d.setDate(d.getDate() + days);
  return d.toISOString();
}

/** "2 yr 3 mo", "5 mo", "3 wk", "4 days" — same rules as the native app. */
export function ageString(startISO, end = new Date()) {
  const start = new Date(startISO);
  let months = (end.getFullYear() - start.getFullYear()) * 12 + end.getMonth() - start.getMonth();
  if (end.getDate() < start.getDate()) months--;
  const years = Math.floor(months / 12);
  months -= years * 12;
  if (years > 0) return months > 0 ? `${years} yr ${months} mo` : `${years} yr`;
  if (months > 0) return `${months} mo`;
  const days = daysBetween(start, end);
  if (days >= 7) return `${Math.floor(days / 7)} wk`;
  return days === 1 ? "1 day" : `${Math.max(days, 0)} days`;
}

export function daysAgo(iso) {
  const days = daysBetween(iso);
  if (days === 0) return "Today";
  if (days === 1) return "Yesterday";
  if (days < 0) return `in ${-days} days`;
  return `${days} days ago`;
}

export function formatDate(iso) {
  return iso ? new Date(iso).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" }) : "";
}

export function formatTime(iso) {
  return iso ? new Date(iso).toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit", second: "2-digit" }) : "";
}

/** ISO timestamp → value for <input type="date"> (local calendar date). */
export function toDateInput(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** <input type="date"> value → ISO timestamp at local noon (safe across time zones). */
export function fromDateInput(value) {
  if (!value) return null;
  const [y, m, d] = value.split("-").map(Number);
  return new Date(y, m - 1, d, 12).toISOString();
}

export function todayInput() {
  return toDateInput(new Date().toISOString());
}

export function formatWeight(grams) {
  return grams >= 1000 ? `${(grams / 1000).toFixed(2)} kg` : `${Math.round(grams)} g`;
}

export function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(0)} KB`;
  if (bytes < 1024 ** 3) return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
  return `${(bytes / 1024 ** 3).toFixed(2)} GB`;
}

export function plural(n, word) {
  return `${n} ${word}${n === 1 ? "" : "s"}`;
}

// MARK: Sheet & toast

const sheet = () => document.getElementById("sheet");

/**
 * Opens a modal form. `onSubmit(form)` may return false to keep it open.
 * Returns the <form> so callers can wire up extra behaviour.
 */
export function openSheet({ title, body, submitLabel = "Save", onSubmit, cancelLabel = "Cancel" }) {
  const dialog = sheet();
  dialog.innerHTML = h`
    <form novalidate>
      <div class="sheet-bar">
        <button type="button" data-close>${cancelLabel}</button>
        <strong>${title}</strong>
        ${onSubmit ? h`<button type="submit">${submitLabel}</button>` : h`<span style="min-width:60px"></span>`}
      </div>
      <div class="sheet-body">${body}</div>
    </form>`.html;
  const form = dialog.querySelector("form");
  form.querySelector("[data-close]").addEventListener("click", closeSheet);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (!onSubmit) return closeSheet();
    const submit = form.querySelector('button[type="submit"]');
    submit.disabled = true;
    try {
      if ((await onSubmit(form)) !== false) closeSheet();
    } catch (error) {
      toast(error.message);
      console.error(error);
    } finally {
      submit.disabled = false;
    }
  });
  if (!dialog.open) dialog.showModal();
  dialog.querySelector(".sheet-body").scrollTop = 0;
  return form;
}

export function closeSheet() {
  const dialog = sheet();
  if (dialog.open) dialog.close();
  dialog.innerHTML = "";
}

let toastTimer;
export function toast(message) {
  const el = document.getElementById("toast");
  el.textContent = message;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("show"), 2800);
}

export function confirmAction(message) {
  return window.confirm(message);
}

// MARK: Files

/** Share sheet when the browser supports sharing files (iPad), otherwise download. */
export async function shareFiles(files) {
  if (navigator.canShare?.({ files })) {
    try {
      await navigator.share({ files });
      return;
    } catch (error) {
      if (error.name === "AbortError") return;
    }
  }
  for (const file of files) {
    const url = URL.createObjectURL(file);
    const a = Object.assign(document.createElement("a"), { href: url, download: file.name });
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 30000);
  }
}

export function pickFile(accept, { multiple = false, capture } = {}) {
  return new Promise((resolve) => {
    const input = Object.assign(document.createElement("input"), { type: "file", accept, multiple });
    if (capture) input.setAttribute("capture", capture);
    input.addEventListener("change", () => resolve([...input.files]));
    input.click();
  });
}

/** Downscaled JPEG as base64 (no data: prefix), matching the native app. */
export async function resizeImage(file, maxDimension, quality) {
  const bitmap = await createImageBitmap(file);
  const scale = Math.min(1, maxDimension / Math.max(bitmap.width, bitmap.height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(bitmap.width * scale);
  canvas.height = Math.round(bitmap.height * scale);
  canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  bitmap.close?.();
  return canvas.toDataURL("image/jpeg", quality).split(",")[1];
}
