# Sync file format

The iPad app (`App/Support/SyncFile.swift`) and the web app (`web/js/sync.js`) exchange one JSON file.
Change both sides together, and bump `version` for incompatible changes.

```json
{
  "format": "snakekeeper-sync",
  "version": 1,
  "app": "ios" | "web",
  "exportedAt": "2026-10-26T07:34:30.240Z",
  "customGenes": [{ "id", "updatedAt", "name", "species", "inheritance", "superName", "locus", "warning" }],
  "snakes": [{ "id", "updatedAt", "createdAt", "name", "species", "sex", "hatchDate", "hatchDateIsEstimate",
               "origin", "originDetails", "acquiredDate", "weightGrams", "feedingIntervalDays",
               "traits": [{ "geneID", "zygosity": "single" | "double" | "possibleHet", "probability" }], "notes" }],
  "feedings": [{ "id", "updatedAt", "snakeID", "date", "preyType", "preySize", "preyState", "preyCount",
                 "preyWeightGrams", "refused", "notes" }],
  "concerns": [{ "id", "updatedAt", "snakeID", "title", "details", "category", "severity", "dateNoted",
                 "isResolved", "resolvedDate", "vetVisit" }],
  "photos": [{ "id", "updatedAt", "snakeID", "dateTaken", "caption", "isCover", "image", "thumbnail" }],
  "pairings": [{ "id", "updatedAt", "createdAt", "femaleID", "maleID", "season", "status", "introducedDate",
                 "lockCount", "lastLockDate", "ovulationDate", "preLayShedDate", "layDate", "eggCount",
                 "fertileEggCount", "hatchDate", "notes" }],
  "deleted": [{ "id", "type": "snakes" | "feedings" | …, "deletedAt" }]
}
```

- **ids** are uppercase UUID strings. Custom gene ids in traits are `custom.<id>`.
- **Dates** are ISO 8601 (with or without fractional seconds). Missing optional fields mean "none".
- **Images** are base64 JPEG (full image ≤ 2048 px, thumbnail ≤ 300 px).
- Raw values (sex, origin, prey, category, severity, status, inheritance) are the native enums' raw values.

## Merge rules

1. A deletion ("tombstone") beats any version of the record that is not newer than the deletion.
2. Otherwise the record with the newer `updatedAt` wins; ties keep the local copy.
3. Feedings, concerns and photos whose snake doesn't exist are skipped (and cleaned up).

Because merging only ever keeps the newest data, importing the same file twice, or syncing in
either order, gives the same result.
