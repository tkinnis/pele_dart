# Upstream Tracking (`obsidianmd/pele`)

This document is the **single source of truth** for the upstream [`obsidianmd/pele`](https://github.com/obsidianmd/pele) release tag and commit SHA that `pele_dart` is pinned against, along with the per-module porting and sync status. Automated sync and differential verification scripts (`tool/sync_upstream.dart`, `tool/verify_against_upstream.dart`) read the pinned SHA directly from this file.

## Pinned Baseline

| Field | Value |
| :--- | :--- |
| **Upstream Repository** | `https://github.com/obsidianmd/pele` |
| **Upstream License** | MIT |
| **Target Release** | `v1.13.0` |
| **Target Commit SHA** | `3a2f075ee0c3d914f0fad3545fc0f193693975ac` |
| **Target Commit Date** | `2026-10-31T00:07:28Z` |

---

## Module Sync Matrix

Every file under `obsidianmd/pele/src/<path>.ts` maps 1:1 to `lib/src/<path>.dart` (with camelCase filenames converted to Dart `snake_case.dart`).

### Core Infrastructure

| Upstream Path (`src/`) | Dart Path (`lib/src/`) | Status | Synced Commit |
| :--- | :--- | :--- | :--- |
| `types.ts`, `models.ts`, `errors.ts` | `types.dart`, `errors.dart` | ✅ Ported | `3a2f075ee0c3d914f0fad3545fc0f193693975ac` |
| `detect.ts`, `preprocess.ts`, `core.ts`, `index.ts` | `detect.dart`, `preprocess.dart`, `core.dart`, `index.dart` | ✅ Ported | `3a2f075ee0c3d914f0fad3545fc0f193693975ac` |
| `util/{chars,unicode,url,yaml}.ts` | `util/{chars,unicode,url,yaml,math_js}.dart` | ✅ Ported | `3a2f075ee0c3d914f0fad3545fc0f193693975ac` |
| `text/{entities,icons,label,math,measurer,metrics}.ts` | `text/{entities,icons,label,math,measurer,metrics}.dart` | ✅ Ported | `3a2f075ee0c3d914f0fad3545fc0f193693975ac` |
| `layout/{components,compound,lanes,layered}.ts` | `layout/{components,compound,lanes,layered}.dart` | ✅ Ported | `3a2f075ee0c3d914f0fad3545fc0f193693975ac` |
| `svg/{builder,cluster,edges,ink,palette,root,shapes,theme,title}.ts` | `svg/{builder,cluster,edges,ink,palette,root,shapes,theme,title,flattener}.dart` | ✅ Ported | `3a2f075ee0c3d914f0fad3545fc0f193693975ac` |

### Diagram Modules (`src/diagrams/<type>/` -> `lib/src/diagrams/<type>/`)

| Diagram Family | Upstream Directory | Dart Directory | Phase | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Common Helpers** | `src/diagrams/common/` | `lib/src/diagrams/common/` | Phase 1 | ✅ Ported |
| **Flowchart** | `src/diagrams/flowchart/` | `lib/src/diagrams/flowchart/` | Phase 2 (Tier 1) | ✅ Ported |
| **Sequence** | `src/diagrams/sequence/` | `lib/src/diagrams/sequence/` | Phase 2 (Tier 1) | ✅ Ported |
| **Class** | `src/diagrams/class/` | `lib/src/diagrams/class/` | Phase 2 (Tier 1) | ✅ Ported |
| **State** | `src/diagrams/state/` | `lib/src/diagrams/state/` | Phase 2 (Tier 1) | ✅ Ported |
| **Entity-Relationship** | `src/diagrams/er/` | `lib/src/diagrams/er/` | Phase 2 (Tier 1) | ✅ Ported |
| **Gantt** | `src/diagrams/gantt/` | `lib/src/diagrams/gantt/` | Phase 2 (Tier 1) | ✅ Ported |
| **Git Graph** | `src/diagrams/git/` | `lib/src/diagrams/git/` | Phase 2 (Tier 1) | ✅ Ported |
| **Mindmap** | `src/diagrams/mindmap/` | `lib/src/diagrams/mindmap/` | Phase 2 (Tier 1) | ✅ Ported |
| **Pie** | `src/diagrams/pie/` | `lib/src/diagrams/pie/` | Phase 2 (Tier 1) | ✅ Ported |
| **Agentflow** | `src/diagrams/agentflow/` | `lib/src/diagrams/agentflow/` | Phase 3 (Tier 2) | ✅ Ported |
| **Architecture** | `src/diagrams/architecture/` | `lib/src/diagrams/architecture/` | Phase 3 (Tier 2) | ✅ Ported |
| **Block** | `src/diagrams/block/` | `lib/src/diagrams/block/` | Phase 3 (Tier 2) | ✅ Ported |
| **C4** | `src/diagrams/c4/` | `lib/src/diagrams/c4/` | Phase 3 (Tier 2) | ✅ Ported |
| **Cynefin** | `src/diagrams/cynefin/` | `lib/src/diagrams/cynefin/` | Phase 3 (Tier 2) | ✅ Ported |
| **Event Modeling** | `src/diagrams/eventmodeling/` | `lib/src/diagrams/eventmodeling/` | Phase 3 (Tier 2) | ✅ Ported |
| **Info** | `src/diagrams/info/` | `lib/src/diagrams/info/` | Phase 3 (Tier 2) | ✅ Ported |
| **Ishikawa** | `src/diagrams/ishikawa/` | `lib/src/diagrams/ishikawa/` | Phase 3 (Tier 2) | ✅ Ported |
| **Journey** | `src/diagrams/journey/` | `lib/src/diagrams/journey/` | Phase 3 (Tier 2) | ✅ Ported |
| **Kanban** | `src/diagrams/kanban/` | `lib/src/diagrams/kanban/` | Phase 3 (Tier 2) | ✅ Ported |
| **Packet** | `src/diagrams/packet/` | `lib/src/diagrams/packet/` | Phase 3 (Tier 2) | ✅ Ported |
| **Quadrant** | `src/diagrams/quadrant/` | `lib/src/diagrams/quadrant/` | Phase 3 (Tier 2) | ✅ Ported |
| **Radar** | `src/diagrams/radar/` | `lib/src/diagrams/radar/` | Phase 3 (Tier 2) | ✅ Ported |
| **Railroad** | `src/diagrams/railroad/` | `lib/src/diagrams/railroad/` | Phase 3 (Tier 2) | ✅ Ported |
| **Requirement** | `src/diagrams/requirement/` | `lib/src/diagrams/requirement/` | Phase 3 (Tier 2) | ✅ Ported |
| **Sankey** | `src/diagrams/sankey/` | `lib/src/diagrams/sankey/` | Phase 3 (Tier 2) | ✅ Ported |
| **Swimlane** | `src/diagrams/swimlane/` | `lib/src/diagrams/swimlane/` | Phase 3 (Tier 2) | ✅ Ported |
| **Timeline** | `src/diagrams/timeline/` | `lib/src/diagrams/timeline/` | Phase 3 (Tier 2) | ✅ Ported |
| **Treemap** | `src/diagrams/treemap/` | `lib/src/diagrams/treemap/` | Phase 3 (Tier 2) | ✅ Ported |
| **Treeview** | `src/diagrams/treeview/` | `lib/src/diagrams/treeview/` | Phase 3 (Tier 2) | ✅ Ported |
| **Use Case** | `src/diagrams/usecase/` | `lib/src/diagrams/usecase/` | Phase 3 (Tier 2) | ✅ Ported |
| **Venn** | `src/diagrams/venn/` | `lib/src/diagrams/venn/` | Phase 3 (Tier 2) | ✅ Ported |
| **Wardley** | `src/diagrams/wardley/` | `lib/src/diagrams/wardley/` | Phase 3 (Tier 2) | ✅ Ported |
| **XY Chart** | `src/diagrams/xychart/` | `lib/src/diagrams/xychart/` | Phase 3 (Tier 2) | ✅ Ported |
