# HackApp — Database Migration Changes

## Overview

The original app stored all hackathon data (teams, judges, rubrics, grades, scores) as deeply nested dictionaries inside a single Firestore document. This caused data fetch failures, incorrect score calculations, and data consistency issues. We migrated to a normalized Firestore schema using subcollections and rewrote all data access logic.

---

## New Firestore Schema

```
hackathons/{hackathonId}
  keyCode:     String
  name:        String
  description: String
  isActive:    Bool
  isStarted:   Bool
  pitchTime:   Double
  startDate:   Timestamp
  endDate:     Timestamp
  maxScore:    Int

  /teams/{teamId}
    name: String

    /evaluations/{judgeDocId}
      judgeName:   String
      scores:      { criterionId: Double }
      notes:       String
      submittedAt: Timestamp

  /judges/{judgeId}
    name: String

  /rubricCriteria/{criterionId}
    name:   String
    weight: Double
```

**Old schema:** Everything nested inside one document under the `hacks` collection.  
**New schema:** Proper subcollections under the `hackathons` collection.

---

## Problems Fixed

### 1. Field Naming Inconsistency
- `fetchHacks()` queried capitalized keys: `"Equipos"`, `"Jueces"`, `"Rubros"`
- `fetchHack()` queried lowercase keys: `"equipos"`, `"jueces"`, `"rubros"`
- One of these silently returned empty data every time
- **Fix:** Standardized field names across the entire codebase using the new schema

### 2. Broken Score Calculation
- Old formula divided the sum of all scores by the total number of individual ratings across all judges and rubrics — mathematically incorrect
- **Fix:** For each rubric criterion, average the score across all judges independently, multiply by the criterion's weight percentage, then sum — correct weighted average

### 3. Non-Atomic Writes
- Creating a hackathon wrote the main document, then scores and notes were written in separate sequential operations — a failure mid-way left the DB in an inconsistent state
- **Fix:** Hackathon creation uses a Firestore batch write — hackathon document + all team, judge, and rubric documents are committed atomically

### 4. Everything Keyed by Name Strings
- Team names, judge names, and rubric names were used as dictionary keys throughout the nested structure — case-sensitive, no uniqueness enforcement, renaming broke everything
- **Fix:** Every entity has a Firestore-generated document ID (`firestoreId`) used for all lookups; names are display-only

### 5. Stale Cached Scores
- Final scores were calculated and written back to Firestore only when an admin opened `HackView` — results could be outdated
- **Fix:** Scores are calculated on-demand client-side when `ResultsView` opens, reading directly from evaluation subcollections

### 6. No Cascading Deletes
- Deleting a hackathon document left all subcollection data orphaned in Firestore
- **Fix:** `deleteHack()` now recursively deletes all subcollection documents before deleting the parent document

---

## Files Changed

### Models

| File | Change |
|------|--------|
| `HackModel.swift` | Removed all nested fields (`equipos`, `jueces`, `rubros`, `calificaciones`, `finalScores`, `notas`). Now only holds top-level hackathon fields. Added `id: String` as the Firestore document ID |
| `Juez.swift` | Added `firestoreId: String` to carry the Firestore document ID alongside the display name |
| `Equipo.swift` | Added `firestoreId: String` |
| `Rubro.swift` | Added `firestoreId: String` |
| `Evaluacion.swift` | Cleared — evaluations now live in Firestore subcollections |
| `Hack.swift` | Cleared — was an unused legacy SwiftData model |

### ViewModels

| File | Change |
|------|--------|
| `HacksViewModel.swift` | Full rewrite. Replaced all old methods with new ones targeting the `hackathons` collection and subcollections. Added: `getTeams`, `getJudges`, `getRubrics`, `saveEvaluation`, `getEvaluation`, `getEvaluationStatus`, `getTeamCalificaciones`, `saveNotes`, `getNotes`, `markNoShow`, `calculateAllScores`, `calculateScoresByCriterion`, `teamHasAnyEvaluation` |
| `HackViewModel.swift` | Updated all method signatures to use `hackId` (Firestore doc ID) instead of `hackClave` (key code string) |
| `TeamViewModel.swift` | Updated to take `hackId` and `teamId` instead of `HackModel` and team name. Now calls `getTeamCalificaciones` and `fetchRubros(hackId:)` |

### Views — Judge Flow

| File | Change |
|------|--------|
| `JudgesView.swift` | After fetching a hackathon by key code, stores `hackId` and `hackMaxScore`. Fetches judges as `[Juez]` with `firestoreId`. Passes `hackId`, `hackMaxScore`, and `judgeId` to `JudgeHomeView` |
| `JudgeHomeView.swift` | New parameters: `hackId`, `hackMaxScore`, `judgeId`. Fetches teams as `[Equipo]` with `firestoreId`. Uses `getEvaluationStatus(hackId:judgeId:)` keyed by team Firestore ID for checkmarks |
| `GradeView.swift` | New parameters: `hackId`, `hackMaxScore`, `team: Equipo`, `judgeId`. Sliders keyed by `rubro.firestoreId`. Saves evaluation via `saveEvaluation(hackId:teamId:judgeId:judgeName:scores:notes:)`. Checks prior submission via `getEvaluation(hackId:teamId:judgeId:)` |

### Views — Admin Flow

| File | Change |
|------|--------|
| `HackView.swift` | All DB operations now use `hack.id` (Firestore doc ID) instead of `hack.clave`. `selectedEquipos` changed from `[String]?` to `[Equipo]`. `jueces` changed to `[Juez]`. No-show button uses `markNoShow(hackId:teamId:)`. Team evaluation check uses `teamHasAnyEvaluation(hackId:teamId:)`. Save changes calls updated `updateHack(hackId:...)` signature |
| `ResultsView.swift` | Replaced `getScores` and `getCalificacionesPorCriterio` calls with `calculateAllScores(hackId:)` and `calculateScoresByCriterion(hackId:)`. Fetches `[Equipo]` list to resolve team names for `TeamView` navigation |
| `TeamView.swift` | Changed from `(hack: HackModel, equipoSeleccionado: String)` to `(hack: HackModel, equipo: Equipo)`. `TeamViewModel` initialized with `hackId` and `teamId` (Firestore doc IDs) |
| `AddHackForm.swift` | `validateAndSave()` now calls `addHack(nombre:clave:descripcion:fechaStart:fechaEnd:valorRubro:tiempoPitch:teams:judges:rubrics:)` instead of constructing a `HackModel` with nested data |
| `HackRow.swift` | `deleteHack(withKey:)` replaced with `deleteHack(hackId:)` |

---

## Firebase Console Setup

**Firestore Security Rules** (no authentication required):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /hackathons/{hackathonId} {
      allow read, write: if true;

      match /teams/{teamId} {
        allow read, write: if true;

        match /evaluations/{evaluationId} {
          allow read, write: if true;
        }
      }

      match /judges/{judgeId} {
        allow read, write: if true;
      }

      match /rubricCriteria/{criterionId} {
        allow read, write: if true;
      }
    }
  }
}
```

---

## What Was NOT Changed

- All UI layout and styling
- The 6-step hackathon creation form flow
- Judge UX (key code entry + name selection — no login required)
- Timer view, progress bar, step indicator components
- Font and asset files
- Firebase initialization in `HackApp.swift`
