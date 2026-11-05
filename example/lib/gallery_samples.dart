/// Curated gallery of all 33 Mermaid diagram families supported by `pele_dart`.
class DiagramSample {
  final String id;
  final String title;
  final String diagramType;
  final int tier;
  final String source;

  const DiagramSample({
    required this.id,
    required this.title,
    required this.diagramType,
    required this.tier,
    required this.source,
  });
}

const List<DiagramSample> gallerySamples = <DiagramSample>[
  DiagramSample(
    id: 'flowchart',
    title: 'Flowchart (Subgraphs & Shapes)',
    diagramType: 'flowchart',
    tier: 1,
    source: '''flowchart TD
  subgraph Client["Client Layer"]
    A([User Request]) --> B{Authenticated?}
  end
  subgraph Backend["Core Services"]
    B -->|Yes| C[API Gateway]
    B -->|No| D[[Auth Service]]
    C --> E[(Primary DB)]
    C --> F([Cache Layer])
  end
  D -.->|Token Issued| C''',
  ),
  DiagramSample(
    id: 'sequence',
    title: 'Sequence Diagram',
    diagramType: 'sequence',
    tier: 1,
    source: '''sequenceDiagram
  autonumber
  participant U as User
  participant A as App Client
  participant S as API Server
  participant D as Database
  U->>A: Click Render
  activate A
  A->>S: POST /diagrams/render
  activate S
  S->>D: Query cached AST
  D-->>S: Cache miss
  S-->>A: 200 OK (SVG payload)
  deactivate S
  A-->>U: Display Vector Diagram
  deactivate A''',
  ),
  DiagramSample(
    id: 'class',
    title: 'Class Diagram',
    diagramType: 'class',
    tier: 1,
    source: '''classDiagram
  class DiagramEngine {
    <<interface>>
    +parse(String source)
    +render(String source) String
  }
  class PeleRenderer {
    +SvgOutputMode outputMode
    +bool dark
    +flattenSvg(String rawSvg) String
  }
  class LayoutGraph {
    +List~Node~ nodes
    +List~Edge~ edges
    +compoundLayout()
  }
  DiagramEngine <|.. PeleRenderer
  PeleRenderer *-- LayoutGraph : uses''',
  ),
  DiagramSample(
    id: 'state',
    title: 'State Diagram (v2)',
    diagramType: 'state',
    tier: 1,
    source: '''stateDiagram-v2
  [*] --> Idle
  Idle --> Parsing : renderMermaid()
  state Parsing {
    [*] --> Preprocess
    Preprocess --> DetectType
    DetectType --> BuildAST
  }
  Parsing --> Layout : AST valid
  Parsing --> Error : MermaidParseError
  Layout --> EmitSVG : Coordinates ready
  EmitSVG --> Flatten : SvgOutputMode.flattened
  Flatten --> [*]
  Error --> [*]''',
  ),
  DiagramSample(
    id: 'er',
    title: 'Entity Relationship (ER)',
    diagramType: 'er',
    tier: 1,
    source: '''erDiagram
  WORKSPACE ||--o{ DOCUMENT : contains
  DOCUMENT ||--o{ DIAGRAM_BLOCK : embeds
  DIAGRAM_BLOCK {
    string id PK
    string diagram_type
    string source_hash
    int render_ms
  }
  WORKSPACE {
    string id PK
    string title
  }
  DOCUMENT {
    string path PK
    datetime updated_at
  }''',
  ),
  DiagramSample(
    id: 'gantt',
    title: 'Gantt Chart',
    diagramType: 'gantt',
    tier: 1,
    source: '''gantt
  title Pure-Dart Diagram Engine Roadmap
  dateFormat YYYY-MM-DD
  section Foundation
    Text & Layout Engine :done, f1, 2026-10-01, 7d
    SVG Flattener        :done, f2, after f1, 5d
  section Diagrams
    Tier 1 Core Families :active, d1, 2026-10-13, 10d
    Tier 2 Extended      :d2, after d1, 10d
  section Tooling
    3-Way Comparison App :t1, after d2, 5d''',
  ),
  DiagramSample(
    id: 'pie',
    title: 'Pie Chart',
    diagramType: 'pie',
    tier: 1,
    source: '''pie showData
  title Diagram Family Usage Distribution
  "Flowchart" : 42
  "Sequence" : 24
  "Class & State" : 16
  "Architecture & C4" : 10
  "Other 27 Families" : 8''',
  ),
  DiagramSample(
    id: 'gitGraph',
    title: 'Git Graph',
    diagramType: 'gitGraph',
    tier: 1,
    source: '''gitGraph
  commit id: "init"
  branch feature/layout
  checkout feature/layout
  commit id: "sugiyama"
  commit id: "compound"
  checkout main
  merge feature/layout id: "v0.1.0"
  branch feature/flattener
  checkout feature/flattener
  commit id: "oklab-mix"
  checkout main
  merge feature/flattener id: "v0.2.0"''',
  ),
  DiagramSample(
    id: 'mindmap',
    title: 'Mindmap',
    diagramType: 'mindmap',
    tier: 1,
    source: '''mindmap
  root((pele_dart))
    Core Engine
      Sugiyama Layout
      Text Measurer
      YAML Frontmatter
    SVG Pipeline
      CSS Variables
      OKLab Flattener
    33 Diagram Families
      Tier 1 Core
      Tier 2 Extended''',
  ),
  DiagramSample(
    id: 'timeline',
    title: 'Timeline',
    diagramType: 'timeline',
    tier: 2,
    source: '''timeline
  title Evolution of Mermaid Rendering
  2014 : mermaid.js Initial Release
       : Browser DOM + Dagre
  2024 : Native Desktop Viewers
       : Offscreen WebView Pools
  2026 : obsidianmd/pele Zero-DOM
       : pele_dart Pure Dart Port''',
  ),
  DiagramSample(
    id: 'journey',
    title: 'User Journey',
    diagramType: 'journey',
    tier: 2,
    source: '''journey
  title Developer Diagram Authoring Flow
  section Write Markdown
    Type Mermaid block: 5: Developer
    Live preview updates: 5: Developer
  section Inspect Diff
    Compare 3 renderers: 5: Developer
    Toggle Visual Diff: 4: Developer
  section Export
    Render vector SVG: 5: Developer''',
  ),
  DiagramSample(
    id: 'quadrantChart',
    title: 'Quadrant Chart',
    diagramType: 'quadrantChart',
    tier: 2,
    source: '''quadrantChart
  title Rendering Engine Trade-offs
  x-axis Low Speed --> High Speed
  y-axis Browser Required --> Pure Native
  quadrant-1 Ideal Desktop Engine
  quadrant-2 Native Heavyweight
  quadrant-3 Legacy DOM
  quadrant-4 Fast JS Engine
  pele_dart: [0.92, 0.95]
  obsidianmd/pele: [0.88, 0.35]
  mermaid.js: [0.25, 0.15]''',
  ),
  DiagramSample(
    id: 'xychart',
    title: 'XY Chart',
    diagramType: 'xychart',
    tier: 2,
    source: '''xychart-beta
  title "Render Latency by Diagram Complexity (ms)"
  x-axis ["10 Nodes", "25 Nodes", "50 Nodes", "100 Nodes", "200 Nodes"]
  y-axis "Milliseconds" 0 --> 120
  bar [2, 5, 11, 24, 52]
  line [1, 4, 9, 19, 41]''',
  ),
  DiagramSample(
    id: 'requirement',
    title: 'Requirement Diagram',
    diagramType: 'requirement',
    tier: 2,
    source: '''requirementDiagram
  requirement zero_dom_req {
    id: 1
    text: Render without browser or WebView process
    risk: low
    verifymethod: test
  }
  element pele_dart_engine {
    type: library
    docref: lib/pele_dart.dart
  }
  pele_dart_engine - satisfies -> zero_dom_req''',
  ),
  DiagramSample(
    id: 'c4',
    title: 'C4 Context Diagram',
    diagramType: 'c4',
    tier: 2,
    source: '''C4Context
  title System Context for Pure-Dart Diagram Renderer
  Person(dev, "Developer", "Authors Markdown with Mermaid diagrams")
  System(viewer, "Desktop App", "Renders Markdown and vector diagrams natively")
  System_Ext(upstream, "obsidianmd/pele", "Upstream TypeScript reference engine")
  Rel(dev, viewer, "Views & diffs diagrams")
  Rel(viewer, upstream, "Verified against via sync tooling")''',
  ),
  DiagramSample(
    id: 'sankey',
    title: 'Sankey Diagram',
    diagramType: 'sankey',
    tier: 2,
    source: '''sankey-beta
  Mermaid Source,Preprocessor,100
  Preprocessor,Detector,100
  Detector,Flowchart Parser,45
  Detector,Sequence Parser,30
  Detector,Other 31 Parsers,25
  Flowchart Parser,Sugiyama Layout,45
  Sequence Parser,Timeline Layout,30
  Other 31 Parsers,Specialized Layouts,25''',
  ),
  DiagramSample(
    id: 'kanban',
    title: 'Kanban Board',
    diagramType: 'kanban',
    tier: 2,
    source: '''kanban
  Completed
    [Phase 0: Repo & Sync Tooling]
    [Phase 1: Layout & SVG Core]
  In Progress
    [Phase 2: Tier 1 Diagrams]
    [Phase 3: Tier 2 Diagrams]
  Review
    [Phase 4: macOS 3-Way Comparison App]''',
  ),
  DiagramSample(
    id: 'packet',
    title: 'Packet Diagram',
    diagramType: 'packet',
    tier: 2,
    source: '''packet-beta
  0-15: "Source Port"
  16-31: "Destination Port"
  32-63: "Sequence Number"
  64-95: "Acknowledgment Number"
  96-99: "Data Offset"
  100-105: "Reserved"
  106-111: "Flags"
  112-127: "Window Size"''',
  ),
  DiagramSample(
    id: 'block',
    title: 'Block Diagram',
    diagramType: 'block',
    tier: 2,
    source: '''block-beta
  columns 3
  Frontend["Markdown Parser"] space:1 Engine["pele_dart"]
  space:3
  SVG["Raw SVG"] Flattener["OKLab Flattener"] Vector["vector_graphics"]
  Frontend --> Engine
  Engine --> SVG
  SVG --> Flattener
  Flattener --> Vector''',
  ),
  DiagramSample(
    id: 'architecture',
    title: 'Architecture Diagram',
    diagramType: 'architecture',
    tier: 2,
    source: '''architecture-beta
  group core(cloud)[Pele Core]
  service parser(server)[Parser] in core
  service layout(server)[Sugiyama Layout] in core
  service svg(database)[SVG Builder] in core
  parser:R --> L:layout
  layout:R --> L:svg''',
  ),
  DiagramSample(
    id: 'radar',
    title: 'Radar Chart',
    diagramType: 'radar',
    tier: 2,
    source: '''radar-beta
  title Engine Capability Comparison
  axis Speed, Parity, Offline, Footprint, Ergonomics
  curve pele_dart{95, 98, 100, 96, 92}
  curve mermaid_js{35, 100, 60, 25, 80}''',
  ),
  DiagramSample(
    id: 'treemap',
    title: 'Treemap Diagram',
    diagramType: 'treemap',
    tier: 2,
    source: '''treemap-beta
"pele_dart"
  "Layout Engine"
    "layered.dart": 45
    "compound.dart": 35
  "SVG Pipeline"
    "shapes.dart": 30
    "flattener.dart": 25
  "Diagrams"
    "Tier 1": 60
    "Tier 2": 80''',
  ),
  DiagramSample(
    id: 'info',
    title: 'Info Diagram',
    diagramType: 'info',
    tier: 1,
    source: '''info
  showInfo''',
  ),
  DiagramSample(
    id: 'railroad',
    title: 'Railroad Syntax Diagram',
    diagramType: 'railroad',
    tier: 2,
    source: '''railroad-ebnf-beta
  Diagram = "flowchart" ("TD" | "LR") Statement+ ;
  Statement = Node ("-->" | "-.->") Node ;''',
  ),
  DiagramSample(
    id: 'agentflow',
    title: 'Agentflow Diagram',
    diagramType: 'agentflow',
    tier: 2,
    source: '''agentflow-beta TB
  orchestrator["Lead Orchestrator"] --> porter["Diagram Porter"]
  porter --> verifier["Diff Verifier"]''',
  ),
  DiagramSample(
    id: 'treeView',
    title: 'TreeView Diagram',
    diagramType: 'treeView',
    tier: 2,
    source: '''treeView-beta
  "pele_dart"
    "lib"
      "pele_dart.dart"
      "src"
        "layout"
        "svg"
        "diagrams"
    "example"
      "lib"
        "main.dart"''',
  ),
  DiagramSample(
    id: 'cynefin',
    title: 'Cynefin Framework',
    diagramType: 'cynefin',
    tier: 2,
    source: '''cynefin-beta
  title Decision Complexity Domains
  clear
    "1:1 Syntax Porting"
  complicated
    "Sugiyama Crossing Minimization"
  complex
    "Visual Pixel-Diff Analysis"
  chaotic
    "Unbounded DOM Quirks"''',
  ),
  DiagramSample(
    id: 'wardley',
    title: 'Wardley Map',
    diagramType: 'wardley',
    tier: 2,
    source: '''wardley-beta
  title Diagram Rendering Value Chain
  component Markdown Viewer [0.85, 0.65]
  component Vector SVG Widget [0.70, 0.72]
  component pele_dart Engine [0.55, 0.50]
  component Sugiyama Layout [0.30, 0.80]
  Markdown Viewer -> Vector SVG Widget
  Vector SVG Widget -> pele_dart Engine
  pele_dart Engine -> Sugiyama Layout''',
  ),
  DiagramSample(
    id: 'eventmodeling',
    title: 'Event Modeling',
    diagramType: 'eventmodeling',
    tier: 2,
    source: '''eventmodeling
  tf 01 ui RenderButton
  tf 02 cmd RenderDiagram ->> 01
  tf 03 evt DiagramParsed ->> 02
  tf 04 rmo VectorCanvas ->> 03''',
  ),
  DiagramSample(
    id: 'usecase',
    title: 'Use Case Diagram',
    diagramType: 'usecase',
    tier: 2,
    source: '''usecase-beta
  actor Developer("Developer")
  UC1("Compare 3 Renderers")
  UC2("Inspect Visual Pixel Diff")
  UC3("Launch External SVG Diff")
  Developer --> UC1
  Developer --> UC2
  Developer --> UC3''',
  ),
  DiagramSample(
    id: 'venn',
    title: 'Venn Diagram',
    diagramType: 'venn',
    tier: 2,
    source: '''venn-beta
  title Renderer Architecture Overlap
  set A["Zero-DOM Speed"]
  set B["33 Diagram Families"]
  set C["Pure Dart Native"]
  union A,B["obsidianmd/pele"]
  union A,B,C["pele_dart"]''',
  ),
  DiagramSample(
    id: 'ishikawa',
    title: 'Ishikawa (Fishbone) Diagram',
    diagramType: 'ishikawa',
    tier: 2,
    source: '''ishikawa-beta
  Visual Drift
    Typography
      Font width metrics
      Line wrapping breaks
    Colors
      OKLab color-mix
      CSS custom properties
    Geometry
      Rank spacing
      Bezier control points''',
  ),
  DiagramSample(
    id: 'swimlane',
    title: 'Swimlane Diagram',
    diagramType: 'swimlane',
    tier: 2,
    source: '''swimlane-beta
  subgraph Parser["Parser Stage"]
    A[Preprocess YAML] --> B[Detect Type]
  end
  subgraph Layout["Layout Stage"]
    B --> C[Compound Layout]
  end
  subgraph Output["SVG Stage"]
    C --> D[Flatten CSS Variables]
  end''',
  ),
];
