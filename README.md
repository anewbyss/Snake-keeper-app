# SnakeKeeper

An app for snake breeders: track your collection, feedings, health concerns, photos and pairings,
and predict clutches with a built-in genetics calculator.

It comes in two versions that can sync with each other:

- **Web app** (`web/`): runs in Safari and installs on the home screen. No Mac, Xcode or Apple
  developer account needed.
- **Native iPad / iPhone app** (`App/`): SwiftUI + SwiftData, built with Xcode or Swift Playgrounds.

## Web app

**Install on iPad:** open the web app's address in Safari, tap **Share → Add to Home Screen**.
It gets its own icon, opens full screen and works offline. Data is stored on the device.

**Publishing (one time):** the repo publishes `web/` to GitHub Pages on every push to `main`
(`.github/workflows/pages.yml`). Turn it on in *Settings → Pages → Source: GitHub Actions*.
The address is `https://<owner>.github.io/<repo>/`. GitHub Pages for a private repo needs a paid
GitHub plan; otherwise make the repo public (only the code is public, never your data) or host the
`web/` folder anywhere that serves static files.

**Run locally:** `cd web && python3 -m http.server`, then open http://localhost:8000.
**Tests:** `node --test web/tests/*.test.mjs` (genetics engine and sync merge).

The gene list in `web/js/genes.js` is generated from the Swift library by
`scripts/make-web-genes.py`, so both apps always know the same genes.

## Syncing the two apps

Both apps have **Settings → Sync**:

1. In one app, **Export Sync File** and save it (e.g. to iCloud Drive / Files).
2. In the other app, **Import & Merge Sync File** and pick that file.

Each record keeps the newest version, deletions carry over, and photos are included. Do it in
both directions to bring both apps fully up to date. The format is described in [SYNC.md](SYNC.md).

## Native app

## Features

- **Collection**: species, name/ID, sex, hatch date (exact or estimated) with auto-calculated age,
  origin (bred by me / purchased / traded / rescue / wild caught) with breeder or locality details,
  acquired date, weight, genes and notes. Search and filter by species or sex.
- **Feeding**: log meals (prey type, size, F/T / pre-killed / live, count, weight) or refusals. Shows
  the last meal, next due date, refusal streaks and acceptance rate. The Feeding tab lists every
  snake by urgency (overdue, due, fed) and you can swipe to log a meal. New logs start with the
  snake's last meal filled in.
- **Health concerns**: category, severity, date noticed, details, vet visit flag, resolve/reopen.
  Snakes with open concerns get a warning badge.
- **Photos**: add from the library (several at once) or the camera, set a cover photo, caption,
  share or delete. Images are downscaled and kept in external storage.
- **Potential pairings**: each snake's page lists every opposite-sex snake of the same species with
  a preview of the predicted offspring. The **Pairing Finder** ranks every female × male pair in
  your collection by the odds of producing a chosen gene.
- **Pairing tracker**: planned → introduced → locks → ovulation → pre-lay shed → laid → hatched,
  with egg counts and estimated lay and hatch dates.
- **Genetics calculator**: pick species, load parents from your collection or enter genes by hand,
  and see every outcome with its percentage, expected count per clutch, het / possible-het odds and
  health notes (e.g. Spider wobble).
- **Export to Excel / Google Sheets**: Settings → Export creates an `.xlsx` workbook with Snakes,
  Feedings, Concerns and Pairings tabs, or one CSV per tab. Share it to Excel, Numbers, the Google
  Sheets app, Google Drive, Files, AirDrop or Mail.

## Genetics engine

`SnakeGenetics/` is a standalone Swift package with no UI dependencies, so it is unit-tested on its own.

- Recessive, incomplete dominant (co-dom) and dominant genes
- **Possible hets** on parents (e.g. 66% poss het Pied), with correct possible-het odds for offspring
- **Allelic genes** on a shared locus, with compound names: Lesser × Mojave → Blue Eyed Leucistic,
  Yellow Belly × Gravel → Highway, Amel × Ultra → Ultramel, and so on
- Any number of genes at once (e.g. a triple-het × triple-het cross gives all 8 groups)
- Built-in libraries for Ball Python (40+ genes), Corn Snake, Western Hognose and Boa
- Custom genes for any species (Settings tab), including allelic links and health notes

```swift
import SnakeGenetics

let calc = GeneticsCalculator(genes: GeneLibrary.allGenes)
let female = [TraitEntry(geneID: "bp.pastel", zygosity: .single),
              TraitEntry(geneID: "bp.clown", zygosity: .single)]   // Pastel het Clown
let male   = [TraitEntry(geneID: "bp.clown", zygosity: .double)]   // Clown
for outcome in try calc.cross(female, male) {
    print(outcome.fullName, Percent.format(outcome.probability))
}
// Clown 25%, Clown Pastel 25%, Normal het Clown 25%, Pastel het Clown 25%
```

## Building

Requires Xcode 15+ and iOS 17+.

**With XcodeGen (recommended)**

```sh
brew install xcodegen
git clone https://github.com/anewbyss/snake-keeper-app.git
cd snake-keeper-app
xcodegen
open SnakeKeeper.xcodeproj
```

**Manually**: in Xcode create a new iOS App called `SnakeKeeper` (SwiftUI, SwiftData storage),
delete the template's Swift files, drag in the `App/` folder, then use *File → Add Package
Dependencies… → Add Local…* to add the `SnakeGenetics` folder. Add `NSCameraUsageDescription` to
the Info tab if you want the camera button.

**On iPad with Swift Playgrounds (no Mac needed)**

`SnakeKeeper.swiftpm` is the same app packaged for Swift Playgrounds (4.4 or later, iPadOS 17+).

1. Install **Swift Playgrounds** from the App Store.
2. In Safari on the iPad, open
   https://github.com/anewbyss/snake-keeper-app/archive/refs/heads/main.zip (sign in first; the repo is private).
3. In the Files app, tap the ZIP to unzip it, then open `snake-keeper-app-main/SnakeKeeper.swiftpm`.
   It opens in Playgrounds.
4. Tap ▶ to run it.

To get a real home-screen icon from the iPad you need an Apple Developer Program membership
($99/year): in Playgrounds open *App Settings → App Store Connect → Upload to App Store Connect*,
then install the build with the TestFlight app (builds last 90 days). Without a membership, a
Shortcuts home-screen icon can open Swift Playgrounds, and you tap ▶ from there.

`SnakeKeeper.swiftpm` is generated. After changing `App/` or `SnakeGenetics/`, run
`scripts/make-playground.sh` to rebuild it.

**Run the genetics tests**

```sh
cd SnakeGenetics
swift test
```

## Layout

```
snake-keeper-app/
├── project.yml                 XcodeGen spec
├── App/
│   ├── SnakeKeeperApp.swift    entry point + tabs
│   ├── Models/                 SwiftData models (Snake, FeedingRecord, SnakePhoto, Concern, Pairing, CustomGene)
│   ├── Support/                gene catalog, formatting, images, spreadsheet export
│   └── Views/                  Collection, Feeding, Pairings, Genetics, Settings
├── SnakeGenetics/              Swift package: genes, library, calculator, tests
├── SnakeKeeper.swiftpm/        generated Swift Playgrounds app for iPad
└── scripts/make-playground.sh  regenerates SnakeKeeper.swiftpm
```

Health notes in the gene library are issues commonly reported in the hobby, not veterinary advice.
