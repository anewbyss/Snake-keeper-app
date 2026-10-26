// Port of App/Support/XLSXWriter.swift: minimal .xlsx (Excel, Google Sheets, Numbers) and CSV.
// A cell is a string, a number, a Date, or null.

const MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
const REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
const PKG_REL = "http://schemas.openxmlformats.org/package/2006/relationships";
const HEADER = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

export function xlsxBlob(sheets) {
  const files = [
    ["[Content_Types].xml", contentTypes(sheets.length)],
    ["_rels/.rels", `${HEADER}<Relationships xmlns="${PKG_REL}"><Relationship Id="rId1" Type="${REL}/officeDocument" Target="xl/workbook.xml"/></Relationships>`],
    ["xl/workbook.xml", workbook(sheets)],
    ["xl/_rels/workbook.xml.rels", workbookRels(sheets.length)],
    ["xl/styles.xml", STYLES],
    ...sheets.map((sheet, i) => [`xl/worksheets/sheet${i + 1}.xml`, worksheet(sheet)]),
  ];
  return new Blob([zip(files)], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
}

export function csv(sheet) {
  const field = (cell) => {
    const text = cell == null ? "" : cell instanceof Date ? isoDate(cell) : String(cell);
    return /[",\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
  };
  return [sheet.columns, ...sheet.rows].map((row) => row.map(field).join(",")).join("\r\n") + "\r\n";
}

function isoDate(d) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function contentTypes(count) {
  const sheets = Array.from({ length: count }, (_, i) =>
    `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join("");
  return `${HEADER}<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">`
    + '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    + '<Default Extension="xml" ContentType="application/xml"/>'
    + '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
    + '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
    + `${sheets}</Types>`;
}

function workbook(sheets) {
  const entries = sheets.map((s, i) =>
    `<sheet name="${escape(s.name.replace(/[[\]:*?/\\]/g, "").slice(0, 31))}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join("");
  return `${HEADER}<workbook xmlns="${MAIN}" xmlns:r="${REL}"><sheets>${entries}</sheets></workbook>`;
}

function workbookRels(count) {
  const sheets = Array.from({ length: count }, (_, i) =>
    `<Relationship Id="rId${i + 1}" Type="${REL}/worksheet" Target="worksheets/sheet${i + 1}.xml"/>`).join("");
  return `${HEADER}<Relationships xmlns="${PKG_REL}">${sheets}<Relationship Id="rId${count + 1}" Type="${REL}/styles" Target="styles.xml"/></Relationships>`;
}

// Style 0: normal, 1: bold header, 2: date.
const STYLES = `${HEADER}<styleSheet xmlns="${MAIN}">`
  + '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
  + '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
  + '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
  + '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
  + '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
  + '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
  + '<xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs>'
  + '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>';

function worksheet(sheet) {
  let xml = `${HEADER}<worksheet xmlns="${MAIN}">`
    + '<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>';
  if (sheet.columns.length) xml += `<cols><col min="1" max="${sheet.columns.length}" width="18" customWidth="1"/></cols>`;
  xml += "<sheetData>";
  [sheet.columns, ...sheet.rows].forEach((row, rowIndex) => {
    const r = rowIndex + 1;
    xml += `<row r="${r}">`;
    row.forEach((cell, col) => {
      const ref = `${columnName(col)}${r}`;
      const style = rowIndex === 0 ? ' s="1"' : "";
      if (cell == null || cell === "") return;
      if (cell instanceof Date) xml += `<c r="${ref}" s="2"><v>${serialDay(cell)}</v></c>`;
      else if (typeof cell === "number") xml += `<c r="${ref}"${style}><v>${cell}</v></c>`;
      else xml += `<c r="${ref}"${style} t="inlineStr"><is><t xml:space="preserve">${escape(String(cell))}</t></is></c>`;
    });
    xml += "</row>";
  });
  return xml + "</sheetData></worksheet>";
}

export function columnName(index) {
  let name = "";
  do {
    name = String.fromCharCode(65 + (index % 26)) + name;
    index = Math.floor(index / 26) - 1;
  } while (index >= 0);
  return name;
}

/** Excel day number for the local calendar date. */
export function serialDay(date) {
  const local = Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
  return Math.round((local - Date.UTC(1899, 11, 30)) / 86400000);
}

function escape(text) {
  return text
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "")
    .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");
}

// Stored (uncompressed) zip.
const CRC_TABLE = Array.from({ length: 256 }, (_, i) => {
  let c = i;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});

function crc32(bytes) {
  let c = 0xffffffff;
  for (const b of bytes) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function zip(files) {
  const encoder = new TextEncoder();
  const chunks = [], directory = [];
  let offset = 0;
  const DOS_DATE = (1 << 5) | 1; // 1980-01-01
  for (const [path, text] of files) {
    const name = encoder.encode(path), body = encoder.encode(text), crc = crc32(body);
    const local = new DataView(new ArrayBuffer(30));
    [[0, 0x04034b50, 4], [4, 20, 2], [6, 0, 2], [8, 0, 2], [10, 0, 2], [12, DOS_DATE, 2], [14, crc, 4],
     [18, body.length, 4], [22, body.length, 4], [26, name.length, 2], [28, 0, 2]].forEach(([at, v, n]) => set(local, at, v, n));
    const central = new DataView(new ArrayBuffer(46));
    [[0, 0x02014b50, 4], [4, 20, 2], [6, 20, 2], [8, 0, 2], [10, 0, 2], [12, 0, 2], [14, DOS_DATE, 2], [16, crc, 4],
     [20, body.length, 4], [24, body.length, 4], [28, name.length, 2], [30, 0, 2], [32, 0, 2], [34, 0, 2], [36, 0, 2],
     [38, 0, 4], [42, offset, 4]].forEach(([at, v, n]) => set(central, at, v, n));
    chunks.push(local, name, body);
    directory.push(central, name);
    offset += 30 + name.length + body.length;
  }
  const size = directory.reduce((s, part) => s + part.byteLength, 0);
  const end = new DataView(new ArrayBuffer(22));
  [[0, 0x06054b50, 4], [4, 0, 2], [6, 0, 2], [8, files.length, 2], [10, files.length, 2], [12, size, 4],
   [16, offset, 4], [20, 0, 2]].forEach(([at, v, n]) => set(end, at, v, n));
  const parts = [...chunks, ...directory, end];
  const out = new Uint8Array(parts.reduce((s, part) => s + part.byteLength, 0));
  let at = 0;
  for (const part of parts) {
    out.set(part instanceof DataView ? new Uint8Array(part.buffer) : part, at);
    at += part.byteLength;
  }
  return out;
}

function set(view, at, value, bytes) {
  if (bytes === 2) view.setUint16(at, value, true);
  else view.setUint32(at, value, true);
}
