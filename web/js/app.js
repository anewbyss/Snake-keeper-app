import * as db from "./db.js";
import { data, newID, now } from "./db.js";
import { h, raw, openSheet, closeSheet, toast, confirmAction, shareFiles, pickFile, resizeImage,
  daysAgo, formatDate, formatTime, toDateInput, fromDateInput, todayInput, formatWeight, formatBytes, plural } from "./ui.js";
import { INHERITANCE, Percent, zygosityOptions, homozygousName } from "./genetics.js";
import { SPECIES } from "./genes.js";
import * as M from "./model.js";
import { buildSyncFile, parseSyncFile, planMerge, describeSummary } from "./sync.js";
import { xlsxBlob, csv } from "./xlsx.js";
import { workbookSheets } from "./export.js";
import { applyBatch } from "./batch.js";

const app = document.getElementById("app");

// View state that should survive re-renders.
const ui = {
  search: "",
  selecting: false,
  selected: new Set(),
  visibleIDs: [],
  status: "current",
  sort: "name",
  speciesFilter: "",
  sexFilter: "",
  calc: { species: SPECIES[0].name, female: [], male: [], femaleName: null, maleName: null, clutch: 6 },
  finder: { species: SPECIES[0].name, geneID: "" },
  lastSaved: null,
  saveError: null,
};

// MARK: - Saving

async function save(store, records, options) {
  try {
    await db.save(store, records, options);
    ui.lastSaved = now();
    ui.saveError = null;
  } catch (error) {
    ui.saveError = `Save failed: ${error.message}`;
    throw error;
  }
}

async function remove(store, ids) {
  await db.remove(store, ids);
  ui.lastSaved = now();
}

async function deleteSnake(snake) {
  await remove("feedings", M.feedingsFor(snake).map((r) => r.id));
  await remove("logs", M.logsFor(snake).map((r) => r.id));
  await remove("concerns", M.concernsFor(snake).map((r) => r.id));
  await remove("photos", M.photosFor(snake).map((r) => r.id));
  await remove("snakes", snake.id);
}

// MARK: - Router

const routes = [
  [/^#\/collection$/, () => collectionView(), "collection"],
  [/^#\/snake\/([^/]+)$/, (id) => snakeView(id), "collection"],
  [/^#\/snake\/([^/]+)\/feedings$/, (id) => feedingHistoryView(id), "collection"],
  [/^#\/snake\/([^/]+)\/log$/, (id) => logHistoryView(id), "collection"],
  [/^#\/profile$/, () => profileView(), "settings"],
  [/^#\/feeding$/, () => feedingView(), "feeding"],
  [/^#\/pairings$/, () => pairingsView(), "pairings"],
  [/^#\/pairing\/([^/]+)$/, (id) => pairingView(id), "pairings"],
  [/^#\/finder$/, () => finderView(), "pairings"],
  [/^#\/preview\/([^/]+)\/([^/]+)$/, (f, m) => previewView(f, m), "pairings"],
  [/^#\/genetics$/, () => geneticsView(), "genetics"],
  [/^#\/settings$/, () => settingsView(), "settings"],
  [/^#\/library\/(.+)$/, (name) => libraryView(decodeURIComponent(name)), "settings"],
];

let afterRender = [];

function render() {
  const hash = location.hash || "#/collection";
  for (const [pattern, view, tab] of routes) {
    const match = hash.match(pattern);
    if (!match) continue;
    afterRender = [];
    app.innerHTML = view(...match.slice(1)).html;
    afterRender.forEach((fn) => fn());
    document.querySelectorAll(".tabbar a").forEach((a) => a.classList.toggle("active", a.dataset.tab === tab));
    return;
  }
  location.hash = "#/collection";
}

/** Re-render and keep the scroll position (for in-place updates). */
function refresh() {
  const y = window.scrollY;
  render();
  window.scrollTo(0, y);
}

function topbar(title, { back, action } = {}) {
  if (!back) {
    return h`<div class="topbar"><h1>${title}</h1>${action ?? ""}</div>`;
  }
  return h`<div class="topbar"><a class="back" href="${back.href}">‹ ${back.label}</a><div class="title-sm">${title}</div>${action ?? h`<span style="min-width:44px"></span>`}</div>`;
}

const notFound = (what) => h`${topbar(what, { back: { href: "#/collection", label: "Back" } })}<div class="empty">This ${what.toLowerCase()} no longer exists.</div>`;

// MARK: - Shared pieces

function thumb(snake, size = "") {
  const photo = snake && M.coverPhoto(snake);
  return photo
    ? h`<img class="thumb ${size}" src="data:image/jpeg;base64,${photo.thumbnail}" alt="">`
    : h`<div class="thumb ${size}" aria-hidden="true">🐍</div>`;
}

function statusBadge(snake) {
  const status = M.statusOf(snake);
  if (status === "active") return "";
  const { label, color } = M.STATUS[status];
  return h`<span class="badge" style="color:${color};background:color-mix(in srgb, ${color} 15%, transparent)">${label}</span>`;
}

function sexMark(sex) {
  return h`<span class="sex-${sex}">${M.SEX[sex]?.symbol ?? "?"}</span>`;
}

function snakeRow(snake, href = `#/snake/${snake.id}`, { selectable = false, checked = false } = {}) {
  const cat = M.catalog();
  const status = M.feedingStatus(snake);
  const days = M.daysSinceMeal(snake);
  const age = M.ageDescription(snake);
  const open = selectable
    ? h`<button class="row" data-action="toggle-select" data-id="${snake.id}" role="checkbox" aria-checked="${checked}">
        <span class="check ${checked ? "on" : ""}" aria-hidden="true">${checked ? "✓" : ""}</span>`
    : h`<a class="row" href="${href}">`;
  return h`
    ${open}
      ${thumb(snake)}
      <div class="grow">
        <div><span class="name">${snake.name}</span> ${sexMark(snake.sex)} ${M.openConcerns(snake).length ? h`<span class="warn" title="Open concerns">⚠︎</span>` : ""} ${statusBadge(snake)}</div>
        <div class="sub ellipsis">${cat.describe(snake.traits)}</div>
        <div class="tiny">${snake.species}${age ? ` · ${age}` : ""}${snake.enclosure ? ` · ${snake.enclosure}` : ""}</div>
      </div>
      <div class="tiny status-${status}" style="text-align:right" title="${M.FEEDING_STATUS_LABEL[status]}">
        ●<br>${days != null ? `${days}d` : ""}
      </div>
    ${raw(selectable ? "</button>" : "</a>")}`;
}

function outcomeList(result, clutch) {
  if (result.error) return h`<div class="row error">⚠︎ ${result.error}</div>`;
  const warnings = [...new Set(result.outcomes.flatMap((o) => o.warnings))].sort();
  return h`
    ${result.outcomes.map((o) => h`
      <div class="outcome">
        <div class="top">
          <div class="grow"><div class="name">${o.name}</div>${o.hets.length ? h`<div class="sub">${o.hetsDescription}</div>` : ""}</div>
          <div class="pct">${Percent.format(o.probability)}${clutch ? h`<div class="tiny">≈ ${(o.probability * clutch).toFixed(1)} of ${clutch}</div>` : ""}</div>
        </div>
        <div class="bar ${o.warnings.length ? "warn" : ""}"><div style="width:${(o.probability * 100).toFixed(2)}%"></div></div>
        ${o.warnings.length ? h`<div class="tiny warn" style="margin-top:4px">⚠︎ ${o.warnings.join(" · ")}</div>` : ""}
      </div>`)}
    ${warnings.length ? h`<div class="outcome warn"><strong>Health notes</strong>${warnings.map((w) => h`<div class="tiny warn">• ${w}</div>`)}</div>` : ""}`;
}

/**
 * Editable gene list. Renders into `container` and calls `onChange(traits)` after each edit.
 */
function mountTraits(container, { traits, species, onChange }) {
  const draw = () => {
    const cat = M.catalog();
    const available = cat.genesFor(species).filter((g) => !traits.some((t) => t.geneID === g.id));
    let error = null;
    try { cat.calculator.validate(traits); } catch (e) { error = e.message; }
    container.innerHTML = h`
      ${traits.map((trait, index) => {
        const gene = cat.byID[trait.geneID];
        if (!gene) return h`<div class="trait-row"><div class="grow sub">Unknown gene (deleted?)</div><button type="button" class="remove" data-remove="${index}" aria-label="Remove">⊖</button></div>`;
        const options = zygosityOptions(gene);
        const current = options.findIndex((o) => o.zygosity === trait.zygosity && (o.zygosity !== "possibleHet" || Math.abs(o.probability - trait.probability) < 1e-6));
        if (current < 0) options.push({ ...trait, label: `${Percent.floor(trait.probability)} Poss Het` });
        return h`
          <div class="trait-row">
            <button type="button" class="remove" data-remove="${index}" aria-label="Remove ${gene.name}">⊖</button>
            <div class="grow"><div>${gene.name}</div><div class="tiny">${INHERITANCE[gene.inheritance]}</div></div>
            <select data-zygosity="${index}" aria-label="${gene.name} copies">
              ${options.map((o, i) => h`<option value="${i}" ${i === (current < 0 ? options.length - 1 : current) ? "selected" : ""}>${o.label}</option>`)}
            </select>
          </div>`;
      })}
      ${error ? h`<div class="trait-row error tiny">⚠︎ ${error}</div>` : ""}
      <div class="trait-row">
        <select data-add class="grow" style="text-align:left;text-align-last:left" aria-label="Add gene">
          <option value="">＋ ${traits.length ? "Add gene" : "Add gene (Normal if none)"}</option>
          ${Object.entries(INHERITANCE).map(([key, label]) => {
            const genes = available.filter((g) => g.inheritance === key);
            return genes.length ? h`<optgroup label="${label}">${genes.map((g) => h`<option value="${g.id}">${g.name}${g.warning ? " ⚠︎" : ""}</option>`)}</optgroup>` : "";
          })}
        </select>
      </div>`.html;
    container.dataset.valid = error ? "false" : "true";
  };

  container.addEventListener("click", (event) => {
    const button = event.target.closest("[data-remove]");
    if (!button) return;
    traits.splice(Number(button.dataset.remove), 1);
    draw();
    onChange?.(traits);
  });
  container.addEventListener("change", (event) => {
    const el = event.target;
    if (el.matches("[data-add]") && el.value) {
      traits.push({ geneID: el.value, zygosity: "single" });
    } else if (el.matches("[data-zygosity]")) {
      const index = Number(el.dataset.zygosity);
      const gene = M.catalog().byID[traits[index].geneID];
      const options = zygosityOptions(gene);
      const choice = options[Number(el.value)];
      if (choice) traits[index] = { geneID: gene.id, zygosity: choice.zygosity, ...(choice.probability != null ? { probability: choice.probability } : {}) };
    } else return;
    draw();
    onChange?.(traits);
  });

  draw();
  return {
    setSpecies(next) {
      species = next;
      const valid = new Set(M.catalog().genesFor(species).map((g) => g.id));
      for (let i = traits.length - 1; i >= 0; i--) if (!valid.has(traits[i].geneID)) traits.splice(i, 1);
      draw();
      onChange?.(traits);
    },
    redraw: draw,
  };
}

const options = (entries, selected) =>
  entries.map(([value, label]) => h`<option value="${value}" ${value === selected ? "selected" : ""}>${label}</option>`);

const field = (label, control) => h`<label class="field"><span>${label}</span>${control}</label>`;

// MARK: - Collection

function collectionView() {
  afterRender.push(() => {
    const search = document.getElementById("search");
    search?.addEventListener("input", () => { ui.search = search.value; drawList(); });
    document.getElementById("species-filter")?.addEventListener("change", (e) => { ui.speciesFilter = e.target.value; drawList(); });
    document.getElementById("sex-filter")?.addEventListener("change", (e) => { ui.sexFilter = e.target.value; drawList(); });
    document.getElementById("status-filter")?.addEventListener("change", (e) => { ui.status = e.target.value; drawList(); });
    document.getElementById("sort")?.addEventListener("change", (e) => { ui.sort = e.target.value; drawList(); });
    drawList();
  });

  const add = ui.selecting
    ? h`<button class="icon-btn" style="font-size:17px" data-action="end-select">Done</button>`
    : h`<span style="display:flex">${data.snakes.length ? h`<button class="icon-btn" style="font-size:17px" data-action="start-select">Select</button>` : ""}
        <button class="icon-btn" data-action="add-snake" aria-label="Add snake">＋</button></span>`;
  if (!data.snakes.length) {
    return h`${topbar("Collection", { action: add })}
      <div class="empty"><div class="big">🐍</div><p><strong>No snakes yet</strong><br>Add your first animal to start tracking meals, health and pairings.</p>
      <button class="btn" data-action="add-snake">Add Snake</button></div>`;
  }
  const species = [...new Set(data.snakes.map((s) => s.species))].sort();
  return h`${topbar("Collection", { action: add })}
    <input id="search" class="search" type="search" placeholder="Search name, species or morph" value="${ui.search}" autocomplete="off">
    <div class="filters">
      <select id="species-filter" aria-label="Species filter"><option value="">All species</option>${options(species.map((s) => [s, s]), ui.speciesFilter)}</select>
      <select id="sex-filter" aria-label="Sex filter"><option value="">Any sex</option>${options(Object.entries(M.SEX).map(([k, v]) => [k, v.label]), ui.sexFilter)}</select>
    </div>
    <div class="filters">
      <select id="status-filter" aria-label="Status filter">${options([["current", "In collection"], ...Object.entries(M.STATUS).map(([k, v]) => [k, v.label]), ["all", "All, incl. sold"]], ui.status)}</select>
      <select id="sort" aria-label="Sort">${options([["name", "Sort: Name"], ["fed", "Sort: Feeding due"], ["age", "Sort: Oldest first"], ["newest", "Sort: Recently added"]], ui.sort)}</select>
    </div>
    <div id="snake-list" class="card" style="margin-top:8px"></div>
    ${ui.selecting ? h`<div style="height:64px"></div><div class="select-bar" id="select-bar"></div>` : ""}`;
}

function drawList() {
  const list = document.getElementById("snake-list");
  if (!list) return;
  const cat = M.catalog();
  const q = ui.search.trim().toLowerCase();
  const rank = { overdue: 0, due: 1, none: 2, fed: 3 };
  const sorters = {
    name: () => 0,
    fed: (a, b) => rank[M.feedingStatus(a)] - rank[M.feedingStatus(b)] || (M.nextFeeding(a) ?? "").localeCompare(M.nextFeeding(b) ?? ""),
    age: (a, b) => (a.hatchDate ?? "9999").localeCompare(b.hatchDate ?? "9999"),
    newest: (a, b) => (b.createdAt ?? "").localeCompare(a.createdAt ?? ""),
  };
  const snakes = M.sortedSnakes().sort(sorters[ui.sort] ?? sorters.name).filter((s) =>
    (ui.status === "all" || (ui.status === "current" ? M.isInCollection(s) : M.statusOf(s) === ui.status))
    && (!ui.speciesFilter || s.species === ui.speciesFilter)
    && (!ui.sexFilter || s.sex === ui.sexFilter)
    && (!q || s.name.toLowerCase().includes(q) || s.species.toLowerCase().includes(q) || cat.describe(s.traits).toLowerCase().includes(q)));
  ui.visibleIDs = snakes.map((s) => s.id);
  list.innerHTML = snakes.length
    ? h`${snakes.map((s) => snakeRow(s, undefined, { selectable: ui.selecting, checked: ui.selected.has(s.id) }))}`.html
    : h`<div class="empty">No matches</div>`.html;
  const bar = document.getElementById("select-bar");
  if (bar) {
    const count = ui.selected.size;
    const allVisible = snakes.length > 0 && snakes.every((s) => ui.selected.has(s.id));
    bar.innerHTML = h`
      <button class="btn secondary" data-action="${allVisible ? "select-none" : "select-all"}">${allVisible ? "Select None" : "Select All"}</button>
      <span class="grow" style="text-align:center">${count ? `${count} selected` : "Tap snakes to select"}</span>
      <button class="btn" data-action="batch-edit" ${count ? "" : "disabled"}>Edit ${count || ""}</button>`.html;
  }
}

// MARK: - Batch edit

function batchForm() {
  const snakes = [...ui.selected].map(M.snakeByID).filter(Boolean);
  if (!snakes.length) return;
  const cat = M.catalog();
  const speciesList = [...new Set(snakes.map((s) => s.species))];
  // Only genes every selected species can carry.
  const geneLists = speciesList.map((sp) => cat.genesFor(sp));
  const genes = geneLists[0].filter((g) => geneLists.every((list) => list.some((o) => o.id === g.id)));
  const form = openSheet({
    title: `Edit ${plural(snakes.length, "Snake")}`,
    submitLabel: "Apply",
    body: h`
      <p class="footnote" style="margin-top:12px">${snakes.map((s) => s.name).join(", ")}</p>
      <h2>Gene</h2>
      <div class="card">
        ${genes.length ? h`
          ${field("Gene", h`<select name="geneID"><option value="">Don't change genes</option>${Object.entries(INHERITANCE).map(([key, label]) => {
            const list = genes.filter((g) => g.inheritance === key);
            return list.length ? h`<optgroup label="${label}">${list.map((g) => h`<option value="${g.id}">${g.name}</option>`)}</optgroup>` : "";
          })}</select>`)}
          <div class="field"><span>Action</span><div class="segmented">
            <label><input type="radio" name="mode" value="set" checked>Add / set</label>
            <label><input type="radio" name="mode" value="remove">Remove</label>
          </div></div>
          <label class="field" id="zygosity-row"><span>Copies</span><select name="zygosity"></select></label>`
        : h`<div class="row sub">${speciesList.length > 1 ? "The selected snakes are different species with no genes in common." : "No genes for this species. Add custom genes in Settings."}</div>`}
      </div>
      <p class="footnote">Snakes the change would make impossible (e.g. a third gene at the same locus) are skipped and listed.</p>
      <h2>Status</h2>
      <div class="card">
        ${field("Status", h`<select name="status"><option value="">Don't change</option>${options(Object.entries(M.STATUS).map(([k, v]) => [k, v.label]), "")}</select>`)}
      </div>`,
    onSubmit: async (f) => {
      const change = {};
      const geneID = f.geneID?.value;
      if (geneID) {
        const mode = f.mode.value;
        const choice = mode === "set" ? zygosityOptions(cat.byID[geneID])[Number(f.zygosity.value)] : null;
        change.gene = { geneID, mode, ...(choice ? { zygosity: choice.zygosity, probability: choice.probability } : {}) };
      }
      if (f.status.value) change.status = f.status.value;
      if (!change.gene && !change.status) { toast("Choose a gene or a status to change."); return false; }
      const { updated, skipped } = applyBatch(snakes, change, cat.calculator);
      await save("snakes", updated);
      let message = updated.length ? `Updated ${plural(updated.length, "snake")}` : "Nothing needed changing";
      if (skipped.length) message += ` · skipped ${skipped.map((x) => x.snake.name).join(", ")} (gene limit)`;
      toast(message);
      ui.selecting = false;
      ui.selected.clear();
      refresh();
    },
  });
  const updateZygosity = () => {
    const gene = cat.byID[form.geneID?.value];
    const setMode = form.querySelector('input[name="mode"]:checked')?.value === "set";
    const row = form.querySelector("#zygosity-row");
    if (!row) return;
    row.hidden = !gene || !setMode;
    if (gene) form.zygosity.innerHTML = h`${zygosityOptions(gene).map((o, i) => h`<option value="${i}">${o.label}</option>`)}`.html;
  };
  form.geneID?.addEventListener("change", updateZygosity);
  form.querySelectorAll('input[name="mode"]').forEach((r) => r.addEventListener("change", updateZygosity));
  updateZygosity();
}

function snakeView(id) {
  const snake = M.snakeByID(id);
  if (!snake) return notFound("Snake");
  const cat = M.catalog();
  const meal = M.lastMeal(snake);
  const status = M.feedingStatus(snake);
  const streak = M.refusalStreak(snake);
  const feedings = M.feedingsFor(snake);
  const open = M.openConcerns(snake);
  const resolved = M.concernsFor(snake).filter((c) => c.isResolved);
  const photos = M.photosFor(snake);
  const info = M.speciesInfo(snake.species);
  const opposite = snake.sex === "male" ? "female" : snake.sex === "female" ? "male" : null;
  const partners = opposite ? M.sortedSnakes().filter((s) => s.species === snake.species && s.sex === opposite && M.isInCollection(s)) : [];
  const dam = M.snakeByID(snake.damID), sire = M.snakeByID(snake.sireID);
  const offspring = M.offspringOf(snake);
  const lifeStatus = M.statusOf(snake);

  return h`
    ${topbar(snake.name, { back: { href: "#/collection", label: "Collection" }, action: h`<button class="icon-btn" style="font-size:17px" data-action="edit-snake" data-id="${snake.id}">Edit</button>` })}
    <div class="card"><div class="hero">${thumb(snake, "lg")}
      <div><div class="morph">${cat.describe(snake.traits)}</div><div class="sub">${snake.species}</div>${info ? h`<div class="tiny"><em>${info.scientificName}</em></div>` : ""}
        ${lifeStatus !== "active" ? h`<div style="margin-top:6px">${statusBadge(snake)}</div>` : ""}</div>
    </div></div>

    <h2>Details</h2>
    <div class="card">
      <div class="row"><span class="grow">Sex</span><span class="sex-${snake.sex}">${M.SEX[snake.sex].symbol} ${M.SEX[snake.sex].label}</span></div>
      <div class="row"><span class="grow">Status</span><span class="value">${M.STATUS[lifeStatus].label}${snake.statusNote ? ` · ${snake.statusNote}` : ""}</span></div>
      ${snake.enclosure ? h`<div class="row"><span class="grow">Enclosure</span><span class="value">${snake.enclosure}</span></div>` : ""}
      <div class="row"><span class="grow">Age</span><span class="value">${M.ageDescription(snake) ?? "Unknown"}</span></div>
      ${snake.hatchDate ? h`<div class="row"><span class="grow">Hatched</span><span class="value">${formatDate(snake.hatchDate)}${snake.hatchDateIsEstimate ? " (est.)" : ""}</span></div>` : ""}
      <div class="row"><span class="grow">Origin</span><span class="value">${M.ORIGIN[snake.origin]?.label ?? snake.origin}</span></div>
      ${snake.originDetails ? h`<div class="row"><span class="grow">${M.ORIGIN[snake.origin]?.prompt ?? "Details"}</span><span class="value">${snake.originDetails}</span></div>` : ""}
      ${snake.acquiredDate ? h`<div class="row"><span class="grow">Acquired</span><span class="value">${formatDate(snake.acquiredDate)}</span></div>` : ""}
      ${snake.weightGrams ? h`<div class="row"><span class="grow">Weight</span><span class="value">${formatWeight(snake.weightGrams)}</span></div>` : ""}
      ${dam ? h`<a class="row chevron" href="#/snake/${dam.id}"><span class="grow">Dam ♀</span><span class="value">${dam.name}</span></a>` : ""}
      ${sire ? h`<a class="row chevron" href="#/snake/${sire.id}"><span class="grow">Sire ♂</span><span class="value">${sire.name}</span></a>` : ""}
    </div>

    <h2>Feeding · every ${snake.feedingIntervalDays} days</h2>
    <div class="card">
      ${meal ? h`
        <div class="row"><span class="grow">Last meal</span><span style="text-align:right"><span class="status-${status}">${daysAgo(meal.date)}</span><br><span class="tiny">${M.feedingSummary(meal)}</span></span></div>
        <div class="row"><span class="grow">Next feeding</span><span class="value">${formatDate(M.nextFeeding(snake))}</span></div>`
        : h`<div class="row sub">No meals logged</div>`}
      ${streak ? h`<div class="row warn">✋ Refused last ${plural(streak, "offer")}</div>` : ""}
      <button class="link-btn" data-action="log-feeding" data-id="${snake.id}">⊕ Log Feeding</button>
      ${feedings.length ? h`<a class="row chevron" href="#/snake/${snake.id}/feedings"><span class="grow">History</span><span class="value">${plural(feedings.length, "record")}</span></a>` : ""}
    </div>

    ${careLogSection(snake)}

    <h2>Health &amp; Concerns</h2>
    <div class="card">
      ${open.map((c) => concernRow(c))}
      <button class="link-btn" data-action="add-concern" data-id="${snake.id}">⊕ Add Concern</button>
    </div>
    ${resolved.length ? h`<details class="card" style="margin-top:8px"><summary class="row">Resolved (${resolved.length})</summary>${resolved.map((c) => concernRow(c))}</details>` : ""}

    <h2>Photos</h2>
    <div class="card">
      ${photos.length ? h`<div class="photo-grid">${photos.map((p) => h`
        <button data-action="view-photo" data-id="${p.id}" aria-label="Photo ${formatDate(p.dateTaken)}">
          <img src="data:image/jpeg;base64,${p.thumbnail}" alt="">${p.isCover ? h`<span class="star">★</span>` : ""}
        </button>`)}</div>` : ""}
      <button class="link-btn" data-action="add-photos" data-id="${snake.id}">⊕ Add Photos</button>
    </div>

    <h2>Potential Pairings</h2>
    <div class="card">
      ${snake.sex === "unknown" ? h`<div class="row sub">Set this snake's sex to see potential pairings.</div>`
        : partners.length ? partners.map((partner) => {
          const [female, male] = snake.sex === "female" ? [snake, partner] : [partner, snake];
          const result = cat.cross(female.traits, male.traits);
          let summary = result.error ?? "";
          if (!result.error) {
            const best = result.outcomes.filter((o) => o.visualTraits.length).sort((a, b) => b.visualTraits.length - a.visualTraits.length)[0];
            summary = best ? `${plural(result.outcomes.length, "outcome")} · up to ${best.name} (${Percent.format(best.probability)})` : plural(result.outcomes.length, "outcome");
          }
          return h`<a class="row chevron" href="#/preview/${female.id}/${male.id}"><div class="grow">
            <div>${sexMark(partner.sex)} ${partner.name}</div><div class="sub ellipsis">${cat.describe(partner.traits)}</div><div class="tiny ${result.error ? "error" : "accent"}">${summary}</div></div></a>`;
        })
        : h`<div class="row sub">No ${M.SEX[opposite].label.toLowerCase()} ${snake.species} in your collection yet.</div>`}
      ${M.pairingsFor(snake).map((p) => h`<a class="row chevron" href="#/pairing/${p.id}"><span class="grow">${M.PAIRING_STATUSES[p.status] ?? ""} ${p.season}: ${M.pairingTitle(p)} — ${p.status}</span></a>`)}
    </div>

    ${offspring.length ? h`<h2>Offspring (${offspring.length})</h2><div class="card">${offspring.map((s) => snakeRow(s))}</div>` : ""}

    ${snake.notes ? h`<h2>Notes</h2><div class="card"><div class="row" style="white-space:pre-wrap">${snake.notes}</div></div>` : ""}
    <div class="card" style="margin-top:24px"><button class="link-btn danger" data-action="delete-snake" data-id="${snake.id}">Delete ${snake.name}</button></div>`;
}

function concernRow(c) {
  return h`<button class="row" data-action="edit-concern" data-id="${c.id}">
    <span class="dot" style="background:${c.isResolved ? "var(--green)" : M.SEVERITIES[c.severity] ?? "var(--yellow)"}"></span>
    <div class="grow"><div>${c.title}</div><div class="tiny">${c.category} · ${formatDate(c.dateNoted)}</div>${c.details ? h`<div class="tiny ellipsis">${c.details}</div>` : ""}</div>
    ${c.vetVisit ? h`<span title="Vet visit">🩺</span>` : ""}
  </button>`;
}

function feedingHistoryView(id) {
  const snake = M.snakeByID(id);
  if (!snake) return notFound("Snake");
  const records = M.feedingsFor(snake);
  const rate = records.length ? Math.round((records.filter((r) => !r.refused).length / records.length) * 100) : 0;
  return h`${topbar("Feeding History", { back: { href: `#/snake/${id}`, label: snake.name } })}
    <div class="card">
      <div class="row"><span class="grow">Records</span><span class="value">${records.length}</span></div>
      <div class="row"><span class="grow">Acceptance</span><span class="value">${rate}%</span></div>
    </div>
    <h2>Meals</h2>
    <div class="card">${records.map((r) => h`
      <button class="row" data-action="edit-feeding" data-id="${r.id}">
        <span class="${r.refused ? "error" : "status-fed"}">${r.refused ? "✕" : "✓"}</span>
        <div class="grow"><div>${M.feedingSummary(r)}</div>${r.notes ? h`<div class="tiny">${r.notes}</div>` : ""}</div>
        <span class="tiny">${formatDate(r.date)}</span>
      </button>`)}</div>
    <p class="footnote">Tap a meal to edit or delete it.</p>`;
}

// MARK: - Snake form

function snakeForm(snake, preset = {}) {
  const cat = M.catalog();
  const p = M.profile();
  const draft = snake ? structuredClone(snake) : {
    id: newID(), createdAt: now(), name: "", species: preset.species ?? p.defaultSpecies, sex: "unknown",
    hatchDate: preset.hatchDate ?? null, hatchDateIsEstimate: false, origin: preset.origin ?? "purchased",
    originDetails: preset.originDetails ?? "", acquiredDate: null, weightGrams: null,
    feedingIntervalDays: p.defaultFeedingInterval || 7, traits: [], notes: "", status: "active", statusNote: "",
    enclosure: "", damID: preset.damID ?? null, sireID: preset.sireID ?? null,
  };
  draft.status = M.statusOf(draft);
  draft.statusNote ??= "";
  draft.enclosure ??= "";
  const parentOptions = (sex, selected) => h`<option value="">None</option>${M.sortedSnakes()
    .filter((s) => s.sex === sex && s.id !== draft.id && (s.species === draft.species || s.id === selected))
    .map((s) => h`<option value="${s.id}" ${s.id === selected ? "selected" : ""}>${s.name}</option>`)}`.html;

  const form = openSheet({
    title: snake ? `Edit ${snake.name}` : preset.damID ? "New Hatchling" : "New Snake",
    body: h`
      <h2>Identity</h2>
      <div class="card">
        ${field("Name or ID", h`<input name="name" value="${draft.name}" placeholder="Required" required>`)}
        ${field("Species", h`<select name="species">${options(cat.speciesNames.map((s) => [s, s]), draft.species)}</select>`)}
        <div class="field"><span>Sex</span><div class="segmented">${Object.entries(M.SEX).map(([k, v]) => h`<label><input type="radio" name="sex" value="${k}" ${k === draft.sex ? "checked" : ""}>${v.symbol} ${v.label}</label>`)}</div></div>
      </div>
      <h2>Status</h2>
      <div class="card">
        ${field("Status", h`<select name="status">${options(Object.entries(M.STATUS).map(([k, v]) => [k, v.label]), draft.status)}</select>`)}
        ${field("Status note", h`<input name="statusNote" value="${draft.statusNote}" placeholder="Price, buyer, date…">`)}
        ${field("Enclosure", h`<input name="enclosure" value="${draft.enclosure}" placeholder="Rack / tub / tank">`)}
      </div>
      <h2>Age</h2>
      <div class="card">
        ${field("Hatched", h`<input type="date" name="hatchDate" max="${todayInput()}" value="${toDateInput(draft.hatchDate)}">`)}
        ${field("Estimated", h`<input type="checkbox" name="hatchDateIsEstimate" ${draft.hatchDateIsEstimate ? "checked" : ""}>`)}
      </div>
      <h2>Origin</h2>
      <div class="card">
        ${field("Origin", h`<select name="origin">${options(Object.entries(M.ORIGIN).map(([k, v]) => [k, v.label]), draft.origin)}</select>`)}
        ${field(h`<span id="origin-prompt">${M.ORIGIN[draft.origin]?.prompt ?? "Details"}</span>`, h`<input name="originDetails" value="${draft.originDetails}">`)}
        ${field("Acquired", h`<input type="date" name="acquiredDate" max="${todayInput()}" value="${toDateInput(draft.acquiredDate)}">`)}
        ${field("Dam ♀", h`<select name="damID"></select>`)}
        ${field("Sire ♂", h`<select name="sireID"></select>`)}
      </div>
      <h2>Husbandry</h2>
      <div class="card">
        ${field("Weight (g)", h`<input type="number" inputmode="decimal" min="0" step="any" name="weightGrams" value="${draft.weightGrams ?? ""}" placeholder="Grams">`)}
        ${field("Feed every", h`<input type="number" inputmode="numeric" min="1" max="60" name="feedingIntervalDays" value="${draft.feedingIntervalDays}" style="max-width:80px"> days`)}
      </div>
      <h2>Genetics</h2>
      <div class="card" id="traits"></div>
      <p class="footnote" id="morph-preview"></p>
      <h2>Notes</h2>
      <div class="card"><label class="field stack"><textarea name="notes" placeholder="Temperament, husbandry, anything else">${draft.notes}</textarea></label></div>`,
    onSubmit: async (f) => {
      const name = f.name.value.trim();
      if (!name) { toast("Give your snake a name or ID."); return false; }
      if (traitsBox.dataset.valid === "false") { toast("Fix the gene error first."); return false; }
      const weight = f.weightGrams.value ? Number(f.weightGrams.value) : null;
      const weightChanged = weight != null && weight !== draft.weightGrams;
      Object.assign(draft, {
        name,
        species: f.species.value,
        sex: f.sex.value,
        status: f.status.value,
        statusNote: f.statusNote.value.trim(),
        enclosure: f.enclosure.value.trim(),
        hatchDate: f.hatchDate.value === toDateInput(draft.hatchDate) ? draft.hatchDate : fromDateInput(f.hatchDate.value),
        hatchDateIsEstimate: !!f.hatchDate.value && f.hatchDateIsEstimate.checked,
        origin: f.origin.value,
        originDetails: f.originDetails.value.trim(),
        acquiredDate: f.acquiredDate.value === toDateInput(draft.acquiredDate) ? draft.acquiredDate : fromDateInput(f.acquiredDate.value),
        damID: f.damID.value || null,
        sireID: f.sireID.value || null,
        weightGrams: weight,
        feedingIntervalDays: Math.min(60, Math.max(1, Number(f.feedingIntervalDays.value) || 7)),
        notes: f.notes.value,
      });
      await save("snakes", draft);
      // Keep weight history: a new or changed weight goes into the care log too.
      if (weightChanged) await logWeight(draft, weight, now());
      toast(snake ? "Saved" : `Added ${draft.name}`);
      if (!snake) location.hash = `#/snake/${draft.id}`;
      refresh();
    },
  });
  const traitsBox = form.querySelector("#traits");
  const preview = form.querySelector("#morph-preview");
  const showMorph = () => { preview.textContent = M.catalog().describe(draft.traits); };
  const editor = mountTraits(traitsBox, { traits: draft.traits, species: draft.species, onChange: showMorph });
  const fillParents = () => {
    form.damID.innerHTML = parentOptions("female", form.damID.value || draft.damID);
    form.sireID.innerHTML = parentOptions("male", form.sireID.value || draft.sireID);
  };
  showMorph();
  fillParents();
  form.species.addEventListener("change", () => {
    draft.species = form.species.value;
    editor.setSpecies(form.species.value);
    fillParents();
  });
  form.origin.addEventListener("change", () => {
    form.querySelector("#origin-prompt").textContent = M.ORIGIN[form.origin.value].prompt;
    if (form.origin.value === "homeBred" && !form.originDetails.value && M.breederName()) form.originDetails.value = M.breederName();
  });
}

// MARK: - Care log

async function logWeight(snake, grams, date) {
  await save("logs", { id: newID(), snakeID: snake.id, date, kind: "weight", grams, notes: "" });
  const latest = M.weightsFor(snake)[0];
  if (latest && latest.grams !== snake.weightGrams) await save("snakes", { ...snake, weightGrams: latest.grams });
}

function weightChart(weights) {
  const points = [...weights].reverse().slice(-24);
  if (points.length < 2) return "";
  const w = 300, ht = 70, pad = 6;
  const times = points.map((p) => Date.parse(p.date)), grams = points.map((p) => p.grams);
  const [t0, t1] = [Math.min(...times), Math.max(...times)], [g0, g1] = [Math.min(...grams), Math.max(...grams)];
  const x = (t) => pad + ((t - t0) / (t1 - t0 || 1)) * (w - 2 * pad);
  const y = (g) => ht - pad - ((g - g0) / (g1 - g0 || 1)) * (ht - 2 * pad);
  const path = points.map((p, i) => `${i ? "L" : "M"}${x(times[i]).toFixed(1)},${y(p.grams).toFixed(1)}`).join(" ");
  const change = grams[grams.length - 1] - grams[0];
  return h`<div class="row" style="display:block">
    <div class="tiny">Weight trend · ${change >= 0 ? "+" : "−"}${formatWeight(Math.abs(change))} since ${formatDate(points[0].date)}</div>
    <svg viewBox="0 0 ${w} ${ht}" style="width:100%;height:80px" role="img" aria-label="Weight trend">
      <path d="${path}" fill="none" stroke="var(--accent)" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>
      ${points.map((p, i) => h`<circle cx="${x(times[i]).toFixed(1)}" cy="${y(p.grams).toFixed(1)}" r="3" fill="var(--accent)"/>`)}
    </svg>
    <div class="tiny" style="display:flex;justify-content:space-between"><span>${formatWeight(g0)}</span><span>${formatWeight(g1)}</span></div>
  </div>`;
}

function logRow(entry) {
  const kind = M.LOG_KINDS[entry.kind] ?? M.LOG_KINDS.note;
  return h`<button class="row" data-action="edit-log" data-id="${entry.id}">
    <span style="width:24px;text-align:center">${kind.icon}</span>
    <div class="grow"><div>${kind.label}${entry.kind === "weight" && entry.grams ? ` · ${formatWeight(entry.grams)}` : ""}</div>${entry.notes ? h`<div class="tiny ellipsis">${entry.notes}</div>` : ""}</div>
    <span class="tiny">${formatDate(entry.date)}</span>
  </button>`;
}

function careLogSection(snake) {
  const logs = M.logsFor(snake);
  const shed = M.lastShed(snake);
  return h`<h2>Care Log</h2>
    <div class="card">
      ${shed ? h`<div class="row"><span class="grow">Last shed</span><span class="value">${daysAgo(shed.date)}</span></div>` : ""}
      ${weightChart(M.weightsFor(snake))}
      ${logs.slice(0, 3).map(logRow)}
      <div class="row" style="gap:6px;flex-wrap:wrap">
        ${["shed", "weight", "cleaning", "medication", "note"].map((k) => h`<button class="btn secondary" style="min-height:36px;padding:0 10px;font-size:14px" data-action="log-care" data-id="${snake.id}" data-kind="${k}">${M.LOG_KINDS[k].icon} ${k === "cleaning" ? "Cleaned" : k === "medication" ? "Meds" : M.LOG_KINDS[k].label}</button>`)}
      </div>
      ${logs.length > 3 ? h`<a class="row chevron" href="#/snake/${snake.id}/log"><span class="grow">All entries</span><span class="value">${logs.length}</span></a>` : ""}
    </div>`;
}

function logHistoryView(id) {
  const snake = M.snakeByID(id);
  if (!snake) return notFound("Snake");
  const logs = M.logsFor(snake);
  return h`${topbar("Care Log", { back: { href: `#/snake/${id}`, label: snake.name } })}
    ${M.weightsFor(snake).length > 1 ? h`<div class="card">${weightChart(M.weightsFor(snake))}</div>` : ""}
    <h2>Entries</h2>
    <div class="card">${logs.length ? logs.map(logRow) : h`<div class="row sub">Nothing logged yet.</div>`}</div>
    <p class="footnote">Tap an entry to edit or delete it.</p>`;
}

function logForm(snake, entry, kind = "note") {
  const draft = entry ? structuredClone(entry) : { id: newID(), snakeID: snake.id, date: now(), kind, grams: null, notes: "" };
  const form = openSheet({
    title: entry ? "Edit Entry" : M.LOG_KINDS[draft.kind]?.label ?? "Log",
    body: h`
      <div class="card" style="margin-top:12px">
        ${field("Type", h`<select name="kind">${options(Object.entries(M.LOG_KINDS).map(([k, v]) => [k, `${v.icon} ${v.label}`]), draft.kind)}</select>`)}
        ${field("Date", h`<input type="date" name="date" max="${todayInput()}" value="${toDateInput(draft.date)}">`)}
        <label class="field" id="grams-row"><span>Weight (g)</span><input type="number" inputmode="decimal" min="0" step="any" name="grams" value="${draft.grams ?? ""}" placeholder="${snake.weightGrams ? formatWeight(snake.weightGrams) : "Grams"}"></label>
      </div>
      <h2>Notes</h2>
      <div class="card"><label class="field stack"><textarea name="notes" placeholder="${draft.kind === "shed" ? "One piece? Eye caps? Stuck tail?" : draft.kind === "medication" ? "Drug, dose, schedule" : "Notes"}">${draft.notes}</textarea></label></div>
      ${entry ? h`<div class="card" style="margin-top:24px"><button type="button" class="link-btn danger" id="delete-log">Delete Entry</button></div>` : ""}`,
    onSubmit: async (f) => {
      const grams = f.grams.value ? Number(f.grams.value) : null;
      if (f.kind.value === "weight" && !grams) { toast("Enter the weight in grams."); return false; }
      const picked = f.date.value;
      draft.date = picked === toDateInput(draft.date) ? draft.date : picked === todayInput() ? now() : fromDateInput(picked);
      Object.assign(draft, { kind: f.kind.value, grams: f.kind.value === "weight" ? grams : null, notes: f.notes.value });
      await save("logs", draft);
      if (draft.kind === "weight") {
        const latest = M.weightsFor(snake)[0];
        if (latest && latest.grams !== snake.weightGrams) await save("snakes", { ...snake, weightGrams: latest.grams });
      }
      toast(`${M.LOG_KINDS[draft.kind].label} logged`);
      refresh();
    },
  });
  const showGrams = () => { form.querySelector("#grams-row").hidden = form.kind.value !== "weight"; };
  form.kind.addEventListener("change", showGrams);
  showGrams();
  if (draft.kind === "weight" && !entry) setTimeout(() => form.grams.focus(), 50);
  document.getElementById("delete-log")?.addEventListener("click", async () => {
    if (!confirmAction("Delete this entry?")) return;
    await remove("logs", entry.id);
    closeSheet();
    refresh();
  });
}

// MARK: - Profile

function profileView() {
  const p = M.profile();
  const row = (label, value, href) => (value ? h`<${href ? "a" : "div"} class="row${href ? " chevron" : ""}" ${href ? h`href="${href}"` : ""}><span class="grow">${label}</span><span class="value ellipsis" style="max-width:60%">${value}</span></${href ? "a" : "div"}>` : "");
  const website = p.website && !/^https?:\/\//i.test(p.website) ? `https://${p.website}` : p.website;
  return h`${topbar("Profile", { back: { href: "#/settings", label: "Settings" }, action: h`<button class="icon-btn" style="font-size:17px" data-action="edit-profile">Edit</button>` })}
    <div class="card"><div class="hero">
      ${p.photo ? h`<img class="thumb lg" src="data:image/jpeg;base64,${p.photo}" alt="">` : h`<div class="thumb lg" aria-hidden="true">👤</div>`}
      <div><div class="morph">${M.breederName() || "Add your details"}</div>${p.business && p.name ? h`<div class="sub">${p.name}</div>` : ""}${p.location ? h`<div class="tiny">${p.location}</div>` : ""}</div>
    </div></div>
    <h2>Contact</h2>
    <div class="card">
      ${row("Email", p.email, p.email && `mailto:${encodeURIComponent(p.email)}`)}
      ${row("Phone", p.phone, p.phone && `tel:${p.phone.replace(/[^+\d]/g, "")}`)}
      ${row("Website", p.website, website)}
      ${row("Social", p.social)}
      ${!p.email && !p.phone && !p.website && !p.social ? h`<div class="row sub">No contact details yet.</div>` : ""}
    </div>
    <h2>Defaults</h2>
    <div class="card">
      <div class="row"><span class="grow">Species for new snakes</span><span class="value">${p.defaultSpecies}</span></div>
      <div class="row"><span class="grow">Feeding interval</span><span class="value">${p.defaultFeedingInterval} days</span></div>
    </div>
    <h2>At a glance</h2>
    <div class="card">
      <div class="row"><span class="grow">In collection</span><span class="value">${data.snakes.filter(M.isInCollection).length}</span></div>
      <div class="row"><span class="grow">For sale</span><span class="value">${data.snakes.filter((s) => M.statusOf(s) === "forSale").length}</span></div>
      <div class="row"><span class="grow">Bred by you</span><span class="value">${data.snakes.filter((s) => s.origin === "homeBred").length}</span></div>
      <div class="row"><span class="grow">Active pairings</span><span class="value">${data.pairings.filter(M.isActivePairing).length}</span></div>
    </div>
    ${p.notes ? h`<h2>Notes</h2><div class="card"><div class="row" style="white-space:pre-wrap">${p.notes}</div></div>` : ""}
    <p class="footnote">Your name appears on exports and as the default for snakes you breed. The profile syncs with the iPad app.</p>`;
}

function profileForm() {
  const draft = M.profile();
  const form = openSheet({
    title: "Edit Profile",
    body: h`
      <div class="card" style="margin-top:12px">
        <div class="row">
          <span id="profile-photo">${draft.photo ? h`<img class="thumb" src="data:image/jpeg;base64,${draft.photo}" alt="">` : h`<div class="thumb" aria-hidden="true">👤</div>`}</span>
          <div class="grow"><button type="button" class="btn secondary" id="pick-photo">Choose Photo / Logo</button></div>
          ${draft.photo ? h`<button type="button" class="btn danger" id="clear-photo">Remove</button>` : ""}
        </div>
      </div>
      <h2>Breeder</h2>
      <div class="card">
        ${field("Your name", h`<input name="name" value="${draft.name}" autocomplete="name">`)}
        ${field("Business", h`<input name="business" value="${draft.business}" placeholder="Optional" autocomplete="organization">`)}
        ${field("Location", h`<input name="location" value="${draft.location}" placeholder="City, state / country">`)}
      </div>
      <h2>Contact</h2>
      <div class="card">
        ${field("Email", h`<input type="email" name="email" value="${draft.email}" autocomplete="email">`)}
        ${field("Phone", h`<input type="tel" name="phone" value="${draft.phone}" autocomplete="tel">`)}
        ${field("Website", h`<input type="url" name="website" value="${draft.website}" placeholder="example.com" autocomplete="url">`)}
        ${field("Social", h`<input name="social" value="${draft.social}" placeholder="@handle, MorphMarket store…">`)}
      </div>
      <h2>Defaults</h2>
      <div class="card">
        ${field("Species", h`<select name="defaultSpecies">${options(M.catalog().speciesNames.map((s) => [s, s]), draft.defaultSpecies)}</select>`)}
        ${field("Feed every", h`<input type="number" inputmode="numeric" min="1" max="60" name="defaultFeedingInterval" value="${draft.defaultFeedingInterval}" style="max-width:80px"> days`)}
      </div>
      <h2>Notes</h2>
      <div class="card"><label class="field stack"><textarea name="notes" placeholder="Permits, policies, anything else">${draft.notes}</textarea></label></div>`,
    onSubmit: async (f) => {
      Object.assign(draft, {
        name: f.name.value.trim(), business: f.business.value.trim(), location: f.location.value.trim(),
        email: f.email.value.trim(), phone: f.phone.value.trim(), website: f.website.value.trim(), social: f.social.value.trim(),
        defaultSpecies: f.defaultSpecies.value, defaultFeedingInterval: Math.min(60, Math.max(1, Number(f.defaultFeedingInterval.value) || 7)),
        notes: f.notes.value,
      });
      await save("profile", draft);
      ui.calc.species = ui.finder.species = draft.defaultSpecies;
      toast("Profile saved");
      refresh();
    },
  });
  form.querySelector("#pick-photo").addEventListener("click", async () => {
    const [file] = await pickFile("image/*");
    if (!file) return;
    draft.photo = await resizeImage(file, 600, 0.85);
    form.querySelector("#profile-photo").innerHTML = h`<img class="thumb" src="data:image/jpeg;base64,${draft.photo}" alt="">`.html;
  });
  form.querySelector("#clear-photo")?.addEventListener("click", (e) => {
    draft.photo = null;
    form.querySelector("#profile-photo").innerHTML = h`<div class="thumb" aria-hidden="true">👤</div>`.html;
    e.target.remove();
  });
}

// MARK: - Feeding

function feedingForm(snake, record) {
  const template = record ?? M.lastMeal(snake);
  const draft = record ? structuredClone(record) : {
    id: newID(), snakeID: snake.id, date: now(), preyType: template?.preyType ?? "Mouse", preySize: template?.preySize ?? "Small",
    preyState: template?.preyState ?? "Frozen/thawed", preyCount: template?.preyCount ?? 1, preyWeightGrams: template?.preyWeightGrams ?? null,
    refused: false, notes: "",
  };
  openSheet({
    title: record ? "Edit Feeding" : "Log Feeding",
    body: h`
      <div class="card" style="margin-top:12px">
        ${field("Date", h`<input type="date" name="date" max="${todayInput()}" value="${toDateInput(draft.date)}">`)}
        ${field("Refused", h`<input type="checkbox" name="refused" ${draft.refused ? "checked" : ""}>`)}
      </div>
      <h2>Prey</h2>
      <div class="card">
        ${field("Type", h`<select name="preyType">${options(M.PREY_TYPES.map((p) => [p, p]), draft.preyType)}</select>`)}
        ${field("Size", h`<select name="preySize">${options(M.PREY_SIZES.map((p) => [p, p]), draft.preySize)}</select>`)}
        ${field("Offered", h`<select name="preyState">${options(Object.keys(M.PREY_STATES).map((p) => [p, p]), draft.preyState)}</select>`)}
        ${field("Count", h`<input type="number" inputmode="numeric" min="1" max="10" name="preyCount" value="${draft.preyCount}">`)}
        ${field("Prey weight (g)", h`<input type="number" inputmode="decimal" min="0" step="any" name="preyWeightGrams" value="${draft.preyWeightGrams ?? ""}" placeholder="Optional">`)}
      </div>
      ${record ? "" : h`<h2>Snake</h2><div class="card">${field("Snake weight (g)", h`<input type="number" inputmode="decimal" min="0" step="any" name="snakeWeight" placeholder="${snake.weightGrams ? formatWeight(snake.weightGrams) : "Optional"}">`)}</div>
        <p class="footnote">Updates ${snake.name}'s current weight.</p>`}
      <h2>Notes</h2>
      <div class="card"><label class="field stack"><textarea name="notes" placeholder="Strike, regurge, shed status…">${draft.notes}</textarea></label></div>
      ${record ? h`<div class="card" style="margin-top:24px"><button type="button" class="link-btn danger" id="delete-feeding">Delete Feeding</button></div>` : ""}`,
    onSubmit: async (f) => {
      // Keep the original time of day when only the date changes.
      const picked = f.date.value;
      draft.date = picked === toDateInput(draft.date) ? draft.date : picked === todayInput() ? now() : fromDateInput(picked);
      Object.assign(draft, {
        refused: f.refused.checked,
        preyType: f.preyType.value,
        preySize: f.preySize.value,
        preyState: f.preyState.value,
        preyCount: Math.min(10, Math.max(1, Number(f.preyCount.value) || 1)),
        preyWeightGrams: f.preyWeightGrams.value ? Number(f.preyWeightGrams.value) : null,
        notes: f.notes.value,
      });
      await save("feedings", draft);
      if (!record && f.snakeWeight.value) await logWeight(snake, Number(f.snakeWeight.value), draft.date);
      toast(draft.refused ? "Refusal logged" : "Feeding logged");
      refresh();
    },
  });
  document.getElementById("delete-feeding")?.addEventListener("click", async () => {
    if (!confirmAction("Delete this feeding record?")) return;
    await remove("feedings", record.id);
    closeSheet();
    refresh();
  });
}

function feedingView() {
  const rank = { overdue: 0, due: 1, none: 2, fed: 3 };
  const snakes = M.sortedSnakes().filter(M.isInCollection).sort((a, b) =>
    rank[M.feedingStatus(a)] - rank[M.feedingStatus(b)] || (M.nextFeeding(a) ?? "").localeCompare(M.nextFeeding(b) ?? ""));
  if (!snakes.length) return h`${topbar("Feeding")}<div class="empty"><div class="big">🍽</div><p>Nothing to feed yet. Add snakes in the Collection tab.</p></div>`;
  return h`${topbar("Feeding")}
    <div class="card">${snakes.map((snake) => {
      const status = M.feedingStatus(snake);
      const meal = M.lastMeal(snake);
      const streak = M.refusalStreak(snake);
      return h`<div class="row">
        <a href="#/snake/${snake.id}">${thumb(snake, "sm")}</a>
        <a class="grow" href="#/snake/${snake.id}" style="color:inherit">
          <div class="name">${snake.name}</div>
          ${meal ? h`<div class="tiny">${M.feedingSummary(meal)} · ${daysAgo(meal.date)}</div>` : ""}
          ${streak ? h`<div class="tiny warn">${plural(streak, "refusal")} in a row</div>` : ""}
        </a>
        <span class="badge status-${status} bg-${status}">${M.FEEDING_STATUS_LABEL[status]}</span>
        <button class="btn secondary" style="min-height:36px;padding:0 12px" data-action="log-feeding" data-id="${snake.id}" aria-label="Log feeding for ${snake.name}">Log</button>
      </div>`;
    })}</div>`;
}

// MARK: - Concerns

function concernForm(snake, concern) {
  const draft = concern ? structuredClone(concern) : {
    id: newID(), snakeID: snake.id, title: "", details: "", category: "Other", severity: "Low",
    dateNoted: now(), isResolved: false, resolvedDate: null, vetVisit: false,
  };
  openSheet({
    title: concern ? "Concern" : "New Concern",
    body: h`
      <div class="card" style="margin-top:12px">
        <label class="field stack"><input name="title" value="${draft.title}" placeholder="What's going on?"></label>
        ${field("Category", h`<select name="category">${options(M.CONCERN_CATEGORIES.map((c) => [c, c]), draft.category)}</select>`)}
        <div class="field"><span>Severity</span><div class="segmented">${Object.keys(M.SEVERITIES).map((s) => h`<label><input type="radio" name="severity" value="${s}" ${s === draft.severity ? "checked" : ""}>${s}</label>`)}</div></div>
        ${field("Noticed", h`<input type="date" name="dateNoted" max="${todayInput()}" value="${toDateInput(draft.dateNoted)}">`)}
      </div>
      <h2>Details</h2>
      <div class="card">
        <label class="field stack"><textarea name="details" placeholder="Symptoms, treatment, follow-up">${draft.details}</textarea></label>
        ${field("Vet visit", h`<input type="checkbox" name="vetVisit" ${draft.vetVisit ? "checked" : ""}>`)}
      </div>
      <div class="card" style="margin-top:12px">
        ${field("Resolved", h`<input type="checkbox" name="isResolved" ${draft.isResolved ? "checked" : ""}>`)}
        ${field("Resolved on", h`<input type="date" name="resolvedDate" max="${todayInput()}" value="${toDateInput(draft.resolvedDate ?? now())}">`)}
      </div>
      ${concern ? h`<div class="card" style="margin-top:24px"><button type="button" class="link-btn danger" id="delete-concern">Delete Concern</button></div>` : ""}`,
    onSubmit: async (f) => {
      const title = f.title.value.trim();
      if (!title) { toast("Describe the concern first."); return false; }
      const noted = f.dateNoted.value === toDateInput(draft.dateNoted) ? draft.dateNoted : fromDateInput(f.dateNoted.value) ?? now();
      let resolvedDate = null;
      if (f.isResolved.checked) {
        resolvedDate = fromDateInput(f.resolvedDate.value) ?? now();
        if (resolvedDate < noted) resolvedDate = noted;
      }
      Object.assign(draft, {
        title, category: f.category.value, severity: f.severity.value, dateNoted: noted, details: f.details.value,
        vetVisit: f.vetVisit.checked, isResolved: f.isResolved.checked, resolvedDate,
      });
      await save("concerns", draft);
      refresh();
    },
  });
  document.getElementById("delete-concern")?.addEventListener("click", async () => {
    if (!confirmAction("Delete this concern?")) return;
    await remove("concerns", concern.id);
    closeSheet();
    refresh();
  });
}

// MARK: - Photos

async function addPhotos(snake) {
  const files = await pickFile("image/*", { multiple: true });
  if (!files.length) return;
  toast(`Adding ${plural(files.length, "photo")}…`);
  const records = [];
  for (const file of files) {
    try {
      records.push({
        id: newID(), snakeID: snake.id, dateTaken: file.lastModified ? new Date(file.lastModified).toISOString() : now(),
        caption: "", isCover: false, image: await resizeImage(file, 2048, 0.8), thumbnail: await resizeImage(file, 300, 0.7),
      });
    } catch (error) {
      console.error(error);
      toast(`Couldn't read ${file.name}`);
    }
  }
  await save("photos", records);
  if (records.length) toast(`Added ${plural(records.length, "photo")}`);
  refresh();
}

function photoViewer(photo) {
  const snake = M.snakeByID(photo.snakeID);
  openSheet({
    title: snake?.name ?? "Photo",
    cancelLabel: "Close",
    submitLabel: "Save",
    body: h`
      <img class="photo-full" style="margin-top:12px" src="data:image/jpeg;base64,${photo.image}" alt="${photo.caption}">
      <div class="card" style="margin-top:12px">
        <label class="field stack"><input name="caption" value="${photo.caption}" placeholder="Caption"></label>
        ${field("Taken", h`<input type="date" name="dateTaken" value="${toDateInput(photo.dateTaken)}">`)}
      </div>
      <div class="card" style="margin-top:12px">
        <button type="button" class="link-btn" id="photo-cover">${photo.isCover ? "★ Cover photo" : "☆ Set as Cover"}</button>
        <button type="button" class="link-btn" id="photo-share">Share / Save Image</button>
        <button type="button" class="link-btn danger" id="photo-delete">Delete Photo</button>
      </div>`,
    onSubmit: async (f) => {
      const dateTaken = f.dateTaken.value === toDateInput(photo.dateTaken) ? photo.dateTaken : fromDateInput(f.dateTaken.value) ?? photo.dateTaken;
      await save("photos", { ...photo, caption: f.caption.value, dateTaken });
      refresh();
    },
  });
  document.getElementById("photo-cover").addEventListener("click", async () => {
    const changed = M.photosFor(snake).filter((p) => p.isCover !== (p.id === photo.id)).map((p) => ({ ...p, isCover: p.id === photo.id }));
    await save("photos", changed);
    closeSheet();
    refresh();
  });
  document.getElementById("photo-share").addEventListener("click", async () => {
    const blob = await (await fetch(`data:image/jpeg;base64,${photo.image}`)).blob();
    await shareFiles([new File([blob], `${snake?.name ?? "snake"}.jpg`, { type: "image/jpeg" })]);
  });
  document.getElementById("photo-delete").addEventListener("click", async () => {
    if (!confirmAction("Delete this photo?")) return;
    await remove("photos", photo.id);
    closeSheet();
    refresh();
  });
}

// MARK: - Pairings

function pairingsView() {
  const seasons = [...new Set(data.pairings.map((p) => p.season))].sort((a, b) => b - a);
  return h`${topbar("Pairings", { action: h`<button class="icon-btn" data-action="add-pairing" aria-label="New pairing">＋</button>` })}
    <div class="card"><a class="row chevron" href="#/finder"><span class="grow">🔎 Pairing Finder</span></a></div>
    <p class="footnote">Rank every possible pairing in your collection by the odds of producing a target gene.</p>
    ${seasons.length ? seasons.map((season) => h`
      <h2>${season}</h2>
      <div class="card">${data.pairings.filter((p) => p.season === season).sort((a, b) => b.createdAt.localeCompare(a.createdAt)).map((p) => {
        const hatch = M.estimatedHatch(p);
        return h`<a class="row chevron" href="#/pairing/${p.id}">
          <span style="width:28px;text-align:center;${M.isActivePairing(p) ? "" : "filter:grayscale(1);opacity:.6"}">${M.PAIRING_STATUSES[p.status] ?? ""}</span>
          <div class="grow"><div class="name">${M.pairingTitle(p)}</div><div class="tiny">${M.pairingSpecies(p)} · ${p.status}</div>
          ${hatch && p.status === "Eggs laid / born" ? h`<div class="tiny accent">Est. hatch ${formatDate(hatch)}</div>` : ""}</div>
        </a>`;
      })}</div>`)
      : h`<div class="empty"><div class="big">♥</div><p><strong>No pairings planned</strong><br>Plan a pairing, or use the Pairing Finder.</p></div>`}`;
}

function pairingView(id) {
  const p = M.pairingByID(id);
  if (!p) return notFound("Pairing");
  const cat = M.catalog();
  const female = M.snakeByID(p.femaleID), male = M.snakeByID(p.maleID);
  const row = (label, iso) => (iso ? h`<div class="row"><span class="grow">${label}</span><span class="value">${formatDate(iso)}</span></div>` : "");
  const lay = M.estimatedLay(p), hatch = M.estimatedHatch(p);
  return h`${topbar(M.pairingTitle(p), { back: { href: "#/pairings", label: "Pairings" }, action: h`<button class="icon-btn" style="font-size:17px" data-action="edit-pairing" data-id="${p.id}">Edit</button>` })}
    <div class="card">${[female, male].filter(Boolean).map((s) => snakeRow(s))}</div>
    <h2>Progress</h2>
    <div class="card">
      <div class="row"><span class="grow">Status</span><span>${M.PAIRING_STATUSES[p.status] ?? ""} ${p.status}</span></div>
      ${row("Introduced", p.introducedDate)}
      ${p.lockCount ? h`<div class="row"><span class="grow">Locks</span><span class="value">${p.lockCount}</span></div>` : ""}
      ${row("Last lock", p.lastLockDate)}${row("Ovulation", p.ovulationDate)}${row("Pre-lay shed", p.preLayShedDate)}
      ${lay ? h`<div class="row"><span class="grow">Est. lay</span><span class="value">~${formatDate(lay)}</span></div>` : ""}
      ${row("Laid / born", p.layDate)}
      ${p.eggCount != null ? h`<div class="row"><span class="grow">Clutch</span><span class="value">${p.fertileEggCount != null ? `${p.fertileEggCount} good of ${p.eggCount}` : p.eggCount}</span></div>` : ""}
      ${hatch && !p.hatchDate ? h`<div class="row"><span class="grow">Est. hatch</span><span class="value">~${formatDate(hatch)}</span></div>` : ""}
      ${row("Hatched", p.hatchDate)}
    </div>
    ${(() => {
      const babies = female && male ? M.sortedSnakes().filter((s) => s.damID === female.id && s.sireID === male.id) : [];
      return h`<h2>Hatchlings${babies.length ? ` (${babies.length})` : ""}</h2>
        <div class="card">${babies.map((s) => snakeRow(s))}
          ${female && male ? h`<button class="link-btn" data-action="add-hatchling" data-id="${p.id}">⊕ Add Hatchling</button>` : h`<div class="row sub">Choose both parents to add hatchlings.</div>`}
        </div>`;
    })()}
    ${female && male ? h`<h2>Predicted Offspring</h2><div class="card">${outcomeList(cat.cross(female.traits, male.traits), p.fertileEggCount ?? p.eggCount)}</div>` : ""}
    ${p.notes ? h`<h2>Notes</h2><div class="card"><div class="row" style="white-space:pre-wrap">${p.notes}</div></div>` : ""}
    <div class="card" style="margin-top:24px"><button class="link-btn danger" data-action="delete-pairing" data-id="${p.id}">Delete Pairing</button></div>`;
}

function pairingForm(pairing, preset = {}) {
  const draft = pairing ? structuredClone(pairing) : {
    id: newID(), createdAt: now(), femaleID: preset.femaleID ?? null, maleID: preset.maleID ?? null,
    season: new Date().getFullYear(), status: "Planned", introducedDate: null, lockCount: 0, lastLockDate: null,
    ovulationDate: null, preLayShedDate: null, layDate: null, eggCount: null, fertileEggCount: null, hatchDate: null, notes: "",
  };
  const snakes = M.sortedSnakes();
  const dateField = (label, name) => field(label, h`<input type="date" name="${name}" value="${toDateInput(draft[name])}">`);
  const form = openSheet({
    title: pairing ? "Edit Pairing" : "New Pairing",
    body: h`
      <h2>Pair</h2>
      <div class="card">
        ${field("♀ Female", h`<select name="femaleID"></select>`)}
        ${field("♂ Male", h`<select name="maleID"></select>`)}
        ${field("Season", h`<input type="number" inputmode="numeric" name="season" min="2000" max="2100" value="${draft.season}">`)}
      </div>
      <h2>Progress</h2>
      <div class="card">
        ${field("Status", h`<select name="status">${options(Object.keys(M.PAIRING_STATUSES).map((s) => [s, `${M.PAIRING_STATUSES[s]} ${s}`]), draft.status)}</select>`)}
        ${dateField("Introduced", "introducedDate")}
        ${field("Locks observed", h`<input type="number" inputmode="numeric" min="0" max="100" name="lockCount" value="${draft.lockCount}">`)}
        ${dateField("Last lock", "lastLockDate")}${dateField("Ovulation", "ovulationDate")}${dateField("Pre-lay shed", "preLayShedDate")}
      </div>
      <h2>Clutch</h2>
      <div class="card">
        ${dateField("Laid / born", "layDate")}
        ${field("Eggs / babies", h`<input type="number" inputmode="numeric" min="0" name="eggCount" value="${draft.eggCount ?? ""}" placeholder="–">`)}
        ${field("Good / fertile", h`<input type="number" inputmode="numeric" min="0" name="fertileEggCount" value="${draft.fertileEggCount ?? ""}" placeholder="–">`)}
        ${dateField("Hatched", "hatchDate")}
      </div>
      <h2>Notes</h2>
      <div class="card"><label class="field stack"><textarea name="notes">${draft.notes}</textarea></label></div>`,
    onSubmit: async (f) => {
      if (!f.femaleID.value || !f.maleID.value) { toast("Choose a female and a male."); return false; }
      const num = (v) => (v === "" ? null : Number(v));
      const date = (name) => (f[name].value === toDateInput(draft[name]) ? draft[name] : fromDateInput(f[name].value));
      Object.assign(draft, {
        femaleID: f.femaleID.value, maleID: f.maleID.value, season: Number(f.season.value) || new Date().getFullYear(),
        status: f.status.value, lockCount: Number(f.lockCount.value) || 0, eggCount: num(f.eggCount.value),
        fertileEggCount: num(f.fertileEggCount.value), notes: f.notes.value,
      });
      for (const name of ["introducedDate", "lastLockDate", "ovulationDate", "preLayShedDate", "layDate", "hatchDate"]) draft[name] = date(name);
      await save("pairings", draft);
      if (!pairing) location.hash = `#/pairing/${draft.id}`;
      refresh();
    },
  });
  // Each list only offers snakes of the other one's species.
  const fill = () => {
    const female = M.snakeByID(form.femaleID.value || draft.femaleID);
    const male = M.snakeByID(form.maleID.value || draft.maleID);
    const pick = (sex, other, selected) => h`<option value="">Choose…</option>${snakes
      .filter((s) => s.sex === sex && (!other || s.species === other.species) && (M.isInCollection(s) || s.id === selected))
      .map((s) => h`<option value="${s.id}" ${s.id === selected ? "selected" : ""}>${s.name}</option>`)}`.html;
    form.femaleID.innerHTML = pick("female", male, female?.id);
    form.maleID.innerHTML = pick("male", female, male?.id);
  };
  form.femaleID.addEventListener("change", fill);
  form.maleID.addEventListener("change", fill);
  fill();
}

function previewView(femaleID, maleID) {
  const female = M.snakeByID(femaleID), male = M.snakeByID(maleID);
  if (!female || !male) return notFound("Pairing");
  const cat = M.catalog();
  return h`${topbar(`${female.name} × ${male.name}`, { back: { href: "javascript:history.back()", label: "Back" } })}
    <div class="card">
      <div class="row"><span class="grow">♀ ${female.name}</span><span class="value">${cat.describe(female.traits)}</span></div>
      <div class="row"><span class="grow">♂ ${male.name}</span><span class="value">${cat.describe(male.traits)}</span></div>
    </div>
    <h2>Possible Offspring</h2>
    <div class="card">${outcomeList(cat.cross(female.traits, male.traits))}</div>
    <div class="card" style="margin-top:16px"><button class="link-btn" data-action="plan-pairing" data-female="${female.id}" data-male="${male.id}">📅 Plan This Pairing</button></div>`;
}

function finderView() {
  const cat = M.catalog();
  const f = ui.finder;
  afterRender.push(() => {
    document.getElementById("finder-species").addEventListener("change", (e) => { f.species = e.target.value; f.geneID = ""; refresh(); });
    document.getElementById("finder-gene").addEventListener("change", (e) => { f.geneID = e.target.value; refresh(); });
  });
  let matches = [];
  if (f.geneID) {
    const females = data.snakes.filter((s) => s.species === f.species && s.sex === "female" && M.isInCollection(s));
    const males = data.snakes.filter((s) => s.species === f.species && s.sex === "male" && M.isInCollection(s));
    for (const female of females) {
      for (const male of males) {
        try {
          const p = cat.calculator.probabilityOfExpressing(f.geneID, female.traits, male.traits);
          if (p > 0) matches.push({ female, male, p });
        } catch { /* invalid genes on one snake */ }
      }
    }
    matches.sort((a, b) => b.p - a.p);
  }
  return h`${topbar("Pairing Finder", { back: { href: "#/pairings", label: "Pairings" } })}
    <div class="card">
      ${field("Species", h`<select id="finder-species">${options(cat.speciesNames.map((s) => [s, s]), f.species)}</select>`)}
      ${field("Target gene", h`<select id="finder-gene"><option value="">Choose…</option>${options(cat.genesFor(f.species).map((g) => [g.id, g.name]), f.geneID)}</select>`)}
    </div>
    <p class="footnote">Odds that a baby visually shows the gene, alone or in a combo.</p>
    ${f.geneID ? h`<h2>Best pairings</h2><div class="card">${matches.length ? matches.map((m) => h`
      <a class="row chevron" href="#/preview/${m.female.id}/${m.male.id}">
        <div class="grow"><div>${m.female.name} × ${m.male.name}</div><div class="tiny ellipsis">${cat.describe(m.female.traits)} × ${cat.describe(m.male.traits)}</div></div>
        <span class="name">${Percent.format(m.p)}</span>
      </a>`) : h`<div class="row sub">No pairing in your collection can produce this gene visually.</div>`}</div>` : ""}`;
}

// MARK: - Genetics calculator

function geneticsView() {
  const cat = M.catalog();
  const c = ui.calc;
  afterRender.push(() => {
    const results = document.getElementById("results");
    const drawResults = () => { results.innerHTML = outcomeList(cat.cross(c.female, c.male), c.clutch).html; };
    const female = mountTraits(document.getElementById("female-traits"), { traits: c.female, species: c.species, onChange: () => { drawResults(); morphs(); } });
    const male = mountTraits(document.getElementById("male-traits"), { traits: c.male, species: c.species, onChange: () => { drawResults(); morphs(); } });
    const morphs = () => {
      document.getElementById("female-morph").textContent = cat.describe(c.female);
      document.getElementById("male-morph").textContent = cat.describe(c.male);
    };
    document.getElementById("calc-species").addEventListener("change", (e) => {
      c.species = e.target.value;
      c.female.length = 0; c.male.length = 0; c.femaleName = c.maleName = null;
      refresh();
    });
    document.getElementById("calc-clutch").addEventListener("input", (e) => { c.clutch = Math.max(1, Number(e.target.value) || 1); drawResults(); });
    for (const [sex, editor] of [["female", female], ["male", male]]) {
      document.getElementById(`load-${sex}`)?.addEventListener("change", (e) => {
        const snake = M.snakeByID(e.target.value);
        if (!snake) return;
        c[sex].splice(0, c[sex].length, ...structuredClone(snake.traits ?? []));
        c[`${sex}Name`] = snake.name;
        refresh();
      });
      editor.redraw();
    }
    drawResults();
    morphs();
  });

  const parent = (sex, title) => {
    const candidates = M.sortedSnakes().filter((s) => s.species === c.species && (s.sex === sex || s.sex === "unknown") && M.isInCollection(s));
    return h`
      <div class="section-head"><h2>${title}${c[`${sex}Name`] ? `: ${c[`${sex}Name`]}` : ""}</h2>
        ${candidates.length ? h`<select id="load-${sex}" aria-label="Load ${sex} from collection"><option value="">From Collection…</option>${candidates.map((s) => h`<option value="${s.id}">${s.name}</option>`)}</select>` : ""}
      </div>
      <div class="card" id="${sex}-traits"></div>
      <p class="footnote" id="${sex}-morph"></p>`;
  };

  return h`${topbar("Genetics", { action: h`<button class="icon-btn" style="font-size:17px" data-action="reset-calc">Reset</button>` })}
    <div class="card">${field("Species", h`<select id="calc-species">${options(cat.speciesNames.map((s) => [s, s]), c.species)}</select>`)}</div>
    ${parent("female", "♀ Female")}
    ${parent("male", "♂ Male")}
    <h2>Possible Offspring</h2>
    <div class="card">
      ${field("Clutch size", h`<input id="calc-clutch" type="number" inputmode="numeric" min="1" max="40" value="${c.clutch}">`)}
      <div id="results"></div>
    </div>
    <p class="footnote">Odds are per egg; every egg is an independent roll. Health notes are commonly reported issues, not a diagnosis.</p>`;
}

// MARK: - Settings

function settingsView() {
  afterRender.push(async () => {
    const estimate = await db.storageEstimate();
    const el = document.getElementById("storage-usage");
    if (el && estimate) el.textContent = `${formatBytes(estimate.usage)}${estimate.persisted ? " · protected" : ""}`;
  });
  const customs = [...data.customGenes].sort((a, b) => a.name.localeCompare(b.name));
  const p = M.profile();
  return h`${topbar("Settings")}
    <div class="card"><a class="row chevron" href="#/profile">
      ${p.photo ? h`<img class="thumb" src="data:image/jpeg;base64,${p.photo}" alt="">` : h`<div class="thumb" aria-hidden="true">👤</div>`}
      <div class="grow"><div class="name">${M.breederName() || "Your Profile"}</div><div class="tiny">${p.business && p.name ? `${p.name} · ` : ""}${p.location || "Breeder name, contact details and defaults"}</div></div>
    </a></div>

    <h2>Storage</h2>
    <div class="card">
      <div class="row"><span class="grow">Snakes</span><span class="value">${data.snakes.length}</span></div>
      <div class="row"><span class="grow">Feedings</span><span class="value">${data.feedings.length}</span></div>
      <div class="row"><span class="grow">Care log entries</span><span class="value">${data.logs.length}</span></div>
      <div class="row"><span class="grow">Photos</span><span class="value">${data.photos.length}</span></div>
      <div class="row"><span class="grow">Pairings</span><span class="value">${data.pairings.length}</span></div>
      <div class="row"><span class="grow">On this device</span><span class="value" id="storage-usage">…</span></div>
      ${ui.lastSaved ? h`<div class="row"><span class="grow">Last saved</span><span class="value">${formatTime(ui.lastSaved)}</span></div>` : ""}
      ${ui.saveError ? h`<div class="row error tiny">⚠︎ ${ui.saveError}</div>` : ""}
    </div>
    <p class="footnote">Saved in this browser as soon as you make a change. Clearing Safari's website data deletes it, so sync or export now and then.</p>

    <h2>Sync with the iPad app</h2>
    <div class="card">
      <button class="link-btn" data-action="sync-export">⇪ Export Sync File</button>
      <button class="link-btn" data-action="sync-import">⇩ Import &amp; Merge Sync File</button>
    </div>
    <p class="footnote">Export here and import in the other SnakeKeeper app (or the other way round). Records are matched, and the newest version of each one wins, so you can sync in either direction as often as you like. Includes photos, the care log and your profile.</p>

    <h2>Export</h2>
    <div class="card">
      <button class="link-btn" data-action="export-xlsx" ${data.snakes.length || data.pairings.length ? "" : "disabled"}>▦ Excel Workbook (.xlsx)</button>
      <button class="link-btn" data-action="export-csv" ${data.snakes.length || data.pairings.length ? "" : "disabled"}>≡ CSV Files</button>
    </div>
    <p class="footnote">The workbook has Snakes, Feedings, Care Log, Concerns and Pairings tabs. Open it in Excel or Numbers, or in Google Sheets: share it to the Sheets app, or save it to Google Drive and open it from there.</p>

    <h2>Custom Genes</h2>
    <div class="card">
      ${customs.map((g) => h`<button class="row" data-action="edit-gene" data-id="${g.id}"><div class="grow"><div>${g.name}</div><div class="tiny">${g.species} · ${INHERITANCE[g.inheritance]}</div></div></button>`)}
      <button class="link-btn" data-action="add-gene">⊕ Add Custom Gene</button>
    </div>
    <p class="footnote">Add morphs that aren't built in, or genes for other species. Snakes using a deleted gene will show it as unknown.</p>

    <h2>Built-in Library</h2>
    <div class="card">${SPECIES.map((s) => h`<a class="row chevron" href="#/library/${encodeURIComponent(s.name)}"><span class="grow">${s.name}</span><span class="value">${s.genes.length} genes</span></a>`)}</div>`;
}

function libraryView(name) {
  const species = M.speciesInfo(name);
  if (!species) return notFound("Species");
  return h`${topbar(species.name, { back: { href: "#/settings", label: "Settings" } })}
    ${Object.entries(INHERITANCE).map(([key, label]) => {
      const genes = species.genes.filter((g) => g.inheritance === key);
      if (!genes.length) return "";
      return h`<h2>${label}</h2><div class="card">${genes.map((g) => {
        const allelic = species.genes.filter((o) => o.locus === g.locus && o.id !== g.id);
        return h`<div class="row"><div class="grow"><div>${g.name}</div>
          ${key !== "recessive" ? h`<div class="tiny">Two copies: ${homozygousName(g)}</div>` : ""}
          ${allelic.length ? h`<div class="tiny">Allelic with ${allelic.map((a) => a.name).join(", ")}</div>` : ""}
          ${[g.warning, g.homozygousWarning].filter(Boolean).map((w) => h`<div class="tiny warn">⚠︎ ${w}</div>`)}
        </div></div>`;
      })}</div>`;
    })}`;
}

function geneForm(gene) {
  const cat = M.catalog();
  const draft = gene ? structuredClone(gene) : { id: newID(), name: "", species: SPECIES[0].name, inheritance: "recessive", superName: "", locus: "", warning: "" };
  const ownID = `custom.${draft.id}`;
  const form = openSheet({
    title: gene ? "Edit Gene" : "New Gene",
    body: h`
      <div class="card" style="margin-top:12px">
        ${field("Gene name", h`<input name="name" value="${draft.name}" placeholder="Required">`)}
        ${field("Species", h`<select name="species">${options(cat.speciesNames.map((s) => [s, s]), draft.species)}</select>`)}
        <label class="field" id="new-species-row" hidden><span>Species name</span><input name="newSpecies" placeholder="e.g. Kingsnake"></label>
        ${field("Inheritance", h`<select name="inheritance">${options(Object.entries(INHERITANCE), draft.inheritance)}</select>`)}
        <label class="field" id="super-row"><span>Two-copy name</span><input name="superName" value="${draft.superName}" placeholder="Super …"></label>
      </div>
      <div class="card" style="margin-top:12px">${field("Allelic with", h`<select name="locus"></select>`)}</div>
      <p class="footnote">Pick a gene this one shares a locus with, like Lesser and Mojave. Leave as None if unsure.</p>
      <h2>Health note</h2>
      <div class="card"><label class="field stack"><input name="warning" value="${draft.warning}" placeholder="e.g. wobble, kinking"></label></div>
      ${gene ? h`<div class="card" style="margin-top:24px"><button type="button" class="link-btn danger" id="delete-gene">Delete Gene</button></div>` : ""}`,
    onSubmit: async (f) => {
      const name = f.name.value.trim();
      if (!name) { toast("Give the gene a name."); return false; }
      const newSpecies = f.newSpecies.value.trim();
      Object.assign(draft, {
        name,
        species: f.species.value === M.OTHER_SPECIES && newSpecies ? newSpecies : f.species.value,
        inheritance: f.inheritance.value,
        superName: f.inheritance.value === "recessive" ? "" : f.superName.value.trim(),
        locus: f.locus.value,
        warning: f.warning.value.trim(),
      });
      await save("customGenes", draft);
      refresh();
    },
  });
  const update = () => {
    form.querySelector("#new-species-row").hidden = form.species.value !== M.OTHER_SPECIES;
    form.querySelector("#super-row").hidden = form.inheritance.value === "recessive";
    const current = form.locus.value || draft.locus;
    form.locus.innerHTML = h`<option value="">None (own locus)</option>${M.catalog().genesFor(form.species.value)
      .filter((g) => g.id !== ownID)
      .map((g) => h`<option value="${g.locus}" ${g.locus === current ? "selected" : ""}>${g.name}</option>`)}`.html;
  };
  form.species.addEventListener("change", update);
  form.inheritance.addEventListener("change", update);
  update();
  document.getElementById("delete-gene")?.addEventListener("click", async () => {
    if (!confirmAction(`Delete ${gene.name}? Snakes using it will show it as unknown.`)) return;
    await remove("customGenes", gene.id);
    closeSheet();
    refresh();
  });
}

// MARK: - Export & sync

const stamp = () => new Date().toISOString().slice(0, 10);
const filePrefix = () => (M.breederName() ? `${M.breederName().replace(/[\\/:*?"<>|]/g, "")} SnakeKeeper` : "SnakeKeeper");

async function exportWorkbook() {
  const blob = xlsxBlob(workbookSheets());
  await shareFiles([new File([blob], `${filePrefix()} ${stamp()}.xlsx`, { type: blob.type })]);
}

async function exportCSVs() {
  const files = workbookSheets().map((sheet) => new File([csv(sheet)], `${filePrefix()} ${sheet.name} ${stamp()}.csv`, { type: "text/csv" }));
  await shareFiles(files);
}

async function exportSync() {
  const text = JSON.stringify(buildSyncFile(data, "web"));
  await shareFiles([new File([text], `${filePrefix()} Sync ${stamp()}.json`, { type: "application/json" })]);
}

async function importSync() {
  const [file] = await pickFile(".json,application/json");
  if (!file) return;
  try {
    const incoming = parseSyncFile(await file.text());
    const plan = planMerge(data, incoming);
    await db.applyMerge(plan);
    // Children of snakes deleted on the other device.
    const alive = new Set(data.snakes.map((s) => s.id));
    for (const store of ["feedings", "logs", "concerns", "photos"]) {
      await db.remove(store, data[store].filter((r) => !alive.has(r.snakeID)).map((r) => r.id), { tombstone: false });
    }
    ui.lastSaved = now();
    toast(`Synced: ${describeSummary(plan.summary)}`);
    refresh();
  } catch (error) {
    toast(error.message);
  }
}

// MARK: - Actions

const actions = {
  "add-snake": () => snakeForm(null),
  "start-select": () => { ui.selecting = true; ui.selected.clear(); refresh(); },
  "end-select": () => { ui.selecting = false; ui.selected.clear(); refresh(); },
  "toggle-select": ({ id }) => {
    if (ui.selected.has(id)) ui.selected.delete(id);
    else ui.selected.add(id);
    drawList();
  },
  "select-all": () => { ui.visibleIDs.forEach((id) => ui.selected.add(id)); drawList(); },
  "select-none": () => { ui.selected.clear(); drawList(); },
  "batch-edit": batchForm,
  "edit-snake": ({ id }) => snakeForm(M.snakeByID(id)),
  "delete-snake": async ({ id }) => {
    const snake = M.snakeByID(id);
    if (!confirmAction(`Delete ${snake.name}? This removes all feeding records, photos and concerns for this snake.`)) return;
    await deleteSnake(snake);
    toast(`Deleted ${snake.name}`);
    location.hash = "#/collection";
  },
  "log-feeding": ({ id }) => feedingForm(M.snakeByID(id)),
  "edit-feeding": ({ id }) => {
    const record = data.feedings.find((r) => r.id === id);
    feedingForm(M.snakeByID(record.snakeID), record);
  },
  "add-concern": ({ id }) => concernForm(M.snakeByID(id)),
  "log-care": ({ id, kind }) => logForm(M.snakeByID(id), null, kind),
  "edit-log": ({ id }) => {
    const entry = data.logs.find((l) => l.id === id);
    logForm(M.snakeByID(entry.snakeID), entry);
  },
  "add-hatchling": ({ id }) => {
    const p = M.pairingByID(id);
    const female = M.snakeByID(p.femaleID), male = M.snakeByID(p.maleID);
    snakeForm(null, {
      species: female?.species ?? male?.species, damID: p.femaleID, sireID: p.maleID,
      hatchDate: p.hatchDate ?? now(), origin: "homeBred", originDetails: `${p.season} clutch: ${M.pairingTitle(p)}`,
    });
  },
  "edit-profile": () => profileForm(),
  "edit-concern": ({ id }) => {
    const concern = data.concerns.find((c) => c.id === id);
    concernForm(M.snakeByID(concern.snakeID), concern);
  },
  "add-photos": ({ id }) => addPhotos(M.snakeByID(id)),
  "view-photo": ({ id }) => photoViewer(data.photos.find((p) => p.id === id)),
  "add-pairing": () => pairingForm(null),
  "edit-pairing": ({ id }) => pairingForm(M.pairingByID(id)),
  "plan-pairing": ({ female, male }) => pairingForm(null, { femaleID: female, maleID: male }),
  "delete-pairing": async ({ id }) => {
    if (!confirmAction("Delete this pairing?")) return;
    await remove("pairings", id);
    location.hash = "#/pairings";
  },
  "reset-calc": () => {
    const c = ui.calc;
    c.female.length = 0; c.male.length = 0; c.femaleName = c.maleName = null;
    refresh();
  },
  "add-gene": () => geneForm(null),
  "edit-gene": ({ id }) => geneForm(data.customGenes.find((g) => g.id === id)),
  "export-xlsx": exportWorkbook,
  "export-csv": exportCSVs,
  "sync-export": exportSync,
  "sync-import": importSync,
};

document.addEventListener("click", (event) => {
  const el = event.target.closest("[data-action]");
  if (!el || el.disabled) return;
  const action = actions[el.dataset.action];
  if (!action) return;
  event.preventDefault();
  Promise.resolve(action(el.dataset)).catch((error) => { console.error(error); toast(error.message); });
});

document.getElementById("sheet").addEventListener("close", () => { document.getElementById("sheet").innerHTML = ""; });
window.addEventListener("hashchange", () => {
  closeSheet();
  if (!location.hash.startsWith("#/collection")) { ui.selecting = false; ui.selected.clear(); }
  render();
  window.scrollTo(0, 0);
});

// MARK: - Start

try {
  await db.open();
  ui.calc.species = ui.finder.species = M.profile().defaultSpecies;
  render();
} catch (error) {
  console.error(error);
  app.innerHTML = h`<div class="empty"><div class="big">⚠︎</div><p><strong>Couldn't open saved data</strong><br>${error.message}</p>
    <p class="sub">Private Browsing blocks storage. Open SnakeKeeper in a normal Safari tab or from the home screen.</p></div>`.html;
}

if ("serviceWorker" in navigator && location.protocol === "https:") {
  navigator.serviceWorker.register("sw.js").catch(() => {});
}
