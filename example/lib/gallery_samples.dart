// Generated from upstream obsidianmd/pele website/src/lib/examples.ts and tests/corpus/*-docs.json.
// Contains the official https://pele.run/examples showcase diagrams and
// https://pele.run/playground sample groups across all 33 diagram families.

/// Default diagram loaded when opening https://pele.run/playground.
const String playgroundDefaultSource =
    "flowchart TD\n  A([Mermaid text]) --> B{Supported?}\n  B -- Yes --> C[Parse]\n  B -- No --> H[Fall back]\n\n  subgraph Pele\n    C --> D[Layout]\n    D --> E[Render]\n  end\n\n  E --> F[(SVG)]\n  F -.-> G[Theme with CSS]";

/// A single official sample from the https://pele.run/playground picker.
class PlaygroundSampleItem {
  final String label;
  final String source;

  const PlaygroundSampleItem({required this.label, required this.source});
}

/// Official diagram family group with its https://pele.run/examples showcase
/// diagrams and its 1..6 https://pele.run/playground samples.
class DiagramFamilyGroup {
  final String type;
  final String title;
  final String description;
  final bool beta;
  final int tier;
  final List<String> showcaseSources;
  final List<PlaygroundSampleItem> playgroundSamples;

  const DiagramFamilyGroup({
    required this.type,
    required this.title,
    required this.description,
    required this.beta,
    required this.tier,
    required this.showcaseSources,
    required this.playgroundSamples,
  });
}

/// Primary sample entry per diagram family (33 total).
class DiagramSample {
  final String id;
  final String title;
  final String description;
  final String diagramType;
  final bool beta;
  final int tier;
  final String source;
  final List<String> showcaseSources;
  final List<PlaygroundSampleItem> playgroundSamples;

  const DiagramSample({
    required this.id,
    required this.title,
    required this.description,
    required this.diagramType,
    required this.beta,
    required this.tier,
    required this.source,
    required this.showcaseSources,
    required this.playgroundSamples,
  });
}

const List<DiagramSample> gallerySamples = <DiagramSample>[
  DiagramSample(
    id: "flowchart",
    title: "Flowchart",
    description: "Show the steps and decisions in a process.",
    diagramType: "flowchart",
    beta: false,
    tier: 1,
    source:
        "flowchart LR\n    subgraph subgraph1\n        direction TB\n        top1[top] --> bottom1[bottom]\n    end\n    subgraph subgraph2\n        direction TB\n        top2[top] --> bottom2[bottom]\n    end\n    %% ^ These subgraphs are identical, except for the links to them:\n\n    %% Link *to* subgraph1: subgraph1 direction is maintained\n    outside --> subgraph1\n    %% Link *within* subgraph2:\n    %% subgraph2 inherits the direction of the top-level graph (LR)\n    outside ---> top2",
    showcaseSources: <String>[
      "flowchart LR\n    subgraph subgraph1\n        direction TB\n        top1[top] --> bottom1[bottom]\n    end\n    subgraph subgraph2\n        direction TB\n        top2[top] --> bottom2[bottom]\n    end\n    %% ^ These subgraphs are identical, except for the links to them:\n\n    %% Link *to* subgraph1: subgraph1 direction is maintained\n    outside --> subgraph1\n    %% Link *within* subgraph2:\n    %% subgraph2 inherits the direction of the top-level graph (LR)\n    outside ---> top2",
      "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nflowchart LR\n  subgraph Client\n    UI[Web app]\n    Cache[(Local cache)]\n  end\n  subgraph Services\n    API[API gateway]\n    Auth[Auth service]\n    Orders[Order service]\n  end\n  subgraph Storage\n    DB[(Orders DB)]\n  end\n  UI --> API\n  UI --> Cache\n  API --> Auth\n  API --> Orders\n  Orders --> DB\n  Auth -. token .-> UI",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. subgraph Client",
        source:
            "flowchart LR\n  subgraph Client\n    UI[Web app]\n    Cache[(Local cache)]\n  end\n  subgraph Services\n    API[API gateway]\n    Auth[Auth service]\n    Orders[Order service]\n  end\n  subgraph Storage\n    DB[(Orders DB)]\n  end\n  UI --> API\n  UI --> Cache\n  API --> Auth\n  API --> Orders\n  Orders --> DB\n  Auth -. token .-> UI",
      ),
      PlaygroundSampleItem(
        label: "2. subgraph Client",
        source:
            "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nflowchart LR\n  subgraph Client\n    UI[Web app]\n    Cache[(Local cache)]\n  end\n  subgraph Services\n    API[API gateway]\n    Auth[Auth service]\n    Orders[Order service]\n  end\n  subgraph Storage\n    DB[(Orders DB)]\n  end\n  UI --> API\n  UI --> Cache\n  API --> Auth\n  API --> Orders\n  Orders --> DB\n  Auth -. token .-> UI",
      ),
      PlaygroundSampleItem(
        label: "3. subgraph subgraph1",
        source:
            "flowchart LR\n    subgraph subgraph1\n        direction TB\n        top1[top] --> bottom1[bottom]\n    end\n    subgraph subgraph2\n        direction TB\n        top2[top] --> bottom2[bottom]\n    end\n    %% ^ These subgraphs are identical, except for the links to them:\n\n    %% Link *to* subgraph1: subgraph1 direction is maintained\n    outside --> subgraph1\n    %% Link *within* subgraph2:\n    %% subgraph2 inherits the direction of the top-level graph (LR)\n    outside ---> top2",
      ),
      PlaygroundSampleItem(
        label: "4. subgraph \"One\"",
        source:
            "---\nconfig:\n  htmlLabels: false\n---\nflowchart LR\nsubgraph \"One\"\n  a(\"`The **cat**\n  in the hat`\") -- \"edge label\" --> b{{\"`The **dog** in the hog`\"}}\nend\nsubgraph \"`**Two**`\"\n  c(\"`The **cat**\n  in the hat`\") -- \"`Bold **edge label**`\" --> d(\"The dog in the hog\")\nend",
      ),
      PlaygroundSampleItem(
        label: "5. A-->B",
        source:
            "flowchart LR\n    A-->B\n    B-->C\n    C-->D\n    click A callback \"Tooltip for a callback\"\n    click B \"https://www.github.com\" \"This is a tooltip for a link\"\n    click C call callback() \"Tooltip for a callback\"\n    click D href \"https://www.github.com\" \"This is a tooltip for a link\"",
      ),
      PlaygroundSampleItem(
        label: "6. A-->B",
        source:
            "flowchart LR\n    A-->B\n    B-->C\n    C-->D\n    D-->E\n    click A \"https://www.github.com\" _blank\n    click B \"https://www.github.com\" \"Open this in a new tab\" _blank\n    click C href \"https://www.github.com\" _blank\n    click D href \"https://www.github.com\" \"Open this in a new tab\" _blank",
      ),
    ],
  ),
  DiagramSample(
    id: "block",
    title: "Block",
    description: "Show blocks in a grid that you arrange yourself.",
    diagramType: "block",
    beta: false,
    tier: 2,
    source:
        "block\n  blockArrowId<[\"Label\"]>(right)\n  blockArrowId2<[\"Label\"]>(left)\n  blockArrowId3<[\"Label\"]>(up)\n  blockArrowId4<[\"Label\"]>(down)\n  blockArrowId5<[\"Label\"]>(x)\n  blockArrowId6<[\"Label\"]>(y)\n  blockArrowId7<[\"Label\"]>(x, down)",
    showcaseSources: <String>[
      "block\n  blockArrowId<[\"Label\"]>(right)\n  blockArrowId2<[\"Label\"]>(left)\n  blockArrowId3<[\"Label\"]>(up)\n  blockArrowId4<[\"Label\"]>(down)\n  blockArrowId5<[\"Label\"]>(x)\n  blockArrowId6<[\"Label\"]>(y)\n  blockArrowId7<[\"Label\"]>(x, down)",
      "block\n  columns 3\n  a:3\n  block:group1:2\n    columns 2\n    h i j k\n  end\n  g\n  block:group2:3\n    %% columns auto (default)\n    l m n o p q r\n  end",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. columns 1",
        source:
            "block\ncolumns 1\n  db((\"DB\"))\n  blockArrowId6<[\"&nbsp;&nbsp;&nbsp;\"]>(down)\n  block:ID\n    A\n    B[\"A wide one in the middle\"]\n    C\n  end\n  space\n  D\n  ID --> D\n  C --> D\n  style B fill:#969,stroke:#333,stroke-width:4px",
      ),
      PlaygroundSampleItem(
        label: "2. blockArrowId<[\"Label\"]>(right)",
        source:
            "block\n  blockArrowId<[\"Label\"]>(right)\n  blockArrowId2<[\"Label\"]>(left)\n  blockArrowId3<[\"Label\"]>(up)\n  blockArrowId4<[\"Label\"]>(down)\n  blockArrowId5<[\"Label\"]>(x)\n  blockArrowId6<[\"Label\"]>(y)\n  blockArrowId7<[\"Label\"]>(x, down)",
      ),
      PlaygroundSampleItem(
        label: "3. columns 1",
        source:
            "block\ncolumns 1\n  db((\"DB\"))\n  blockArrowId6<[\"&nbsp;&nbsp;&nbsp;\"]>(down)\n  block:ID\n    A\n    B[\"A wide one in the middle\"]\n    C\n  end\n  space\n  D\n  ID --> D\n  C --> D\n  style B fill:#939,stroke:#333,stroke-width:4px",
      ),
      PlaygroundSampleItem(
        label: "4. id1 space id2",
        source:
            "block\n  id1 space id2\n  id1(\"Start\")-->id2(\"Stop\")\n  style id1 fill:#636,stroke:#333,stroke-width:4px\n  style id2 fill:#bbf,stroke:#f66,stroke-width:2px,color:#fff,stroke-dasharray: 5 5",
      ),
      PlaygroundSampleItem(
        label: "5. columns 3",
        source:
            "block\n  columns 3\n  Frontend blockArrowId6<[\" \"]>(right) Backend\n  space:2 down<[\" \"]>(down)\n  Disk left<[\" \"]>(left) Database[(\"Database\")]\n\n  classDef front fill:#696,stroke:#333;\n  classDef back fill:#969,stroke:#333;\n  class Frontend front\n  class Backend,Database back",
      ),
      PlaygroundSampleItem(
        label: "6. columns 3",
        source:
            "block\n  columns 3\n  Start((\"Start\")) space:2\n  down<[\" \"]>(down) space:2\n  Decision{{\"Make Decision\"}} right<[\"Yes\"]>(right) Process1[\"Process A\"]\n  downAgain<[\"No\"]>(down) space r3<[\"Done\"]>(down)\n  Process2[\"Process B\"] r2<[\"Done\"]>(right) End((\"End\"))\n\n  style Start fill:#969;\n  style End fill:#696;",
      ),
    ],
  ),
  DiagramSample(
    id: "c4",
    title: "C4",
    description:
        "Show a software system as people, systems, containers, and components.",
    diagramType: "c4",
    beta: false,
    tier: 2,
    source:
        "C4Component\n    title Component diagram for Internet Banking System - API Application\n\n    Container(spa, \"Single Page Application\", \"javascript and angular\", \"Provides all the internet banking functionality to customers via their web browser.\")\n    Container(ma, \"Mobile App\", \"Xamarin\", \"Provides a limited subset to the internet banking functionality to customers via their mobile device.\")\n    ContainerDb(db, \"Database\", \"Relational Database Schema\", \"Stores user registration information, hashed authentication credentials, access logs, etc.\")\n    System_Ext(mbs, \"Mainframe Banking System\", \"Stores all of the core banking information about customers, accounts, transactions, etc.\")\n\n    Container_Boundary(api, \"API Application\") {\n        Component(sign, \"Sign In Controller\", \"MVC Rest Controller\", \"Allows users to sign in to the internet banking system\")\n        Component(accounts, \"Accounts Summary Controller\", \"MVC Rest Controller\", \"Provides customers with a summary of their bank accounts\")\n        Component(security, \"Security Component\", \"Spring Bean\", \"Provides functionality related to singing in, changing passwords, etc.\")\n        Component(mbsfacade, \"Mainframe Banking System Facade\", \"Spring Bean\", \"A facade onto the mainframe banking system.\")\n\n        Rel(sign, security, \"Uses\")\n        Rel(accounts, mbsfacade, \"Uses\")\n        Rel(security, db, \"Read & write to\", \"JDBC\")\n        Rel(mbsfacade, mbs, \"Uses\", \"XML/HTTPS\")\n    }\n\n    Rel_Back(spa, sign, \"Uses\", \"JSON/HTTPS\")\n    Rel(spa, accounts, \"Uses\", \"JSON/HTTPS\")\n\n    Rel(ma, sign, \"Uses\", \"JSON/HTTPS\")\n    Rel(ma, accounts, \"Uses\", \"JSON/HTTPS\")\n\n    UpdateRelStyle(spa, sign, \$offsetY=\"-40\")\n    UpdateRelStyle(spa, accounts, \$offsetX=\"40\", \$offsetY=\"40\")\n\n    UpdateRelStyle(ma, sign, \$offsetX=\"-90\", \$offsetY=\"40\")\n    UpdateRelStyle(ma, accounts, \$offsetY=\"-40\")\n\n        UpdateRelStyle(sign, security, \$offsetX=\"-160\", \$offsetY=\"10\")\n        UpdateRelStyle(accounts, mbsfacade, \$offsetX=\"140\", \$offsetY=\"10\")\n        UpdateRelStyle(security, db, \$offsetY=\"-40\")\n        UpdateRelStyle(mbsfacade, mbs, \$offsetY=\"-40\")",
    showcaseSources: <String>[
      "C4Component\n    title Component diagram for Internet Banking System - API Application\n\n    Container(spa, \"Single Page Application\", \"javascript and angular\", \"Provides all the internet banking functionality to customers via their web browser.\")\n    Container(ma, \"Mobile App\", \"Xamarin\", \"Provides a limited subset to the internet banking functionality to customers via their mobile device.\")\n    ContainerDb(db, \"Database\", \"Relational Database Schema\", \"Stores user registration information, hashed authentication credentials, access logs, etc.\")\n    System_Ext(mbs, \"Mainframe Banking System\", \"Stores all of the core banking information about customers, accounts, transactions, etc.\")\n\n    Container_Boundary(api, \"API Application\") {\n        Component(sign, \"Sign In Controller\", \"MVC Rest Controller\", \"Allows users to sign in to the internet banking system\")\n        Component(accounts, \"Accounts Summary Controller\", \"MVC Rest Controller\", \"Provides customers with a summary of their bank accounts\")\n        Component(security, \"Security Component\", \"Spring Bean\", \"Provides functionality related to singing in, changing passwords, etc.\")\n        Component(mbsfacade, \"Mainframe Banking System Facade\", \"Spring Bean\", \"A facade onto the mainframe banking system.\")\n\n        Rel(sign, security, \"Uses\")\n        Rel(accounts, mbsfacade, \"Uses\")\n        Rel(security, db, \"Read & write to\", \"JDBC\")\n        Rel(mbsfacade, mbs, \"Uses\", \"XML/HTTPS\")\n    }\n\n    Rel_Back(spa, sign, \"Uses\", \"JSON/HTTPS\")\n    Rel(spa, accounts, \"Uses\", \"JSON/HTTPS\")\n\n    Rel(ma, sign, \"Uses\", \"JSON/HTTPS\")\n    Rel(ma, accounts, \"Uses\", \"JSON/HTTPS\")\n\n    UpdateRelStyle(spa, sign, \$offsetY=\"-40\")\n    UpdateRelStyle(spa, accounts, \$offsetX=\"40\", \$offsetY=\"40\")\n\n    UpdateRelStyle(ma, sign, \$offsetX=\"-90\", \$offsetY=\"40\")\n    UpdateRelStyle(ma, accounts, \$offsetY=\"-40\")\n\n        UpdateRelStyle(sign, security, \$offsetX=\"-160\", \$offsetY=\"10\")\n        UpdateRelStyle(accounts, mbsfacade, \$offsetX=\"140\", \$offsetY=\"10\")\n        UpdateRelStyle(security, db, \$offsetY=\"-40\")\n        UpdateRelStyle(mbsfacade, mbs, \$offsetY=\"-40\")",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. C4Context — System Context",
        source:
            "C4Context\n      title System Context diagram for Internet Banking System\n      Enterprise_Boundary(b0, \"BankBoundary0\") {\n        Person(customerA, \"Banking Customer A\", \"A customer of the bank, with personal bank accounts.\")\n        Person(customerB, \"Banking Customer B\")\n        Person_Ext(customerC, \"Banking Customer C\", \"desc\")\n\n        Person(customerD, \"Banking Customer D\", \"A customer of the bank, <br/> with personal bank accounts.\")\n\n        System(SystemAA, \"Internet Banking System\", \"Allows customers to view information about their bank accounts, and make payments.\")\n\n        Enterprise_Boundary(b1, \"BankBoundary\") {\n\n          SystemDb_Ext(SystemE, \"Mainframe Banking System\", \"Stores all of the core banking information about customers, accounts, transactions, etc.\")\n\n          System_Boundary(b2, \"BankBoundary2\") {\n            System(SystemA, \"Banking System A\")\n            System(SystemB, \"Banking System B\", \"A system of the bank, with personal bank accounts. next line.\")\n          }\n\n          System_Ext(SystemC, \"E-mail system\", \"The internal Microsoft Exchange e-mail system.\")\n          SystemDb(SystemD, \"Banking System D Database\", \"A system of the bank, with personal bank accounts.\")\n\n          Boundary(b3, \"BankBoundary3\", \"boundary\") {\n            SystemQueue(SystemF, \"Banking System F Queue\", \"A system of the bank.\")\n            SystemQueue_Ext(SystemG, \"Banking System G Queue\", \"A system of the bank, with personal bank accounts.\")\n          }\n        }\n      }\n\n      BiRel(customerA, SystemAA, \"Uses\")\n      BiRel(SystemAA, SystemE, \"Uses\")\n      Rel(SystemAA, SystemC, \"Sends e-mails\", \"SMTP\")\n      Rel(SystemC, customerA, \"Sends e-mails to\")\n\n      UpdateElementStyle(customerA, \$fontColor=\"red\", \$bgColor=\"gray\", \$borderColor=\"red\")\n      UpdateRelStyle(customerA, SystemAA, \$textColor=\"blue\", \$lineColor=\"blue\", \$offsetX=\"5\")\n      UpdateRelStyle(SystemAA, SystemE, \$textColor=\"blue\", \$lineColor=\"blue\", \$offsetY=\"-10\")\n      UpdateRelStyle(SystemAA, SystemC, \$textColor=\"blue\", \$lineColor=\"blue\", \$offsetY=\"-40\", \$offsetX=\"-50\")\n      UpdateRelStyle(SystemC, customerA, \$textColor=\"red\", \$lineColor=\"red\", \$offsetX=\"-50\", \$offsetY=\"20\")\n\n      UpdateLayoutConfig(\$c4ShapeInRow=\"3\", \$c4BoundaryInRow=\"1\")",
      ),
      PlaygroundSampleItem(
        label: "2. C4Context — Enterprise Boundary",
        source:
            "C4Context\n      title System Context diagram for Internet Banking System\n      Enterprise_Boundary(b0, \"BankBoundary0\") {\n        Person(customerA, \"Banking Customer A\", \"A customer of the bank, with personal bank accounts.\")\n        Person(customerB, \"Banking Customer B\")\n        Person_Ext(customerC, \"Banking Customer C\", \"desc\")\n\n        Person(customerD, \"Banking Customer D\", \"A customer of the bank, <br/> with personal bank accounts.\")\n\n        System(SystemAA, \"Internet Banking System\", \"Allows customers to view information about their bank accounts, and make payments.\")\n\n        Enterprise_Boundary(b1, \"BankBoundary\") {\n\n          SystemDb_Ext(SystemE, \"Mainframe Banking System\", \"Stores all of the core banking information about customers, accounts, transactions, etc.\")\n\n          System_Boundary(b2, \"BankBoundary2\") {\n            System(SystemA, \"Banking System A\")\n            System(SystemB, \"Banking System B\", \"A system of the bank, with personal bank accounts. next line.\")\n          }\n\n          System_Ext(SystemC, \"E-mail system\", \"The internal Microsoft Exchange e-mail system.\")\n          SystemDb(SystemD, \"Banking System D Database\", \"A system of the bank, with personal bank accounts.\")\n\n          Boundary(b3, \"BankBoundary3\", \"boundary\") {\n            SystemQueue(SystemF, \"Banking System F Queue\", \"A system of the bank.\")\n            SystemQueue_Ext(SystemG, \"Banking System G Queue\", \"A system of the bank, with personal bank accounts.\")\n          }\n        }\n      }\n\n      BiRel(customerA, SystemAA, \"Uses\")\n      BiRel(SystemAA, SystemE, \"Uses\")\n      Rel(SystemAA, SystemC, \"Sends e-mails\", \"SMTP\")\n      Rel(SystemC, customerA, \"Sends e-mails to\")\n\n      UpdateElementStyle(customerA, \$fontColor=\"red\", \$bgColor=\"gray\", \$borderColor=\"red\")\n      UpdateRelStyle(customerA, SystemAA, \$textColor=\"blue\", \$lineColor=\"blue\", \$offsetX=\"5\")\n      UpdateRelStyle(SystemAA, SystemE, \$textColor=\"blue\", \$lineColor=\"blue\", \$offsetY=\"-10\")\n      UpdateRelStyle(SystemAA, SystemC, \$textColor=\"blue\", \$lineColor=\"blue\", \$offsetY=\"-40\", \$offsetX=\"-50\")\n      UpdateRelStyle(SystemC, customerA, \$textColor=\"red\", \$lineColor=\"red\", \$offsetX=\"-50\", \$offsetY=\"20\")\n\n      UpdateLayoutConfig(\$c4ShapeInRow=\"3\", \$c4BoundaryInRow=\"1\")",
      ),
      PlaygroundSampleItem(
        label: "3. C4Container — Container Diagram",
        source:
            "C4Container\n    title Container diagram for Internet Banking System\n\n    System_Ext(email_system, \"E-Mail System\", \"The internal Microsoft Exchange system\", \$tags=\"v1.0\")\n    Person(customer, Customer, \"A customer of the bank, with personal bank accounts\", \$tags=\"v1.0\")\n\n    Container_Boundary(c1, \"Internet Banking\") {\n        Container(spa, \"Single-Page App\", \"JavaScript, Angular\", \"Provides all the Internet banking functionality to customers via their web browser\")\n        Container_Ext(mobile_app, \"Mobile App\", \"C#, Xamarin\", \"Provides a limited subset of the Internet banking functionality to customers via their mobile device\")\n        Container(web_app, \"Web Application\", \"Java, Spring MVC\", \"Delivers the static content and the Internet banking SPA\")\n        ContainerDb(database, \"Database\", \"SQL Database\", \"Stores user registration information, hashed auth credentials, access logs, etc.\")\n        ContainerDb_Ext(backend_api, \"API Application\", \"Java, Docker Container\", \"Provides Internet banking functionality via API\")\n\n    }\n\n    System_Ext(banking_system, \"Mainframe Banking System\", \"Stores all of the core banking information about customers, accounts, transactions, etc.\")\n\n    Rel(customer, web_app, \"Uses\", \"HTTPS\")\n    UpdateRelStyle(customer, web_app, \$offsetY=\"60\", \$offsetX=\"90\")\n    Rel(customer, spa, \"Uses\", \"HTTPS\")\n    UpdateRelStyle(customer, spa, \$offsetY=\"-40\")\n    Rel(customer, mobile_app, \"Uses\")\n    UpdateRelStyle(customer, mobile_app, \$offsetY=\"-30\")\n\n    Rel(web_app, spa, \"Delivers\")\n    UpdateRelStyle(web_app, spa, \$offsetX=\"130\")\n    Rel(spa, backend_api, \"Uses\", \"async, JSON/HTTPS\")\n    Rel(mobile_app, backend_api, \"Uses\", \"async, JSON/HTTPS\")\n    Rel_Back(database, backend_api, \"Reads from and writes to\", \"sync, JDBC\")\n\n    Rel(email_system, customer, \"Sends e-mails to\")\n    UpdateRelStyle(email_system, customer, \$offsetX=\"-45\")\n    Rel(backend_api, email_system, \"Sends e-mails using\", \"sync, SMTP\")\n    UpdateRelStyle(backend_api, email_system, \$offsetY=\"-60\")\n    Rel(backend_api, banking_system, \"Uses\", \"sync/async, XML/HTTPS\")\n    UpdateRelStyle(backend_api, banking_system, \$offsetY=\"-50\", \$offsetX=\"-140\")",
      ),
      PlaygroundSampleItem(
        label: "4. C4Component — Component Diagram",
        source:
            "C4Component\n    title Component diagram for Internet Banking System - API Application\n\n    Container(spa, \"Single Page Application\", \"javascript and angular\", \"Provides all the internet banking functionality to customers via their web browser.\")\n    Container(ma, \"Mobile App\", \"Xamarin\", \"Provides a limited subset to the internet banking functionality to customers via their mobile device.\")\n    ContainerDb(db, \"Database\", \"Relational Database Schema\", \"Stores user registration information, hashed authentication credentials, access logs, etc.\")\n    System_Ext(mbs, \"Mainframe Banking System\", \"Stores all of the core banking information about customers, accounts, transactions, etc.\")\n\n    Container_Boundary(api, \"API Application\") {\n        Component(sign, \"Sign In Controller\", \"MVC Rest Controller\", \"Allows users to sign in to the internet banking system\")\n        Component(accounts, \"Accounts Summary Controller\", \"MVC Rest Controller\", \"Provides customers with a summary of their bank accounts\")\n        Component(security, \"Security Component\", \"Spring Bean\", \"Provides functionality related to singing in, changing passwords, etc.\")\n        Component(mbsfacade, \"Mainframe Banking System Facade\", \"Spring Bean\", \"A facade onto the mainframe banking system.\")\n\n        Rel(sign, security, \"Uses\")\n        Rel(accounts, mbsfacade, \"Uses\")\n        Rel(security, db, \"Read & write to\", \"JDBC\")\n        Rel(mbsfacade, mbs, \"Uses\", \"XML/HTTPS\")\n    }\n\n    Rel_Back(spa, sign, \"Uses\", \"JSON/HTTPS\")\n    Rel(spa, accounts, \"Uses\", \"JSON/HTTPS\")\n\n    Rel(ma, sign, \"Uses\", \"JSON/HTTPS\")\n    Rel(ma, accounts, \"Uses\", \"JSON/HTTPS\")\n\n    UpdateRelStyle(spa, sign, \$offsetY=\"-40\")\n    UpdateRelStyle(spa, accounts, \$offsetX=\"40\", \$offsetY=\"40\")\n\n    UpdateRelStyle(ma, sign, \$offsetX=\"-90\", \$offsetY=\"40\")\n    UpdateRelStyle(ma, accounts, \$offsetY=\"-40\")\n\n        UpdateRelStyle(sign, security, \$offsetX=\"-160\", \$offsetY=\"10\")\n        UpdateRelStyle(accounts, mbsfacade, \$offsetX=\"140\", \$offsetY=\"10\")\n        UpdateRelStyle(security, db, \$offsetY=\"-40\")\n        UpdateRelStyle(mbsfacade, mbs, \$offsetY=\"-40\")",
      ),
      PlaygroundSampleItem(
        label: "5. C4Dynamic — Dynamic Diagram",
        source:
            "C4Dynamic\n    title Dynamic diagram for Internet Banking System - API Application\n\n    ContainerDb(c4, \"Database\", \"Relational Database Schema\", \"Stores user registration information, hashed authentication credentials, access logs, etc.\")\n    Container(c1, \"Single-Page Application\", \"JavaScript and Angular\", \"Provides all of the Internet banking functionality to customers via their web browser.\")\n    Container_Boundary(b, \"API Application\") {\n      Component(c3, \"Security Component\", \"Spring Bean\", \"Provides functionality Related to signing in, changing passwords, etc.\")\n      Component(c2, \"Sign In Controller\", \"Spring MVC Rest Controller\", \"Allows users to sign in to the Internet Banking System.\")\n    }\n    Rel(c1, c2, \"Submits credentials to\", \"JSON/HTTPS\")\n    Rel(c2, c3, \"Calls isAuthenticated() on\")\n    Rel(c3, c4, \"select * from users where username = ?\", \"JDBC\")\n\n    UpdateRelStyle(c1, c2, \$textColor=\"red\", \$offsetY=\"-40\")\n    UpdateRelStyle(c2, c3, \$textColor=\"red\", \$offsetX=\"-40\", \$offsetY=\"60\")\n    UpdateRelStyle(c3, c4, \$textColor=\"red\", \$offsetY=\"-40\", \$offsetX=\"10\")",
      ),
      PlaygroundSampleItem(
        label: "6. C4Deployment — Deployment Diagram",
        source:
            "C4Deployment\n    title Deployment Diagram for Internet Banking System - Live\n\n    Deployment_Node(mob, \"Customer's mobile device\", \"Apple IOS or Android\"){\n        Container(mobile, \"Mobile App\", \"Xamarin\", \"Provides a limited subset of the Internet Banking functionality to customers via their mobile device.\")\n    }\n\n    Deployment_Node(comp, \"Customer's computer\", \"Microsoft Windows or Apple macOS\"){\n        Deployment_Node(browser, \"Web Browser\", \"Google Chrome, Mozilla Firefox,<br/> Apple Safari or Microsoft Edge\"){\n            Container(spa, \"Single Page Application\", \"JavaScript and Angular\", \"Provides all of the Internet Banking functionality to customers via their web browser.\")\n        }\n    }\n\n    Deployment_Node(plc, \"Big Bank plc\", \"Big Bank plc data center\"){\n        Deployment_Node(dn, \"bigbank-api*** x8\", \"Ubuntu 16.04 LTS\"){\n            Deployment_Node(apache, \"Apache Tomcat\", \"Apache Tomcat 8.x\"){\n                Container(api, \"API Application\", \"Java and Spring MVC\", \"Provides Internet Banking functionality via a JSON/HTTPS API.\")\n            }\n        }\n        Deployment_Node(bb2, \"bigbank-web*** x4\", \"Ubuntu 16.04 LTS\"){\n            Deployment_Node(apache2, \"Apache Tomcat\", \"Apache Tomcat 8.x\"){\n                Container(web, \"Web Application\", \"Java and Spring MVC\", \"Delivers the static content and the Internet Banking single page application.\")\n            }\n        }\n        Deployment_Node(bigbankdb01, \"bigbank-db01\", \"Ubuntu 16.04 LTS\"){\n            Deployment_Node(oracle, \"Oracle - Primary\", \"Oracle 12c\"){\n                ContainerDb(db, \"Database\", \"Relational Database Schema\", \"Stores user registration information, hashed authentication credentials, access logs, etc.\")\n            }\n        }\n        Deployment_Node(bigbankdb02, \"bigbank-db02\", \"Ubuntu 16.04 LTS\") {\n            Deployment_Node(oracle2, \"Oracle - Secondary\", \"Oracle 12c\") {\n                ContainerDb(db2, \"Database\", \"Relational Database Schema\", \"Stores user registration information, hashed authentication credentials, access logs, etc.\")\n            }\n        }\n    }\n\n    Rel(mobile, api, \"Makes API calls to\", \"json/HTTPS\")\n    Rel(spa, api, \"Makes API calls to\", \"json/HTTPS\")\n    Rel_U(web, spa, \"Delivers to the customer's web browser\")\n    Rel(api, db, \"Reads from and writes to\", \"JDBC\")\n    Rel(api, db2, \"Reads from and writes to\", \"JDBC\")\n    Rel_R(db, db2, \"Replicates data to\")\n\n    UpdateRelStyle(spa, api, \$offsetY=\"-40\")\n    UpdateRelStyle(web, spa, \$offsetY=\"-40\")\n    UpdateRelStyle(api, db, \$offsetY=\"-20\", \$offsetX=\"5\")\n    UpdateRelStyle(api, db2, \$offsetX=\"-40\", \$offsetY=\"-20\")\n    UpdateRelStyle(db, db2, \$offsetY=\"-10\")",
      ),
    ],
  ),
  DiagramSample(
    id: "class",
    title: "Class",
    description:
        "Show classes, their members, and the relationships between them.",
    diagramType: "class",
    beta: false,
    tier: 1,
    source:
        "---\nconfig:\n  class:\n    hierarchicalNamespaces: false\n---\nclassDiagram\n    namespace Earth.Volcano.Summit {\n        class Crater {\n            +erupt()\n        }\n    }\n    namespace Earth.Volcano.Slope {\n        class LavaFlow {\n            +buildLand()\n        }\n    }\n    namespace Earth {\n        class Hotspot {\n            +meltRock()\n        }\n    }\n    Hotspot --> Crater : feeds\n    Hotspot --> LavaFlow : feeds",
    showcaseSources: <String>[
      "---\nconfig:\n  class:\n    hierarchicalNamespaces: false\n---\nclassDiagram\n    namespace Earth.Volcano.Summit {\n        class Crater {\n            +erupt()\n        }\n    }\n    namespace Earth.Volcano.Slope {\n        class LavaFlow {\n            +buildLand()\n        }\n    }\n    namespace Earth {\n        class Hotspot {\n            +meltRock()\n        }\n    }\n    Hotspot --> Crater : feeds\n    Hotspot --> LavaFlow : feeds",
      "---\ntitle: Reef animal example\n---\nclassDiagram\n    note \"From Turtle till Whale\"\n    Animal <|-- Turtle\n    note for Turtle \"can swim<br>can dive<br>can nest on beaches<br>can live for decades\"\n    Animal <|-- Shark\n    Animal <|-- Whale\n    Animal : +int age\n    Animal : +String name\n    Animal: +isMammal()\n    Animal: +migrate()\n    class Turtle{\n        +String shellColor\n        +swim()\n        +nest()\n    }\n    class Shark{\n        -int sizeInFeet\n        -canHunt()\n    }\n    class Whale{\n        +bool is_humpback\n        +sing()\n    }",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. namespace Earth.Volcano.Summit {",
        source:
            "---\nconfig:\n  class:\n    hierarchicalNamespaces: false\n---\nclassDiagram\n    namespace Earth.Volcano.Summit {\n        class Crater {\n            +erupt()\n        }\n    }\n    namespace Earth.Volcano.Slope {\n        class LavaFlow {\n            +buildLand()\n        }\n    }\n    namespace Earth {\n        class Hotspot {\n            +meltRock()\n        }\n    }\n    Hotspot --> Crater : feeds\n    Hotspot --> LavaFlow : feeds",
      ),
      PlaygroundSampleItem(
        label: "2. Reef animal example",
        source:
            "---\ntitle: Reef animal example\n---\nclassDiagram\n    note \"From Turtle till Whale\"\n    Animal <|-- Turtle\n    note for Turtle \"can swim<br>can dive<br>can nest on beaches<br>can live for decades\"\n    Animal <|-- Shark\n    Animal <|-- Whale\n    Animal : +int age\n    Animal : +String name\n    Animal: +isMammal()\n    Animal: +migrate()\n    class Turtle{\n        +String shellColor\n        +swim()\n        +nest()\n    }\n    class Shark{\n        -int sizeInFeet\n        -canHunt()\n    }\n    class Whale{\n        +bool is_humpback\n        +sing()\n    }",
      ),
      PlaygroundSampleItem(
        label: "3. Animal example",
        source:
            "---\ntitle: Animal example\n---\nclassDiagram\n    note \"From Duck till Zebra\"\n    Animal <|-- Duck\n    note for Duck \"can fly<br>can swim<br>can dive<br>can help in debugging\"\n    Animal <|-- Fish\n    Animal <|-- Zebra\n    Animal : +int age\n    Animal : +String gender\n    Animal: +isMammal()\n    Animal: +mate()\n    class Duck{\n        +String beakColor\n        +swim()\n        +quack()\n    }\n    class Fish{\n        -int sizeInFeet\n        -canEat()\n    }\n    class Zebra{\n        +bool is_wild\n        +run()\n    }",
      ),
      PlaygroundSampleItem(
        label: "4. class Customer {",
        source:
            "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nclassDiagram\n  class Customer {\n    +String name\n    +String email\n  }\n  class Order {\n    +String id\n    +Date placedAt\n    +total() Money\n  }\n  class LineItem {\n    +int quantity\n  }\n  class Payment {\n    <<interface>>\n    +authorize() bool\n  }\n  Customer \"1\" --> \"*\" Order : places\n  Order \"1\" *-- \"*\" LineItem : contains\n  Order --> Payment : settled by",
      ),
      PlaygroundSampleItem(
        label: "5. namespace Platform {",
        source:
            "classDiagram\n    namespace Platform {\n        namespace Auth {\n            class UserService {\n                +login()\n                +logout()\n            }\n        }\n        namespace Data {\n            class Repository {\n                +find()\n                +save()\n            }\n        }\n        class Gateway {\n            +route()\n        }\n    }\n    Gateway --> UserService : delegates\n    Gateway --> Repository : delegates",
      ),
      PlaygroundSampleItem(
        label: "6. namespace Company.Engineering.Backend {",
        source:
            "---\nconfig:\n  class:\n    hierarchicalNamespaces: false\n---\nclassDiagram\n    namespace Company.Engineering.Backend {\n        class Developer {\n            +writeCode()\n        }\n    }\n    namespace Company.Engineering.Frontend {\n        class Designer {\n            +createMockup()\n        }\n    }\n    namespace Company {\n        class CEO {\n            +makeDecisions()\n        }\n    }\n    CEO --> Developer : oversees\n    CEO --> Designer : oversees",
      ),
    ],
  ),
  DiagramSample(
    id: "er",
    title: "Entity relationship",
    description:
        "Show entities, their attributes, and the relationships between them.",
    diagramType: "er",
    beta: false,
    tier: 1,
    source:
        "erDiagram\n    subgraph title1\n        CUSTOMER\n        CUSTOMER {\n            string name\n            string custNumber\n            string sector\n        }\n    end\n    subgraph title2\n        CAR ||--o{ NAMED-DRIVER : allows\n        subgraph title3\n            PERSON\n            PERSON {\n                string firstName\n                string lastName\n                int age\n            }\n        end\n    end",
    showcaseSources: <String>[
      "erDiagram\n    subgraph title1\n        CUSTOMER\n        CUSTOMER {\n            string name\n            string custNumber\n            string sector\n        }\n    end\n    subgraph title2\n        CAR ||--o{ NAMED-DRIVER : allows\n        subgraph title3\n            PERSON\n            PERSON {\n                string firstName\n                string lastName\n                int age\n            }\n        end\n    end",
      "erDiagram\n    CAR ||--o{ NAMED-DRIVER : allows\n    CAR {\n        string registrationNumber PK\n        string make\n        string model\n        string[] parts\n    }\n    PERSON ||--o{ NAMED-DRIVER : is\n    PERSON {\n        string driversLicense PK \"The license #\"\n        string(99) firstName \"Only 99 characters are allowed\"\n        string lastName\n        string phone UK\n        int age\n    }\n    NAMED-DRIVER {\n        string carRegistrationNumber PK, FK\n        string driverLicense PK, FK\n    }\n    MANUFACTURER only one to zero or more CAR : makes",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. CUSTOMER ||--o{ ORDER : places",
        source:
            "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nerDiagram\n  CUSTOMER ||--o{ ORDER : places\n  ORDER ||--|{ LINE_ITEM : contains\n  PRODUCT ||--o{ LINE_ITEM : \"appears in\"\n  CUSTOMER {\n    string name\n    string email\n  }\n  ORDER {\n    int id\n    date placedAt\n  }\n  LINE_ITEM {\n    int quantity\n    float price\n  }\n  PRODUCT {\n    string sku\n    string title\n  }",
      ),
      PlaygroundSampleItem(
        label: "2. CAR ||--o{ NAMED-DRIVER : allows",
        source:
            "erDiagram\n    CAR ||--o{ NAMED-DRIVER : allows\n    CAR {\n        string registrationNumber PK\n        string make\n        string model\n        string[] parts\n    }\n    PERSON ||--o{ NAMED-DRIVER : is\n    PERSON {\n        string driversLicense PK \"The license #\"\n        string(99) firstName \"Only 99 characters are allowed\"\n        string lastName\n        string phone UK\n        int age\n    }\n    NAMED-DRIVER {\n        string carRegistrationNumber PK, FK\n        string driverLicense PK, FK\n    }\n    MANUFACTURER only one to zero or more CAR : makes",
      ),
      PlaygroundSampleItem(
        label: "3. direction TB",
        source:
            "erDiagram\n    direction TB\n    CUSTOMER ||--o{ ORDER : places\n    CUSTOMER {\n        string name\n        string custNumber\n        string sector\n    }\n    ORDER ||--|{ LINE-ITEM : contains\n    ORDER {\n        int orderNumber\n        string deliveryAddress\n    }\n    LINE-ITEM {\n        string productCode\n        int quantity\n        float pricePerUnit\n    }",
      ),
      PlaygroundSampleItem(
        label: "4. direction LR",
        source:
            "erDiagram\n    direction LR\n    CUSTOMER ||--o{ ORDER : places\n    CUSTOMER {\n        string name\n        string custNumber\n        string sector\n    }\n    ORDER ||--|{ LINE-ITEM : contains\n    ORDER {\n        int orderNumber\n        string deliveryAddress\n    }\n    LINE-ITEM {\n        string productCode\n        int quantity\n        float pricePerUnit\n    }",
      ),
      PlaygroundSampleItem(
        label: "5. subgraph title1",
        source:
            "erDiagram\n    subgraph title1\n        CUSTOMER\n        CUSTOMER {\n            string name\n            string custNumber\n            string sector\n        }\n    end\n    subgraph title2\n        CAR ||--o{ NAMED-DRIVER : allows\n        subgraph title3\n            PERSON\n            PERSON {\n                string firstName\n                string lastName\n                int age\n            }\n        end\n    end",
      ),
      PlaygroundSampleItem(
        label: "6. CAR {",
        source:
            "erDiagram\n    CAR {\n        string registrationNumber\n        string make\n        string model\n    }\n    PERSON {\n        string firstName\n        string lastName\n        int age\n    }\n    PERSON:::foo ||--|| CAR : owns\n    PERSON o{--|| HOUSE:::bar : has\n\n    classDef default fill:#f9f,stroke-width:4px\n    classDef foo stroke:#f00\n    classDef bar stroke:#0f0\n    classDef foobar stroke:#00f",
      ),
    ],
  ),
  DiagramSample(
    id: "eventmodeling",
    title: "Event modeling",
    description:
        "Show how commands, events, and views change a system over time.",
    diagramType: "eventmodeling",
    beta: false,
    tier: 2,
    source:
        "eventmodeling\n\ntimeframe 01 ui CartUI\ntimeframe 02 command AddItem [[AddItem01]]\ntimeframe 03 event ItemAdded [[ItemAdded]]\ntimeframe 04 command AddItem [[AddItem02]]\ntimeframe 05 event ItemAdded [[ItemAdded]]\n\ndata AddItem01 {\n  description: 'john'\n  image: 'avatar_john'\n  price: 20.4\n}\n\ndata AddItem02 {\n  description: 'jack'\n  image: 'avatar_jack'\n  price: 12.5\n}\n\ndata ItemAdded {\n  description: string\n  image: string\n  price: number\n}",
    showcaseSources: <String>[
      "eventmodeling\n\ntimeframe 01 ui CartUI\ntimeframe 02 command AddItem [[AddItem01]]\ntimeframe 03 event ItemAdded [[ItemAdded]]\ntimeframe 04 command AddItem [[AddItem02]]\ntimeframe 05 event ItemAdded [[ItemAdded]]\n\ndata AddItem01 {\n  description: 'john'\n  image: 'avatar_john'\n  price: 20.4\n}\n\ndata AddItem02 {\n  description: 'jack'\n  image: 'avatar_jack'\n  price: 12.5\n}\n\ndata ItemAdded {\n  description: string\n  image: string\n  price: number\n}",
      "eventmodeling\n\ntimeframe 01 ui CartUI\ntimeframe 02 command AddItem\ntimeframe 03 event ItemAdded\n\nresetframe 04 event External.InventoryChanged\ntimeframe 05 processor InventoryProcessor\ntimeframe 06 command ChangeInventory\ntimeframe 07 event Cart.InventoryChanged",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. timeframe 01 ui CartUI",
        source:
            "eventmodeling\n\ntimeframe 01 ui CartUI\ntimeframe 02 command AddItem { description: string }\ntimeframe 03 event ItemAdded { description: string }",
      ),
      PlaygroundSampleItem(
        label: "2. tf 01 ui CartUI",
        source:
            "eventmodeling\n\ntf 01 ui CartUI\ntf 02 cmd AddItem [[AddItem01]]\ntf 03 evt ItemAdded [[ItemAdded]]\ntf 04 cmd AddItem [[AddItem02]]\ntf 05 evt ItemAdded [[ItemAdded]]\n\ndata AddItem01 {\n  description: 'john'\n  image: 'avatar_john'\n  price: 20.4\n}\n\ndata AddItem02 {\n  description: 'jack'\n  image: 'avatar_jack'\n  price: 12.5\n}\n\ndata ItemAdded {\n  description: string\n  image: string\n  price: number\n}",
      ),
      PlaygroundSampleItem(
        label: "3. timeframe 01 ui CartUI",
        source:
            "eventmodeling\n\ntimeframe 01 ui CartUI\ntimeframe 02 command AddItem [[AddItem01]]\ntimeframe 03 event ItemAdded [[ItemAdded]]\ntimeframe 04 command AddItem [[AddItem02]]\ntimeframe 05 event ItemAdded [[ItemAdded]]\n\ndata AddItem01 {\n  description: 'john'\n  image: 'avatar_john'\n  price: 20.4\n}\n\ndata AddItem02 {\n  description: 'jack'\n  image: 'avatar_jack'\n  price: 12.5\n}\n\ndata ItemAdded {\n  description: string\n  image: string\n  price: number\n}",
      ),
      PlaygroundSampleItem(
        label: "4. tf 01 ui CartUI",
        source:
            "eventmodeling\n\ntf 01 ui CartUI\ntf 02 cmd AddItem\ntf 03 evt ItemAdded\n\nrf 04 evt External.InventoryChanged\ntf 05 pcr InventoryProcessor\ntf 06 cmd ChangeInventory\ntf 07 evt Cart.InventoryChanged",
      ),
      PlaygroundSampleItem(
        label: "5. timeframe 01 ui CartUI",
        source:
            "eventmodeling\n\ntimeframe 01 ui CartUI\ntimeframe 02 command AddItem\ntimeframe 03 event ItemAdded\n\nresetframe 04 event External.InventoryChanged\ntimeframe 05 processor InventoryProcessor\ntimeframe 06 command ChangeInventory\ntimeframe 07 event Cart.InventoryChanged",
      ),
      PlaygroundSampleItem(
        label: "6. rf 02 evt CartCreated",
        source:
            "eventmodeling\n\nrf 02 evt CartCreated\nrf 03 evt ItemAdded\nrf 04 evt ItemRemoved\nrf 05 evt CartCleared\ntf 01 rmo CartUI ->> 02 ->> 03 ->> 04 ->> 05",
      ),
    ],
  ),
  DiagramSample(
    id: "gantt",
    title: "Gantt",
    description: "Show the tasks of a project on a timeline.",
    diagramType: "gantt",
    beta: false,
    tier: 1,
    source:
        "gantt\n    title Git Issues - days since last update\n    dateFormat X\n    axisFormat %s\n    section Issue19062\n    71   : 0, 71\n    section Issue19401\n    36   : 0, 36\n    section Issue193\n    34   : 0, 34\n    section Issue7441\n    9    : 0, 9\n    section Issue1300\n    5    : 0, 5",
    showcaseSources: <String>[
      "gantt\n    title Git Issues - days since last update\n    dateFormat X\n    axisFormat %s\n    section Issue19062\n    71   : 0, 71\n    section Issue19401\n    36   : 0, 36\n    section Issue193\n    34   : 0, 34\n    section Issue7441\n    9    : 0, 9\n    section Issue1300\n    5    : 0, 5",
      "gantt\n    title A Gantt Diagram\n    %% This is a comment\n    dateFormat YYYY-MM-DD\n    section Section\n        A task          :a1, 2014-01-01, 30d\n        Another task    :after a1, 20d\n    section Another\n        Task in Another :2014-01-12, 12d\n        another task    :24d",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. title A Gantt Diagram",
        source:
            "gantt\n    title A Gantt Diagram\n    dateFormat YYYY-MM-DD\n    section Section\n        A task          :a1, 2014-01-01, 30d\n        Another task    :after a1, 20d\n    section Another\n        Task in Another :2014-01-12, 12d\n        another task    :24d",
      ),
      PlaygroundSampleItem(
        label: "2. dateFormat  YYYY-MM-DD",
        source:
            "gantt\n    dateFormat  YYYY-MM-DD\n    title       Adding GANTT diagram functionality to mermaid\n    excludes    weekends\n    %% (`excludes` accepts specific dates in YYYY-MM-DD format, days of the week (\"sunday\") or \"weekends\", but not the word \"weekdays\".)\n\n    section A section\n    Completed task            :done,    des1, 2014-01-06,2014-01-08\n    Active task               :active,  des2, 2014-01-09, 3d\n    Future task               :         des3, after des2, 5d\n    Future task2              :         des4, after des3, 5d\n\n    section Critical tasks\n    Completed task in the critical line :crit, done, 2014-01-06,24h\n    Implement parser and jison          :crit, done, after des1, 2d\n    Create tests for parser             :crit, active, 3d\n    Future task in critical line        :crit, 5d\n    Create tests for renderer           :2d\n    Add to mermaid                      :until isadded\n    Functionality added                 :milestone, isadded, 2014-01-25, 0d\n\n    section Documentation\n    Describe gantt syntax               :active, a1, after des1, 3d\n    Add gantt diagram to demo page      :after a1  , 20h\n    Add another diagram to demo page    :doc1, after a1  , 48h\n\n    section Last section\n    Describe gantt syntax               :after doc1, 3d\n    Add gantt diagram to demo page      :20h\n    Add another diagram to demo page    :48h",
      ),
      PlaygroundSampleItem(
        label: "3. title A Gantt Diagram",
        source:
            "---\ndisplayMode: compact\n---\ngantt\n    title A Gantt Diagram\n    dateFormat  YYYY-MM-DD\n\n    section Section\n    A task           :a1, 2014-01-01, 30d\n    Another task     :a2, 2014-01-20, 25d\n    Another one      :a3, 2014-02-10, 20d",
      ),
      PlaygroundSampleItem(
        label: "4. title A Gantt Diagram",
        source:
            "gantt\n    title A Gantt Diagram\n    %% This is a comment\n    dateFormat YYYY-MM-DD\n    section Section\n        A task          :a1, 2014-01-01, 30d\n        Another task    :after a1, 20d\n    section Another\n        Task in Another :2014-01-12, 12d\n        another task    :24d",
      ),
      PlaygroundSampleItem(
        label: "5. title Git Issues - days since last update",
        source:
            "gantt\n    title Git Issues - days since last update\n    dateFormat X\n    axisFormat %s\n    section Issue19062\n    71   : 0, 71\n    section Issue19401\n    36   : 0, 36\n    section Issue193\n    34   : 0, 34\n    section Issue7441\n    9    : 0, 9\n    section Issue1300\n    5    : 0, 5",
      ),
      PlaygroundSampleItem(
        label: "6. title Timeline - Gantt Sampler",
        source:
            "---\n    # Frontmatter config, YAML comments\n    title: Ignored if specified in chart\n    displayMode: compact     #gantt specific setting but works at this level too\n    config:\n#        theme: forest\n#        themeCSS: \" #item36 { fill: CadetBlue } \"\n        themeCSS: \" // YAML supports multiline strings using a newline markers: \\n\n            #item36 { fill: CadetBlue }       \\n\n\n            // Custom marker workaround CSS from forum (below)    \\n\n            rect[id^=workaround] { height: calc(100% - 50px) ; transform: translate(9px, 25px); y: 0; width: 1.5px; stroke: none; fill: red; }   \\n\n            text[id^=workaround] { fill: red; y: 100%; font-size: 15px;}\n        \"\n        gantt:\n            useWidth: 400\n            rightPadding: 0\n            topAxis: true  #false\n            numberSectionStyles: 2\n---\ngantt\n    title Timeline - Gantt Sampler\n    dateFormat YYYY\n    axisFormat %y\n    %% this next line doesn't recognize 'decade' or 'year', but will silently ignore\n    tickInterval 1decade\n\n    section Issue19062\n    71   :            item71, 1900, 1930\n    section Issue19401\n    36   :            item36, 1913, 1935\n    section Issue1300\n    94   :            item94, 1910, 1915\n    5    :            item5,  1920, 1925\n    0    : milestone, item0,  1918, 1s\n    9    : vert,              1906, 1s   %% not yet official\n    64   : workaround,        1923, 1s   %% custom CSS object https://github.com/mermaid-js/mermaid/issues/3250",
      ),
    ],
  ),
  DiagramSample(
    id: "git",
    title: "Git graph",
    description: "Show commits, branches, and merges.",
    diagramType: "git",
    beta: false,
    tier: 1,
    source:
        "gitGraph\n        commit id: \"ZERO\"\n        branch develop\n        branch release\n        commit id:\"A\"\n        checkout main\n        commit id:\"ONE\"\n        checkout develop\n        commit id:\"B\"\n        checkout main\n        merge develop id:\"MERGE\"\n        commit id:\"TWO\"\n        checkout release\n        cherry-pick id:\"MERGE\" parent:\"B\"\n        commit id:\"THREE\"\n        checkout develop\n        commit id:\"C\"",
    showcaseSources: <String>[
      "gitGraph\n        commit id: \"ZERO\"\n        branch develop\n        branch release\n        commit id:\"A\"\n        checkout main\n        commit id:\"ONE\"\n        checkout develop\n        commit id:\"B\"\n        checkout main\n        merge develop id:\"MERGE\"\n        commit id:\"TWO\"\n        checkout release\n        cherry-pick id:\"MERGE\" parent:\"B\"\n        commit id:\"THREE\"\n        checkout develop\n        commit id:\"C\"",
      "---\nconfig:\n  logLevel: 'debug'\n  theme: 'neutral'\n---\n      gitGraph\n        commit\n        branch hotfix\n        checkout hotfix\n        commit\n        branch develop\n        checkout develop\n        commit id:\"ash\" tag:\"abc\"\n        branch featureB\n        checkout featureB\n        commit type:HIGHLIGHT\n        checkout main\n        checkout hotfix\n        commit type:NORMAL\n        checkout develop\n        commit type:REVERSE\n        checkout featureB\n        commit\n        checkout main\n        merge hotfix\n        checkout featureB\n        commit\n        checkout develop\n        branch featureA\n        commit\n        checkout develop\n        merge hotfix\n        checkout featureA\n        commit\n        checkout featureB\n        commit\n        checkout develop\n        merge featureA\n        branch release\n        checkout release\n        commit\n        checkout main\n        commit\n        checkout release\n        merge main\n        checkout develop\n        merge release",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. commit",
        source:
            "---\nconfig:\n  logLevel: 'debug'\n  theme: 'base'\n  gitGraph:\n    showBranches: false\n---\n      gitGraph\n        commit\n        branch hotfix\n        checkout hotfix\n        commit\n        branch develop\n        checkout develop\n        commit id:\"ash\" tag:\"abc\"\n        branch featureB\n        checkout featureB\n        commit type:HIGHLIGHT\n        checkout main\n        checkout hotfix\n        commit type:NORMAL\n        checkout develop\n        commit type:REVERSE\n        checkout featureB\n        commit\n        checkout main\n        merge hotfix\n        checkout featureB\n        commit\n        checkout develop\n        branch featureA\n        commit\n        checkout develop\n        merge hotfix\n        checkout featureA\n        commit\n        checkout featureB\n        commit\n        checkout develop\n        merge featureA\n        branch release\n        checkout release\n        commit\n        checkout main\n        commit\n        checkout release\n        merge main\n        checkout develop\n        merge release",
      ),
      PlaygroundSampleItem(
        label: "2. commit",
        source:
            "---\nconfig:\n  logLevel: 'debug'\n  theme: 'base'\n  gitGraph:\n    showBranches: false\n    showCommitLabel: false\n---\n      gitGraph\n        commit\n        branch hotfix\n        checkout hotfix\n        commit\n        branch develop\n        checkout develop\n        commit id:\"ash\"\n        branch featureB\n        checkout featureB\n        commit type:HIGHLIGHT\n        checkout main\n        checkout hotfix\n        commit type:NORMAL\n        checkout develop\n        commit type:REVERSE\n        checkout featureB\n        commit\n        checkout main\n        merge hotfix\n        checkout featureB\n        commit\n        checkout develop\n        branch featureA\n        commit\n        checkout develop\n        merge hotfix\n        checkout featureA\n        commit\n        checkout featureB\n        commit\n        checkout develop\n        merge featureA\n        branch release\n        checkout release\n        commit\n        checkout main\n        commit\n        checkout release\n        merge main\n        checkout develop\n        merge release",
      ),
      PlaygroundSampleItem(
        label: "3. commit",
        source:
            "---\nconfig:\n  logLevel: 'debug'\n  theme: 'base'\n---\n      gitGraph\n        commit\n        branch hotfix\n        checkout hotfix\n        commit\n        branch develop\n        checkout develop\n        commit id:\"ash\" tag:\"abc\"\n        branch featureB\n        checkout featureB\n        commit type:HIGHLIGHT\n        checkout main\n        checkout hotfix\n        commit type:NORMAL\n        checkout develop\n        commit type:REVERSE\n        checkout featureB\n        commit\n        checkout main\n        merge hotfix\n        checkout featureB\n        commit\n        checkout develop\n        branch featureA\n        commit\n        checkout develop\n        merge hotfix\n        checkout featureA\n        commit\n        checkout featureB\n        commit\n        checkout develop\n        merge featureA\n        branch release\n        checkout release\n        commit\n        checkout main\n        commit\n        checkout release\n        merge main\n        checkout develop\n        merge release",
      ),
      PlaygroundSampleItem(
        label: "4. commit",
        source:
            "---\nconfig:\n  logLevel: 'debug'\n  theme: 'forest'\n---\n      gitGraph\n        commit\n        branch hotfix\n        checkout hotfix\n        commit\n        branch develop\n        checkout develop\n        commit id:\"ash\" tag:\"abc\"\n        branch featureB\n        checkout featureB\n        commit type:HIGHLIGHT\n        checkout main\n        checkout hotfix\n        commit type:NORMAL\n        checkout develop\n        commit type:REVERSE\n        checkout featureB\n        commit\n        checkout main\n        merge hotfix\n        checkout featureB\n        commit\n        checkout develop\n        branch featureA\n        commit\n        checkout develop\n        merge hotfix\n        checkout featureA\n        commit\n        checkout featureB\n        commit\n        checkout develop\n        merge featureA\n        branch release\n        checkout release\n        commit\n        checkout main\n        commit\n        checkout release\n        merge main\n        checkout develop\n        merge release",
      ),
      PlaygroundSampleItem(
        label: "5. commit type:HIGHLIGHT",
        source:
            "---\nconfig:\n  logLevel: 'debug'\n  theme: 'default'\n---\n      gitGraph\n        commit type:HIGHLIGHT\n        branch hotfix\n        checkout hotfix\n        commit\n        branch develop\n        checkout develop\n        commit id:\"ash\" tag:\"abc\"\n        branch featureB\n        checkout featureB\n        commit type:HIGHLIGHT\n        checkout main\n        checkout hotfix\n        commit type:NORMAL\n        checkout develop\n        commit type:REVERSE\n        checkout featureB\n        commit\n        checkout main\n        merge hotfix\n        checkout featureB\n        commit\n        checkout develop\n        branch featureA\n        commit\n        checkout develop\n        merge hotfix\n        checkout featureA\n        commit\n        checkout featureB\n        commit\n        checkout develop\n        merge featureA\n        branch release\n        checkout release\n        commit\n        checkout main\n        commit\n        checkout release\n        merge main\n        checkout develop\n        merge release",
      ),
      PlaygroundSampleItem(
        label: "6. commit",
        source:
            "---\nconfig:\n  logLevel: 'debug'\n  theme: 'neutral'\n---\n      gitGraph\n        commit\n        branch hotfix\n        checkout hotfix\n        commit\n        branch develop\n        checkout develop\n        commit id:\"ash\" tag:\"abc\"\n        branch featureB\n        checkout featureB\n        commit type:HIGHLIGHT\n        checkout main\n        checkout hotfix\n        commit type:NORMAL\n        checkout develop\n        commit type:REVERSE\n        checkout featureB\n        commit\n        checkout main\n        merge hotfix\n        checkout featureB\n        commit\n        checkout develop\n        branch featureA\n        commit\n        checkout develop\n        merge hotfix\n        checkout featureA\n        commit\n        checkout featureB\n        commit\n        checkout develop\n        merge featureA\n        branch release\n        checkout release\n        commit\n        checkout main\n        commit\n        checkout release\n        merge main\n        checkout develop\n        merge release",
      ),
    ],
  ),
  DiagramSample(
    id: "info",
    title: "Info",
    description: "Display package version info.",
    diagramType: "info",
    beta: false,
    tier: 1,
    source: "info",
    showcaseSources: <String>["info", "info showInfo"],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(label: "1. info", source: "info"),
      PlaygroundSampleItem(label: "2. info showInfo", source: "info showInfo"),
      PlaygroundSampleItem(
        label: "3. info with frontmatter",
        source: "---\ntitle: Engine Info\n---\ninfo\n  showInfo",
      ),
    ],
  ),
  DiagramSample(
    id: "journey",
    title: "User journey",
    description: "Show the steps of a task and how satisfying each one is.",
    diagramType: "journey",
    beta: false,
    tier: 2,
    source:
        "journey\n    title My working day\n    section Go to work\n      Make tea: 5: Me\n      Go upstairs: 3: Me\n      Do work: 1: Me, Cat\n    section Go home\n      Go downstairs: 5: Me\n      Sit down: 5: Me",
    showcaseSources: <String>[
      "journey\n    title My working day\n    section Go to work\n      Make tea: 5: Me\n      Go upstairs: 3: Me\n      Do work: 1: Me, Cat\n    section Go home\n      Go downstairs: 5: Me\n      Sit down: 5: Me",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. title My working day",
        source:
            "journey\n    title My working day\n    section Go to work\n      Make tea: 5: Me\n      Go upstairs: 3: Me\n      Do work: 1: Me, Cat\n    section Go home\n      Go downstairs: 5: Me\n      Sit down: 5: Me",
      ),
      PlaygroundSampleItem(
        label: "2. E-Commerce Checkout Journey",
        source:
            "journey\n    title E-Commerce Checkout Journey\n    section Discovery\n      Browse catalog: 5: Customer\n      Compare specs: 4: Customer\n    section Checkout\n      Enter shipping address: 3: Customer\n      Payment verification: 2: Customer, PaymentGateway\n      Order confirmation: 5: Customer, Fulfillment",
      ),
      PlaygroundSampleItem(
        label: "3. Developer Onboarding Journey",
        source:
            "journey\n    title Developer Onboarding Journey\n    section Setup\n      Clone repository: 5: Developer\n      Install SDKs: 3: Developer, IT\n      Run test suite: 5: Developer\n    section First PR\n      Implement feature: 4: Developer\n      Code review: 4: Developer, Reviewer\n      Deploy to production: 5: Developer, CI",
      ),
    ],
  ),
  DiagramSample(
    id: "kanban",
    title: "Kanban",
    description: "Show tasks in columns by status.",
    diagramType: "kanban",
    beta: false,
    tier: 2,
    source:
        "kanban\ntodo[Todo]\n  id3[Update Database Function]@{ ticket: MC-2037, assigned: 'knsv', priority: 'High' }",
    showcaseSources: <String>[
      "kanban\ntodo[Todo]\n  id3[Update Database Function]@{ ticket: MC-2037, assigned: 'knsv', priority: 'High' }",
      "---\nconfig:\n  kanban:\n    ticketBaseUrl: 'https://mermaidchart.atlassian.net/browse/#TICKET#'\n---\nkanban\n  Todo\n    [Create Documentation]\n    docs[Create Blog about the new diagram]\n  [In progress]\n    id6[Create renderer so that it works in all cases. We also add some extra text here for testing purposes. And some more just for the extra flare.]\n  id9[Ready for deploy]\n    id8[Design grammar]@{ assigned: 'knsv' }\n  id10[Ready for test]\n    id4[Create parsing tests]@{ ticket: MC-2038, assigned: 'K.Sveidqvist', priority: 'High' }\n    id66[last item]@{ priority: 'Very Low', assigned: 'knsv' }\n  id11[Done]\n    id5[define getData]\n    id2[Title of diagram is more than 100 chars when user duplicates diagram with 100 char]@{ ticket: MC-2036, priority: 'Very High'}\n    id3[Update DB function]@{ ticket: MC-2037, assigned: knsv, priority: 'High' }\n\n  id12[Can't reproduce]\n    id3[Weird flickering in Firefox]",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. column1[Column Title]",
        source: "kanban\n  column1[Column Title]\n    task1[Task Description]",
      ),
      PlaygroundSampleItem(
        label: "2. todo[Todo]",
        source:
            "kanban\ntodo[Todo]\n  id3[Update Database Function]@{ ticket: MC-2037, assigned: 'knsv', priority: 'High' }",
      ),
      PlaygroundSampleItem(
        label: "3. Todo",
        source:
            "---\nconfig:\n  kanban:\n    ticketBaseUrl: 'https://mermaidchart.atlassian.net/browse/#TICKET#'\n---\nkanban\n  Todo\n    [Create Documentation]\n    docs[Create Blog about the new diagram]\n  [In progress]\n    id6[Create renderer so that it works in all cases. We also add some extra text here for testing purposes. And some more just for the extra flare.]\n  id9[Ready for deploy]\n    id8[Design grammar]@{ assigned: 'knsv' }\n  id10[Ready for test]\n    id4[Create parsing tests]@{ ticket: MC-2038, assigned: 'K.Sveidqvist', priority: 'High' }\n    id66[last item]@{ priority: 'Very Low', assigned: 'knsv' }\n  id11[Done]\n    id5[define getData]\n    id2[Title of diagram is more than 100 chars when user duplicates diagram with 100 char]@{ ticket: MC-2036, priority: 'Very High'}\n    id3[Update DB function]@{ ticket: MC-2037, assigned: knsv, priority: 'High' }\n\n  id12[Can't reproduce]\n    id3[Weird flickering in Firefox]",
      ),
    ],
  ),
  DiagramSample(
    id: "mindmap",
    title: "Mindmap",
    description: "Show ideas branching out from a central topic.",
    diagramType: "mindmap",
    beta: false,
    tier: 1,
    source:
        "mindmap\n  root((Hawaiʻi))\n    History\n      Old legends\n      ::icon(fa fa-book)\n      Voyaging\n        Polynesian navigators who sailed by the stars\n    Nature\n      Mountains<br/>and volcanoes\n      Ocean life\n        Reef\n            Sea turtles\n            Monk seals\n            Parrotfish\n    Culture\n      Hula and lei\n      ʻUkulele",
    showcaseSources: <String>[
      "mindmap\n  root((Hawaiʻi))\n    History\n      Old legends\n      ::icon(fa fa-book)\n      Voyaging\n        Polynesian navigators who sailed by the stars\n    Nature\n      Mountains<br/>and volcanoes\n      Ocean life\n        Reef\n            Sea turtles\n            Monk seals\n            Parrotfish\n    Culture\n      Hula and lei\n      ʻUkulele",
      "mindmap\n    id1[\"`**Pele** is the\ngoddess of volcanoes\nUnicode works too: 🌋`\"]\n      id2[\"`She lives in **the** crater of Kīlauea... a *very old story* that is still told today`\"]\n      id3[Lava builds new land]",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. root((Hawaiʻi))",
        source:
            "mindmap\n  root((Hawaiʻi))\n    History\n      Old legends\n      ::icon(fa fa-book)\n      Voyaging\n        Polynesian navigators who sailed by the stars\n    Nature\n      Mountains<br/>and volcanoes\n      Ocean life\n        Reef\n            Sea turtles\n            Monk seals\n            Parrotfish\n    Culture\n      Hula and lei\n      ʻUkulele",
      ),
      PlaygroundSampleItem(
        label: "2. id1[\"`**Pele** is the",
        source:
            "mindmap\n    id1[\"`**Pele** is the\ngoddess of volcanoes\nUnicode works too: 🌋`\"]\n      id2[\"`She lives in **the** crater of Kīlauea... a *very old story* that is still told today`\"]\n      id3[Lava builds new land]",
      ),
      PlaygroundSampleItem(
        label: "3. root((mindmap))",
        source:
            "mindmap\n  root((mindmap))\n    Origins\n      Long history\n      ::icon(fa fa-book)\n      Popularization\n        British popular psychology author Tony Buzan\n    Research\n      On effectiveness<br/>and features\n      On Automatic creation\n        Uses\n            Creative techniques\n            Strategic planning\n            Argument mapping\n    Tools\n      Pen and paper\n      Mermaid",
      ),
      PlaygroundSampleItem(
        label: "4. Root",
        source:
            "mindmap\n    Root\n        A\n        ::icon(fa fa-book)\n        B(B)\n        ::icon(mdi mdi-skull-outline)",
      ),
      PlaygroundSampleItem(
        label: "5. Root",
        source:
            "mindmap\n    Root\n        A[A]\n        :::urgent large\n        B(B)\n        C",
      ),
      PlaygroundSampleItem(
        label: "6. id1[\"`**Root** with",
        source:
            "mindmap\n    id1[\"`**Root** with\na second line\nUnicode works too: 🤓`\"]\n      id2[\"`The dog in **the** hog... a *very long text* that wraps to a new line`\"]\n      id3[Regular labels still works]",
      ),
    ],
  ),
  DiagramSample(
    id: "packet",
    title: "Packet",
    description: "Show the fields of a network packet.",
    diagramType: "packet",
    beta: false,
    tier: 2,
    source:
        "---\ntitle: \"TCP Packet\"\n---\npacket\n0-15: \"Source Port\"\n16-31: \"Destination Port\"\n32-63: \"Sequence Number\"\n64-95: \"Acknowledgment Number\"\n96-99: \"Data Offset\"\n100-105: \"Reserved\"\n106: \"URG\"\n107: \"ACK\"\n108: \"PSH\"\n109: \"RST\"\n110: \"SYN\"\n111: \"FIN\"\n112-127: \"Window\"\n128-143: \"Checksum\"\n144-159: \"Urgent Pointer\"\n160-191: \"(Options and Padding)\"\n192-255: \"Data (variable length)\"",
    showcaseSources: <String>[
      "---\ntitle: \"TCP Packet\"\n---\npacket\n0-15: \"Source Port\"\n16-31: \"Destination Port\"\n32-63: \"Sequence Number\"\n64-95: \"Acknowledgment Number\"\n96-99: \"Data Offset\"\n100-105: \"Reserved\"\n106: \"URG\"\n107: \"ACK\"\n108: \"PSH\"\n109: \"RST\"\n110: \"SYN\"\n111: \"FIN\"\n112-127: \"Window\"\n128-143: \"Checksum\"\n144-159: \"Urgent Pointer\"\n160-191: \"(Options and Padding)\"\n192-255: \"Data (variable length)\"",
      "---\nconfig:\n  packet:\n    showBits: true\n    bitOrder: descending\n    bitsPerRow: 16\n---\npacket\n0-7: \"DATA\"\n8-11: \"TYPE\"\n12: \"EN\"\n13-15: \"RESERVED\"",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. TCP Packet",
        source:
            "---\ntitle: \"TCP Packet\"\n---\npacket\n0-15: \"Source Port\"\n16-31: \"Destination Port\"\n32-63: \"Sequence Number\"\n64-95: \"Acknowledgment Number\"\n96-99: \"Data Offset\"\n100-105: \"Reserved\"\n106: \"URG\"\n107: \"ACK\"\n108: \"PSH\"\n109: \"RST\"\n110: \"SYN\"\n111: \"FIN\"\n112-127: \"Window\"\n128-143: \"Checksum\"\n144-159: \"Urgent Pointer\"\n160-191: \"(Options and Padding)\"\n192-255: \"Data (variable length)\"",
      ),
      PlaygroundSampleItem(
        label: "2. title UDP Packet",
        source:
            "packet\ntitle UDP Packet\n+16: \"Source Port\"\n+16: \"Destination Port\"\n32-47: \"Length\"\n48-63: \"Checksum\"\n64-95: \"Data (variable length)\"",
      ),
      PlaygroundSampleItem(
        label: "3. 0-7: \"DATA\"",
        source:
            "---\nconfig:\n  packet:\n    showBits: true\n    bitOrder: descending\n    bitsPerRow: 16\n---\npacket\n0-7: \"DATA\"\n8-11: \"TYPE\"\n12: \"EN\"\n13-15: \"RESERVED\"",
      ),
      PlaygroundSampleItem(
        label: "4. 0-15: \"Source Port\"",
        source:
            "---\nconfig:\n  packet:\n    showBits: true\n  themeVariables:\n    packet:\n      startByteColor: red\n---\npacket\n0-15: \"Source Port\"\n16-31: \"Destination Port\"\n32-63: \"Sequence Number\"",
      ),
    ],
  ),
  DiagramSample(
    id: "pie",
    title: "Pie",
    description: "Show the parts of a whole.",
    diagramType: "pie",
    beta: false,
    tier: 1,
    source:
        "pie title Fish caught by the crew\n    \"ʻAhi\" : 386\n    \"Mahimahi\" : 85\n    \"Ono\" : 15",
    showcaseSources: <String>[
      "pie title Fish caught by the crew\n    \"ʻAhi\" : 386\n    \"Mahimahi\" : 85\n    \"Ono\" : 15",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. \"ʻAhi\" : 386",
        source:
            "pie title Fish caught by the crew\n    \"ʻAhi\" : 386\n    \"Mahimahi\" : 85\n    \"Ono\" : 15",
      ),
      PlaygroundSampleItem(
        label: "2. \"Dogs\" : 386",
        source:
            "pie title Pets adopted by volunteers\n    \"Dogs\" : 386\n    \"Cats\" : 85\n    \"Rats\" : 15",
      ),
      PlaygroundSampleItem(
        label: "3. title Key elements in Product X",
        source:
            "---\nconfig:\n  pie:\n    textPosition: 0.5\n    donutHole: 0.2\n    highlightSlice: Potassium\n  themeVariables:\n    pieOuterStrokeWidth: \"5px\"\n---\npie showData\n    title Key elements in Product X\n    \"Calcium\" : 42.96\n    \"Potassium\" : 50.05\n    \"Magnesium\" : 10.01\n    \"Iron\" :  5",
      ),
    ],
  ),
  DiagramSample(
    id: "quadrant",
    title: "Quadrant chart",
    description:
        "Plot items on two axes that divide the chart into four sections.",
    diagramType: "quadrant",
    beta: false,
    tier: 2,
    source:
        "quadrantChart\n    title Reach and engagement of campaigns\n    x-axis Low Reach --> High Reach\n    y-axis Low Engagement --> High Engagement\n    quadrant-1 We should expand\n    quadrant-2 Need to promote\n    quadrant-3 Re-evaluate\n    quadrant-4 May be improved\n    Campaign A: [0.3, 0.6]\n    Campaign B: [0.45, 0.23]\n    Campaign C: [0.57, 0.69]\n    Campaign D: [0.78, 0.34]\n    Campaign E: [0.40, 0.34]\n    Campaign F: [0.35, 0.78]",
    showcaseSources: <String>[
      "quadrantChart\n    title Reach and engagement of campaigns\n    x-axis Low Reach --> High Reach\n    y-axis Low Engagement --> High Engagement\n    quadrant-1 We should expand\n    quadrant-2 Need to promote\n    quadrant-3 Re-evaluate\n    quadrant-4 May be improved\n    Campaign A: [0.3, 0.6]\n    Campaign B: [0.45, 0.23]\n    Campaign C: [0.57, 0.69]\n    Campaign D: [0.78, 0.34]\n    Campaign E: [0.40, 0.34]\n    Campaign F: [0.35, 0.78]",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. title Reach and engagement of campaigns",
        source:
            "quadrantChart\n    title Reach and engagement of campaigns\n    x-axis Low Reach --> High Reach\n    y-axis Low Engagement --> High Engagement\n    quadrant-1 We should expand\n    quadrant-2 Need to promote\n    quadrant-3 Re-evaluate\n    quadrant-4 May be improved\n    Campaign A: [0.3, 0.6]\n    Campaign B: [0.45, 0.23]\n    Campaign C: [0.57, 0.69]\n    Campaign D: [0.78, 0.34]\n    Campaign E: [0.40, 0.34]\n    Campaign F: [0.35, 0.78]",
      ),
      PlaygroundSampleItem(
        label: "2. x-axis Urgent --> Not Urgent",
        source:
            "---\nconfig:\n  quadrantChart:\n    chartWidth: 400\n    chartHeight: 400\n  themeVariables:\n    quadrant1TextFill: \"ff0000\"\n---\nquadrantChart\n  x-axis Urgent --> Not Urgent\n  y-axis Not Important --> \"Important ❤\"\n  quadrant-1 Plan\n  quadrant-2 Do\n  quadrant-3 Delegate\n  quadrant-4 Delete",
      ),
      PlaygroundSampleItem(
        label: "3. title Reach and engagement of campaigns",
        source:
            "quadrantChart\n  title Reach and engagement of campaigns\n  x-axis Low Reach --> High Reach\n  y-axis Low Engagement --> High Engagement\n  quadrant-1 We should expand\n  quadrant-2 Need to promote\n  quadrant-3 Re-evaluate\n  quadrant-4 May be improved\n  Campaign A: [0.9, 0.0] radius: 12\n  Campaign B:::class1: [0.8, 0.1] color: #ff3300, radius: 10\n  Campaign C: [0.7, 0.2] radius: 25, color: #00ff33, stroke-color: #10f0f0\n  Campaign D: [0.6, 0.3] radius: 15, stroke-color: #00ff0f, stroke-width: 5px ,color: #ff33f0\n  Campaign E:::class2: [0.5, 0.4]\n  Campaign F:::class3: [0.4, 0.5] color: #0000ff\n  classDef class1 color: #109060\n  classDef class2 color: #908342, radius : 10, stroke-color: #310085, stroke-width: 10px\n  classDef class3 color: #f00fff, radius : 10",
      ),
    ],
  ),
  DiagramSample(
    id: "requirement",
    title: "Requirement",
    description:
        "Show requirements and how they relate to each other and to the elements that satisfy them.",
    diagramType: "requirement",
    beta: false,
    tier: 2,
    source:
        "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nrequirementDiagram\n  requirement checkout_req {\n    id: 1\n    text: Orders must be payable online.\n    risk: high\n    verifymethod: test\n  }\n  functionalRequirement payment_req {\n    id: 1.1\n    text: Card payments must be authorized.\n    risk: high\n    verifymethod: test\n  }\n  element checkout_service {\n    type: service\n  }\n  checkout_req - contains -> payment_req\n  checkout_service - satisfies -> payment_req",
    showcaseSources: <String>[
      "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nrequirementDiagram\n  requirement checkout_req {\n    id: 1\n    text: Orders must be payable online.\n    risk: high\n    verifymethod: test\n  }\n  functionalRequirement payment_req {\n    id: 1.1\n    text: Card payments must be authorized.\n    risk: high\n    verifymethod: test\n  }\n  element checkout_service {\n    type: service\n  }\n  checkout_req - contains -> payment_req\n  checkout_service - satisfies -> payment_req",
      "requirementDiagram\n\ndirection LR\n\nrequirement test_req {\n    id: 1\n    text: the test text.\n    risk: high\n    verifymethod: test\n}\n\nelement test_entity {\n    type: simulation\n}\n\ntest_entity - satisfies -> test_req",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. requirement checkout_req {",
        source:
            "requirementDiagram\n  requirement checkout_req {\n    id: 1\n    text: Orders must be payable online.\n    risk: high\n    verifymethod: test\n  }\n  functionalRequirement payment_req {\n    id: 1.1\n    text: Card payments must be authorized.\n    risk: high\n    verifymethod: test\n  }\n  element checkout_service {\n    type: service\n  }\n  checkout_req - contains -> payment_req\n  checkout_service - satisfies -> payment_req",
      ),
      PlaygroundSampleItem(
        label: "2. requirement checkout_req {",
        source:
            "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nrequirementDiagram\n  requirement checkout_req {\n    id: 1\n    text: Orders must be payable online.\n    risk: high\n    verifymethod: test\n  }\n  functionalRequirement payment_req {\n    id: 1.1\n    text: Card payments must be authorized.\n    risk: high\n    verifymethod: test\n  }\n  element checkout_service {\n    type: service\n  }\n  checkout_req - contains -> payment_req\n  checkout_service - satisfies -> payment_req",
      ),
      PlaygroundSampleItem(
        label: "3. requirement test_req {",
        source:
            "requirementDiagram\n\n    requirement test_req {\n    id: 1\n    text: the test text.\n    risk: high\n    verifymethod: test\n    }\n\n    functionalRequirement test_req2 {\n    id: 1.1\n    text: the second test text.\n    risk: low\n    verifymethod: inspection\n    }\n\n    performanceRequirement test_req3 {\n    id: 1.2\n    text: the third test text.\n    risk: medium\n    verifymethod: demonstration\n    }\n\n    interfaceRequirement test_req4 {\n    id: 1.2.1\n    text: the fourth test text.\n    risk: medium\n    verifymethod: analysis\n    }\n\n    physicalRequirement test_req5 {\n    id: 1.2.2\n    text: the fifth test text.\n    risk: medium\n    verifymethod: analysis\n    }\n\n    designConstraint test_req6 {\n    id: 1.2.3\n    text: the sixth test text.\n    risk: medium\n    verifymethod: analysis\n    }\n\n    element test_entity {\n    type: simulation\n    }\n\n    element test_entity2 {\n    type: word doc\n    docRef: reqs/test_entity\n    }\n\n    element test_entity3 {\n    type: \"test suite\"\n    docRef: github.com/all_the_tests\n    }\n\n\n    test_entity - satisfies -> test_req2\n    test_req - traces -> test_req2\n    test_req - contains -> test_req3\n    test_req3 - contains -> test_req4\n    test_req4 - derives -> test_req5\n    test_req5 - refines -> test_req6\n    test_entity3 - verifies -> test_req5\n    test_req <- copies - test_entity2",
      ),
      PlaygroundSampleItem(
        label: "4. requirement test_req {",
        source:
            "requirementDiagram\n\nrequirement test_req {\n    id: 1\n    text: styling example\n    risk: low\n    verifymethod: test\n}\n\nelement test_entity {\n    type: simulation\n}\n\nstyle test_req fill:#ffa,stroke:#000, color: green\nstyle test_entity fill:#f9f,stroke:#333, color: blue",
      ),
      PlaygroundSampleItem(
        label: "5. requirement test_req {",
        source:
            "requirementDiagram\n\nrequirement test_req {\n    id: 1\n    text: \"class styling example\"\n    risk: low\n    verifymethod: test\n}\n\nelement test_entity {\n    type: simulation\n}\n\nclassDef important fill:#f96,stroke:#333,stroke-width:4px\nclassDef test fill:#ffa,stroke:#000",
      ),
      PlaygroundSampleItem(
        label: "6. requirement test_req:::important {",
        source:
            "requirementDiagram\n\nrequirement test_req:::important {\n    id: 1\n    text: \"class styling example\"\n    risk: low\n    verifymethod: test\n}\n\nelement test_entity {\n    type: simulation\n}\n\nclassDef important font-weight:bold\n\nclass test_entity important\nstyle test_entity fill:#f9f,stroke:#333",
      ),
    ],
  ),
  DiagramSample(
    id: "sankey",
    title: "Sankey",
    description:
        "Show flows between nodes, with widths proportional to quantity.",
    diagramType: "sankey",
    beta: false,
    tier: 2,
    source:
        "---\nconfig:\n  sankey:\n    showValues: false\n    nodeWidth: 15\n    nodePadding: 20\n---\nsankey\n\nElectricity grid,Heating and cooling - homes,113.726\nElectricity grid,Industry,342.165\nElectricity grid,Losses,56.691",
    showcaseSources: <String>[
      "---\nconfig:\n  sankey:\n    showValues: false\n    nodeWidth: 15\n    nodePadding: 20\n---\nsankey\n\nElectricity grid,Heating and cooling - homes,113.726\nElectricity grid,Industry,342.165\nElectricity grid,Losses,56.691",
      "sankey\n\n%% source,target,value\nElectricity grid,Over generation / exports,104.453\nElectricity grid,Heating and cooling - homes,113.726\nElectricity grid,H2 conversion,27.14",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. Agricultural 'waste',Bio-conversion,124.729",
        source:
            "---\nconfig:\n  sankey:\n    showValues: false\n---\nsankey\n\nAgricultural 'waste',Bio-conversion,124.729\nBio-conversion,Liquid,0.597\nBio-conversion,Losses,26.862\nBio-conversion,Solid,280.322\nBio-conversion,Gas,81.144\nBiofuel imports,Liquid,35\nBiomass imports,Solid,35\nCoal imports,Coal,11.606\nCoal reserves,Coal,63.965\nCoal,Solid,75.571\nDistrict heating,Industry,10.639\nDistrict heating,Heating and cooling - commercial,22.505\nDistrict heating,Heating and cooling - homes,46.184\nElectricity grid,Over generation / exports,104.453\nElectricity grid,Heating and cooling - homes,113.726\nElectricity grid,H2 conversion,27.14\nElectricity grid,Industry,342.165\nElectricity grid,Road transport,37.797\nElectricity grid,Agriculture,4.412\nElectricity grid,Heating and cooling - commercial,40.858\nElectricity grid,Losses,56.691\nElectricity grid,Rail transport,7.863\nElectricity grid,Lighting & appliances - commercial,90.008\nElectricity grid,Lighting & appliances - homes,93.494\nGas imports,Ngas,40.719\nGas reserves,Ngas,82.233\nGas,Heating and cooling - commercial,0.129\nGas,Losses,1.401\nGas,Thermal generation,151.891\nGas,Agriculture,2.096\nGas,Industry,48.58\nGeothermal,Electricity grid,7.013\nH2 conversion,H2,20.897\nH2 conversion,Losses,6.242\nH2,Road transport,20.897\nHydro,Electricity grid,6.995\nLiquid,Industry,121.066\nLiquid,International shipping,128.69\nLiquid,Road transport,135.835\nLiquid,Domestic aviation,14.458\nLiquid,International aviation,206.267\nLiquid,Agriculture,3.64\nLiquid,National navigation,33.218\nLiquid,Rail transport,4.413\nMarine algae,Bio-conversion,4.375\nNgas,Gas,122.952\nNuclear,Thermal generation,839.978\nOil imports,Oil,504.287\nOil reserves,Oil,107.703\nOil,Liquid,611.99\nOther waste,Solid,56.587\nOther waste,Bio-conversion,77.81\nPumped heat,Heating and cooling - homes,193.026\nPumped heat,Heating and cooling - commercial,70.672\nSolar PV,Electricity grid,59.901\nSolar Thermal,Heating and cooling - homes,19.263\nSolar,Solar Thermal,19.263\nSolar,Solar PV,59.901\nSolid,Agriculture,0.882\nSolid,Thermal generation,400.12\nSolid,Industry,46.477\nThermal generation,Electricity grid,525.531\nThermal generation,Losses,787.129\nThermal generation,District heating,79.329\nTidal,Electricity grid,9.452\nUK land based bioenergy,Bio-conversion,182.01\nWave,Electricity grid,19.013\nWind,Electricity grid,289.366",
      ),
      PlaygroundSampleItem(
        label: "2. Electricity grid,Over generation / exports,104.…",
        source:
            "sankey\n\n%% source,target,value\nElectricity grid,Over generation / exports,104.453\nElectricity grid,Heating and cooling - homes,113.726\nElectricity grid,H2 conversion,27.14",
      ),
      PlaygroundSampleItem(
        label: "3. Pumped heat,\"Heating and cooling, \"\"homes\"\"\",19…",
        source:
            "sankey\n\nPumped heat,\"Heating and cooling, \"\"homes\"\"\",193.026\nPumped heat,\"Heating and cooling, \"\"commercial\"\"\",70.672",
      ),
      PlaygroundSampleItem(
        label: "4. Electricity grid,Heating and cooling - homes,11…",
        source:
            "---\nconfig:\n  sankey:\n    showValues: false\n    labelStyle: outlined\n---\nsankey\n\nElectricity grid,Heating and cooling - homes,113.726\nElectricity grid,Industry,342.165\nElectricity grid,Losses,56.691",
      ),
      PlaygroundSampleItem(
        label: "5. Electricity grid,Heating and cooling - homes,11…",
        source:
            "---\nconfig:\n  sankey:\n    showValues: false\n    nodeWidth: 15\n    nodePadding: 20\n---\nsankey\n\nElectricity grid,Heating and cooling - homes,113.726\nElectricity grid,Industry,342.165\nElectricity grid,Losses,56.691",
      ),
      PlaygroundSampleItem(
        label: "6. Electricity grid,Heating and cooling - homes,11…",
        source:
            "---\nconfig:\n  sankey:\n    showValues: false\n    nodeColors:\n      Electricity grid: \"#4e79a7\"\n      Industry: \"#e15759\"\n      Losses: \"#bab0ab\"\n---\nsankey\n\nElectricity grid,Heating and cooling - homes,113.726\nElectricity grid,Industry,342.165\nElectricity grid,Losses,56.691",
      ),
    ],
  ),
  DiagramSample(
    id: "sequence",
    title: "Sequence",
    description: "Show the messages that participants exchange over time.",
    diagramType: "sequence",
    beta: false,
    tier: 1,
    source:
        "---\nconfig:\n  theme: default\n  look: classic\n---\nsequenceDiagram\n  autonumber\n  actor Customer\n  participant Web as Web app\n  participant API as API gateway\n  participant Bank\n  Customer->>Web: Place order\n  Web->>API: POST /orders\n  activate API\n  API->>Bank: Authorize payment\n  Bank-->>API: Approved\n  API-->>Web: 201 Created\n  deactivate API\n  Web-->>Customer: Order confirmed\n  Note over Customer,Bank: One order, one transaction",
    showcaseSources: <String>[
      "---\nconfig:\n  theme: default\n  look: classic\n---\nsequenceDiagram\n  autonumber\n  actor Customer\n  participant Web as Web app\n  participant API as API gateway\n  participant Bank\n  Customer->>Web: Place order\n  Web->>API: POST /orders\n  activate API\n  API->>Bank: Authorize payment\n  Bank-->>API: Approved\n  API-->>Web: 201 Created\n  deactivate API\n  Web-->>Customer: Order confirmed\n  Note over Customer,Bank: One order, one transaction",
      "sequenceDiagram\n    participant Alice\n    participant John\n    link Alice: Dashboard @ https://dashboard.contoso.com/alice\n    link Alice: Wiki @ https://wiki.contoso.com/alice\n    link John: Dashboard @ https://dashboard.contoso.com/john\n    link John: Wiki @ https://wiki.contoso.com/john\n    Alice->>John: Hello John, how are you?\n    John-->>Alice: Great!\n    Alice-)John: See you later!",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. autonumber",
        source:
            "sequenceDiagram\n  autonumber\n  actor Customer\n  participant Web as Web app\n  participant API as API gateway\n  participant Bank\n  Customer->>Web: Place order\n  Web->>API: POST /orders\n  activate API\n  API->>Bank: Authorize payment\n  Bank-->>API: Approved\n  API-->>Web: 201 Created\n  deactivate API\n  Web-->>Customer: Order confirmed\n  Note over Customer,Bank: One order, one transaction",
      ),
      PlaygroundSampleItem(
        label: "2. autonumber",
        source:
            "---\nconfig:\n  theme: default\n  look: classic\n---\nsequenceDiagram\n  autonumber\n  actor Customer\n  participant Web as Web app\n  participant API as API gateway\n  participant Bank\n  Customer->>Web: Place order\n  Web->>API: POST /orders\n  activate API\n  API->>Bank: Authorize payment\n  Bank-->>API: Approved\n  API-->>Web: 201 Created\n  deactivate API\n  Web-->>Customer: Order confirmed\n  Note over Customer,Bank: One order, one transaction",
      ),
      PlaygroundSampleItem(
        label: "3. participant API@{ \"type\": \"boundary\", \"alias\": …",
        source:
            "sequenceDiagram\n    participant API@{ \"type\": \"boundary\", \"alias\": \"Public API\" }\n    participant Auth@{ \"type\": \"control\", \"alias\": \"Auth Service\" }\n    participant DB@{ \"type\": \"database\", \"alias\": \"User Database\" }\n    API->>Auth: Login request\n    Auth->>DB: Query user\n    DB-->>Auth: User data\n    Auth-->>API: Access token",
      ),
      PlaygroundSampleItem(
        label: "4. participant Alice",
        source:
            "sequenceDiagram\n    participant Alice\n    participant John\n\n    rect rgb(191, 223, 255)\n    note right of Alice: Alice calls John.\n    Alice->>+John: Hello John, how are you?\n    rect rgb(200, 150, 255)\n    Alice->>+John: John, can you hear me?\n    John-->>-Alice: Hi Alice, I can hear you!\n    end\n    John-->>-Alice: I feel great!\n    end\n    Alice ->>+ John: Did you want to go to the game tonight?\n    John -->>- Alice: Yeah! See you there.",
      ),
      PlaygroundSampleItem(
        label: "5. participant Alice",
        source:
            "sequenceDiagram\n    participant Alice\n    participant John\n    link Alice: Dashboard @ https://dashboard.contoso.com/alice\n    link Alice: Wiki @ https://wiki.contoso.com/alice\n    link John: Dashboard @ https://dashboard.contoso.com/john\n    link John: Wiki @ https://wiki.contoso.com/john\n    Alice->>John: Hello John, how are you?\n    John-->>Alice: Great!\n    Alice-)John: See you later!",
      ),
      PlaygroundSampleItem(
        label: "6. participant Alice",
        source:
            "sequenceDiagram\n    participant Alice\n    participant John\n    links Alice: {\"Dashboard\": \"https://dashboard.contoso.com/alice\", \"Wiki\": \"https://wiki.contoso.com/alice\"}\n    links John: {\"Dashboard\": \"https://dashboard.contoso.com/john\", \"Wiki\": \"https://wiki.contoso.com/john\"}\n    Alice->>John: Hello John, how are you?\n    John-->>Alice: Great!\n    Alice-)John: See you later!",
      ),
    ],
  ),
  DiagramSample(
    id: "state",
    title: "State",
    description:
        "Show the states of a system and the transitions between them.",
    diagramType: "state",
    beta: false,
    tier: 1,
    source:
        "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nstateDiagram-v2\n  [*] --> Draft\n  Draft --> Submitted : submit\n  state Review {\n    [*] --> Screening\n    Screening --> Decision\n  }\n  Submitted --> Review\n  Review --> Published : approved\n  Review --> Draft : rejected\n  Published --> [*]",
    showcaseSources: <String>[
      "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nstateDiagram-v2\n  [*] --> Draft\n  Draft --> Submitted : submit\n  state Review {\n    [*] --> Screening\n    Screening --> Decision\n  }\n  Submitted --> Review\n  Review --> Published : approved\n  Review --> Draft : rejected\n  Published --> [*]",
      "stateDiagram-v2\n    [*] --> Active\n\n    state Active {\n        [*] --> NumLockOff\n        NumLockOff --> NumLockOn : EvNumLockPressed\n        NumLockOn --> NumLockOff : EvNumLockPressed\n        --\n        [*] --> CapsLockOff\n        CapsLockOff --> CapsLockOn : EvCapsLockPressed\n        CapsLockOn --> CapsLockOff : EvCapsLockPressed\n        --\n        [*] --> ScrollLockOff\n        ScrollLockOff --> ScrollLockOn : EvScrollLockPressed\n        ScrollLockOn --> ScrollLockOff : EvScrollLockPressed\n    }",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. [*] --> Draft",
        source:
            "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nstateDiagram-v2\n  [*] --> Draft\n  Draft --> Submitted : submit\n  state Review {\n    [*] --> Screening\n    Screening --> Decision\n  }\n  Submitted --> Review\n  Review --> Published : approved\n  Review --> Draft : rejected\n  Published --> [*]",
      ),
      PlaygroundSampleItem(
        label: "2. [*] --> First",
        source:
            "stateDiagram-v2\n    [*] --> First\n    state First {\n        [*] --> second\n        second --> [*]\n    }\n\n    [*] --> NamedComposite\n    NamedComposite: Another Composite\n    state NamedComposite {\n        [*] --> namedSimple\n        namedSimple --> [*]\n        namedSimple: Another simple\n    }",
      ),
      PlaygroundSampleItem(
        label: "3. [*] --> Active",
        source:
            "stateDiagram-v2\n    [*] --> Active\n\n    state Active {\n        [*] --> NumLockOff\n        NumLockOff --> NumLockOn : EvNumLockPressed\n        NumLockOn --> NumLockOff : EvNumLockPressed\n        --\n        [*] --> CapsLockOff\n        CapsLockOff --> CapsLockOn : EvCapsLockPressed\n        CapsLockOn --> CapsLockOff : EvCapsLockPressed\n        --\n        [*] --> ScrollLockOff\n        ScrollLockOff --> ScrollLockOn : EvScrollLockPressed\n        ScrollLockOn --> ScrollLockOff : EvScrollLockPressed\n    }",
      ),
      PlaygroundSampleItem(
        label: "4. direction TB",
        source:
            "stateDiagram\n   direction TB\n\n   accTitle: This is the accessible title\n   accDescr: This is an accessible description\n\n   classDef notMoving fill:white\n   classDef movement font-style:italic\n   classDef badBadEvent fill:#f00,color:white,font-weight:bold,stroke-width:2px,stroke:yellow\n\n   [*]--> Still\n   Still --> [*]\n   Still --> Moving\n   Moving --> Still\n   Moving --> Crash\n   Crash --> [*]\n\n   class Still notMoving\n   class Moving, Crash movement\n   class Crash badBadEvent\n   class end badBadEvent",
      ),
      PlaygroundSampleItem(
        label: "5. direction TB",
        source:
            "stateDiagram\n   direction TB\n\n   accTitle: This is the accessible title\n   accDescr: This is an accessible description\n\n   classDef notMoving fill:white\n   classDef movement font-style:italic;\n   classDef badBadEvent fill:#f00,color:white,font-weight:bold,stroke-width:2px,stroke:yellow\n\n   [*] --> Still:::notMoving\n   Still --> [*]\n   Still --> Moving:::movement\n   Moving --> Still\n   Moving --> Crash:::movement\n   Crash:::badBadEvent --> [*]",
      ),
      PlaygroundSampleItem(
        label: "6. classDef yourState font-style:italic,font-weigh…",
        source:
            "stateDiagram\n    classDef yourState font-style:italic,font-weight:bold,fill:white\n\n    yswsii: Your state with spaces in it\n    [*] --> yswsii:::yourState\n    [*] --> SomeOtherState\n    SomeOtherState --> YetAnotherState\n    yswsii --> YetAnotherState\n    YetAnotherState --> [*]",
      ),
    ],
  ),
  DiagramSample(
    id: "timeline",
    title: "Timeline",
    description: "Show events in chronological order.",
    diagramType: "timeline",
    beta: false,
    tier: 2,
    source:
        "timeline\n    title Timeline of the Hawaiian Islands\n    section Older islands\n        Kauaʻi : 5 million years old, Canyons, Sea <br>cliffs\n        Oʻahu : 3 million years old, Diamond Head, Surf breaks\n        Molokaʻi : 2 million years old, Fishponds, Tall cliffs\n    section Younger islands\n        Maui : 1 million years old, Haleakalā, Whale watching\n        Hawaiʻi : Still growing, Mauna Kea, Kīlauea",
    showcaseSources: <String>[
      "timeline\n    title Timeline of the Hawaiian Islands\n    section Older islands\n        Kauaʻi : 5 million years old, Canyons, Sea <br>cliffs\n        Oʻahu : 3 million years old, Diamond Head, Surf breaks\n        Molokaʻi : 2 million years old, Fishponds, Tall cliffs\n    section Younger islands\n        Maui : 1 million years old, Haleakalā, Whale watching\n        Hawaiʻi : Still growing, Mauna Kea, Kīlauea",
      "timeline\n        title Hawaiʻi's History Timeline\n        section Voyagers\n          1000 AD : Polynesian voyagers reach Hawaiʻi in sailing canoes\n          1778 : Captain Cook lands on Kauaʻi.<br> Islanders and Europeans meet for the first time.\n        section Kingdom\n          1810 : King Kamehameha unites the islands. <br>They are ruled as one kingdom for the first time.\n                  : Ships from around the world stop to trade.\n          1882 : ʻIolani Palace is completed in Honolulu.<br> It soon has electric lights and telephones.\n                  : Most people in the kingdom can read and write.",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. title Timeline of the Hawaiian Islands",
        source:
            "timeline\n    title Timeline of the Hawaiian Islands\n    section Older islands\n        Kauaʻi : 5 million years old, Canyons, Sea <br>cliffs\n        Oʻahu : 3 million years old, Diamond Head, Surf breaks\n        Molokaʻi : 2 million years old, Fishponds, Tall cliffs\n    section Younger islands\n        Maui : 1 million years old, Haleakalā, Whale watching\n        Hawaiʻi : Still growing, Mauna Kea, Kīlauea",
      ),
      PlaygroundSampleItem(
        label: "2. title Hawaiʻi's History Timeline",
        source:
            "timeline\n        title Hawaiʻi's History Timeline\n        section Voyagers\n          1000 AD : Polynesian voyagers reach Hawaiʻi in sailing canoes\n          1778 : Captain Cook lands on Kauaʻi.<br> Islanders and Europeans meet for the first time.\n        section Kingdom\n          1810 : King Kamehameha unites the islands. <br>They are ruled as one kingdom for the first time.\n                  : Ships from around the world stop to trade.\n          1882 : ʻIolani Palace is completed in Honolulu.<br> It soon has electric lights and telephones.\n                  : Most people in the kingdom can read and write.",
      ),
      PlaygroundSampleItem(
        label: "3. title Timeline of Industrial Revolution",
        source:
            "timeline\n    title Timeline of Industrial Revolution\n    section 17th-20th century\n        Industry 1.0 : Machinery, Water power, Steam <br>power\n        Industry 2.0 : Electricity, Internal combustion engine, Mass production\n        Industry 3.0 : Electronics, Computers, Automation\n    section 21st century\n        Industry 4.0 : Internet, Robotics, Internet of Things\n        Industry 5.0 : Artificial intelligence, Big data, 3D printing",
      ),
      PlaygroundSampleItem(
        label: "4. title England's History Timeline",
        source:
            "timeline\n        title England's History Timeline\n        section Stone Age\n          7600 BC : Britain's oldest known house was built in Orkney, Scotland\n          6000 BC : Sea levels rise and Britain becomes an island.<br> The people who live here are hunter-gatherers.\n        section Bronze Age\n          2300 BC : People arrive from Europe and settle in Britain. <br>They bring farming and metalworking.\n                  : New styles of pottery and ways of burying the dead appear.\n          2200 BC : The last major building works are completed at Stonehenge.<br> People now bury their dead in stone circles.\n                  : The first metal objects are made in Britain.Some other nice things happen. it is a good time to be alive.",
      ),
      PlaygroundSampleItem(
        label: "5. title MermaidChart 2023 Timeline",
        source:
            "timeline\n        title MermaidChart 2023 Timeline\n        section 2023 Q1 <br> Release Personal Tier\n          Bullet 1 : sub-point 1a : sub-point 1b\n               : sub-point 1c\n          Bullet 2 : sub-point 2a : sub-point 2b\n        section 2023 Q2 <br> Release XYZ Tier\n          Bullet 3 : sub-point <br> 3a : sub-point 3b\n               : sub-point 3c\n          Bullet 4 : sub-point 4a : sub-point 4b",
      ),
      PlaygroundSampleItem(
        label: "6. title History of Social Media Platform",
        source:
            "---\nconfig:\n  logLevel: 'debug'\n  theme: 'default'\n  themeVariables:\n    cScale0: '#ff0000'\n    cScaleLabel0: '#ffffff'\n    cScale1: '#00ff00'\n    cScale2: '#0000ff'\n    cScaleLabel2: '#ffffff'\n---\n       timeline\n        title History of Social Media Platform\n          2002 : LinkedIn\n          2004 : Facebook : Google\n          2005 : YouTube\n          2006 : Twitter\n          2007 : Tumblr\n          2008 : Instagram\n          2010 : Pinterest",
      ),
    ],
  ),
  DiagramSample(
    id: "xychart",
    title: "XY chart",
    description: "Plot data as bars and lines on two axes.",
    diagramType: "xychart",
    beta: false,
    tier: 2,
    source:
        "xychart\n    title \"Ocean Temperature\"\n    x-axis [jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec]\n    y-axis \"Temperature (in °F)\" 74 --> 82\n    bar [76.3, 75.9, 76.0, 76.7, 77.8, 78.9, 79.9, 80.7, 81.1, 80.5, 79.1, 77.4]\n    line [76.3, 75.9, 76.0, 76.7, 77.8, 78.9, 79.9, 80.7, 81.1, 80.5, 79.1, 77.4]",
    showcaseSources: <String>[
      "xychart\n    title \"Ocean Temperature\"\n    x-axis [jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec]\n    y-axis \"Temperature (in °F)\" 74 --> 82\n    bar [76.3, 75.9, 76.0, 76.7, 77.8, 78.9, 79.9, 80.7, 81.1, 80.5, 79.1, 77.4]\n    line [76.3, 75.9, 76.0, 76.7, 77.8, 78.9, 79.9, 80.7, 81.1, 80.5, 79.1, 77.4]",
      "---\nconfig:\n    xyChart:\n        showDataLabel: true\n        showDataLabelOutsideBar: true\n---\nxychart\n    title \"Animals seen in reef survey of 2025\"\n    x-axis [turtles, eels, tangs, wrasses, \"parrot fish\", other]\n    y-axis \"Number of Animals\" 0 --> 30\n    bar [12,2,20,25,17,24]",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. title \"Ocean Temperature\"",
        source:
            "xychart\n    title \"Ocean Temperature\"\n    x-axis [jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec]\n    y-axis \"Temperature (in °F)\" 74 --> 82\n    bar [76.3, 75.9, 76.0, 76.7, 77.8, 78.9, 79.9, 80.7, 81.1, 80.5, 79.1, 77.4]\n    line [76.3, 75.9, 76.0, 76.7, 77.8, 78.9, 79.9, 80.7, 81.1, 80.5, 79.1, 77.4]",
      ),
      PlaygroundSampleItem(
        label: "2. title \"Animals seen in reef survey of 2025\"",
        source:
            "---\nconfig:\n    xyChart:\n        showDataLabel: true\n        showDataLabelOutsideBar: true\n---\nxychart\n    title \"Animals seen in reef survey of 2025\"\n    x-axis [turtles, eels, tangs, wrasses, \"parrot fish\", other]\n    y-axis \"Number of Animals\" 0 --> 30\n    bar [12,2,20,25,17,24]",
      ),
      PlaygroundSampleItem(
        label: "3. title \"Sales Revenue\"",
        source:
            "xychart\n    title \"Sales Revenue\"\n    x-axis [jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec]\n    y-axis \"Revenue (in \$)\" 4000 --> 11000\n    bar [5000, 6000, 7500, 8200, 9500, 10500, 11000, 10200, 9200, 8500, 7000, 6000]\n    line [5000, 6000, 7500, 8200, 9500, 10500, 11000, 10200, 9200, 8500, 7000, 6000]",
      ),
      PlaygroundSampleItem(
        label: "4. title \"Different Colors in xyChart\"",
        source:
            "---\nconfig:\n  themeVariables:\n    xyChart:\n      plotColorPalette: '#000000, #0000FF, #00FF00, #FF0000'\n---\nxychart\ntitle \"Different Colors in xyChart\"\nx-axis \"categoriesX\" [\"Category 1\", \"Category 2\", \"Category 3\", \"Category 4\"]\ny-axis \"valuesY\" 0 --> 50\n%% Black line\nline [10,20,30,40]\n%% Blue bar\nbar [20,30,25,35]\n%% Green bar\nbar [15,25,20,30]\n%% Red line\nline [5,15,25,35]",
      ),
      PlaygroundSampleItem(
        label: "5. title \"Genres in top 100 book survey of 2025\"",
        source:
            "---\nconfig:\n    xyChart:\n        showDataLabel: true\n        showDataLabelOutsideBar: true\n---\nxychart\n    title \"Genres in top 100 book survey of 2025\"\n    x-axis [comedy, romance, mystery, crime, \"non fiction\", other]\n    y-axis \"Number of Books\" 0 --> 30\n    bar [12,2,20,25,17,24]",
      ),
      PlaygroundSampleItem(
        label: "6. title \"Sales Revenue\"",
        source:
            "---\nconfig:\n    xyChart:\n        width: 900\n        height: 600\n        showDataLabel: true\n    themeVariables:\n        xyChart:\n            titleColor: \"#ff0000\"\n---\nxychart\n    title \"Sales Revenue\"\n    x-axis [jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec]\n    y-axis \"Revenue (in \$)\" 4000 --> 11000\n    bar [5000, 6000, 7500, 8200, 9500, 10500, 11000, 10200, 9200, 8500, 7000, 6000]\n    line [5000, 6000, 7500, 8200, 9500, 10500, 11000, 10200, 9200, 8500, 7000, 6000]",
      ),
    ],
  ),
  DiagramSample(
    id: "agentflow",
    title: "Agentflow",
    description:
        "Show the tasks of AI agents and how work passes between them.",
    diagramType: "agentflow",
    beta: true,
    tier: 2,
    source:
        "agentflow-beta TB\n  flow intake[\"Intake\"]\n    receive[\"Receive request\"]@{ shape: input }\n  end\n\n  flow processing[\"Processing\"]\n    validate[\"Validate\"]@{ shape: task }\n    enrich[\"Enrich\"]@{ shape: task }\n    validate --> enrich\n  end\n  processing@{ view: \"collapsed\" }\n\n  flow output[\"Output\"]\n    publish[\"Publish\"]@{ shape: action }\n  end\n\n  receive --> validate\n  enrich --> publish",
    showcaseSources: <String>[
      "agentflow-beta TB\n  flow intake[\"Intake\"]\n    receive[\"Receive request\"]@{ shape: input }\n  end\n\n  flow processing[\"Processing\"]\n    validate[\"Validate\"]@{ shape: task }\n    enrich[\"Enrich\"]@{ shape: task }\n    validate --> enrich\n  end\n  processing@{ view: \"collapsed\" }\n\n  flow output[\"Output\"]\n    publish[\"Publish\"]@{ shape: action }\n  end\n\n  receive --> validate\n  enrich --> publish",
      "agentflow-beta TB\n  connector llm[\"LLM API\"]\n  llm@{ protocol: \"http\", endpoint: \"https://api.example.com/chat\" }\n\n  flow coffee_team[\"Coffee Team\"]\n    city[\"city\"]@{ shape: input, value: \"Stockholm\" }\n\n    flow researcher[\"Researcher\"]\n      research[\"research_location\"]@{ shape: tool, params: \"city :: String\", returns: \"Report\" }\n      write[\"write_copy\"]@{ shape: tool, connectorRef: \"llm.chat\", returns: \"CoffeeCopy\" }\n      city --> research --> write\n    end\n    researcher@{ instruction: \"Research the city and draft English coffee copy citing sources.\" }\n\n    flow designer[\"Designer\"]\n      render[\"generate_html\"]@{ shape: tool, connectorRef: \"llm.chat\", returns: \"String\" }\n      brand[\"Nordic Brand Guide\"]@{ shape: refdoc }\n      render -.- brand\n    end\n\n    researcher --> designer\n  end",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. brief[\"Release brief\"]@{ shape: input }",
        source:
            "agentflow-beta TB\n  brief[\"Release brief\"]@{ shape: input }\n  flow writer[\"Drafting Agent\"]\n    draft[\"Draft the notes\"]@{ shape: task }\n    lookup[\"changelog_search\"]@{ shape: tool }\n    guide[\"Tone of voice\"]@{ shape: refdoc }\n    draft --> lookup\n    draft -.- guide\n  end\n  flow reviewer[\"Review Agent\"]\n    check[\"Check the claims\"]@{ shape: task }\n    ok[\"Accurate?\"]@{ shape: decision }\n    check --> ok\n  end\n  publish[\"Publish\"]@{ shape: action }\n  brief --> writer\n  writer --> reviewer\n  ok --> publish",
      ),
      PlaygroundSampleItem(
        label: "2. brief[\"Release brief\"]@{ shape: input }",
        source:
            "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nagentflow-beta TB\n  brief[\"Release brief\"]@{ shape: input }\n  flow writer[\"Drafting Agent\"]\n    draft[\"Draft the notes\"]@{ shape: task }\n    lookup[\"changelog_search\"]@{ shape: tool }\n    guide[\"Tone of voice\"]@{ shape: refdoc }\n    draft --> lookup\n    draft -.- guide\n  end\n  flow reviewer[\"Review Agent\"]\n    check[\"Check the claims\"]@{ shape: task }\n    ok[\"Accurate?\"]@{ shape: decision }\n    check --> ok\n  end\n  publish[\"Publish\"]@{ shape: action }\n  brief --> writer\n  writer --> reviewer\n  ok --> publish",
      ),
      PlaygroundSampleItem(
        label: "3. brief[\"Brief\"]@{ shape: input }",
        source:
            "agentflow-beta LR\n  brief[\"Brief\"]@{ shape: input }\n  draft[\"Draft copy\"]@{ shape: task }\n  spellcheck[\"spell_check\"]@{ shape: tool }\n  guide[\"Style guide\"]@{ shape: refdoc }\n  publish[\"Publish\"]@{ shape: action }\n\n  brief --> draft --> spellcheck --> publish\n  draft -.- guide",
      ),
      PlaygroundSampleItem(
        label: "4. global",
        source:
            "agentflow-beta TB\n  global\n    corpus[\"Shared corpus\"]@{ shape: refdoc }\n  end\n\n  flow summarizer[\"Summarizer\"]\n    summarize[\"Summarize\"]@{ shape: task }\n    summarize -.- corpus\n  end\n\n  flow indexer[\"Indexer\"]\n    index[\"Build index\"]@{ shape: task }\n    index -.- corpus\n  end",
      ),
      PlaygroundSampleItem(
        label: "5. flow intake[\"Intake\"]",
        source:
            "agentflow-beta TB\n  flow intake[\"Intake\"]\n    receive[\"Receive request\"]@{ shape: input }\n  end\n\n  flow processing[\"Processing\"]\n    validate[\"Validate\"]@{ shape: task }\n    enrich[\"Enrich\"]@{ shape: task }\n    validate --> enrich\n  end\n  processing@{ view: \"collapsed\" }\n\n  flow output[\"Output\"]\n    publish[\"Publish\"]@{ shape: action }\n  end\n\n  receive --> validate\n  enrich --> publish",
      ),
      PlaygroundSampleItem(
        label: "6. connector llm[\"LLM API\"]",
        source:
            "agentflow-beta TB\n  connector llm[\"LLM API\"]\n  llm@{ protocol: \"http\", endpoint: \"https://api.example.com/chat\" }\n\n  flow coffee_team[\"Coffee Team\"]\n    city[\"city\"]@{ shape: input, value: \"Stockholm\" }\n\n    flow researcher[\"Researcher\"]\n      research[\"research_location\"]@{ shape: tool, params: \"city :: String\", returns: \"Report\" }\n      write[\"write_copy\"]@{ shape: tool, connectorRef: \"llm.chat\", returns: \"CoffeeCopy\" }\n      city --> research --> write\n    end\n    researcher@{ instruction: \"Research the city and draft English coffee copy citing sources.\" }\n\n    flow designer[\"Designer\"]\n      render[\"generate_html\"]@{ shape: tool, connectorRef: \"llm.chat\", returns: \"String\" }\n      brand[\"Nordic Brand Guide\"]@{ shape: refdoc }\n      render -.- brand\n    end\n\n    researcher --> designer\n  end",
      ),
    ],
  ),
  DiagramSample(
    id: "architecture",
    title: "Architecture",
    description: "Show services and the connections between them.",
    diagramType: "architecture",
    beta: true,
    tier: 2,
    source:
        "architecture-beta\n    service left_disk(disk)[Disk]\n    service top_disk(disk)[Disk]\n    service bottom_disk(disk)[Disk]\n    service top_gateway(internet)[Gateway]\n    service bottom_gateway(internet)[Gateway]\n    junction junctionCenter\n    junction junctionRight\n\n    left_disk:R -- L:junctionCenter\n    top_disk:B -- T:junctionCenter\n    bottom_disk:T -- B:junctionCenter\n    junctionCenter:R -- L:junctionRight\n    top_gateway:B -- T:junctionRight\n    bottom_gateway:T -- B:junctionRight",
    showcaseSources: <String>[
      "architecture-beta\n    service left_disk(disk)[Disk]\n    service top_disk(disk)[Disk]\n    service bottom_disk(disk)[Disk]\n    service top_gateway(internet)[Gateway]\n    service bottom_gateway(internet)[Gateway]\n    junction junctionCenter\n    junction junctionRight\n\n    left_disk:R -- L:junctionCenter\n    top_disk:B -- T:junctionCenter\n    bottom_disk:T -- B:junctionCenter\n    junctionCenter:R -- L:junctionRight\n    top_gateway:B -- T:junctionRight\n    bottom_gateway:T -- B:junctionRight",
      "architecture-beta\n    group sources(cloud)[Sources]\n        service src_a(server)[Source A] in sources\n        service src_b(server)[Source B] in sources\n        service src_c(server)[Source C] in sources\n\n    group storage(database)[Storage]\n        service db_one(database)[DB One] in storage\n        service db_two(database)[DB Two] in storage\n        service db_three(database)[DB Three] in storage\n\n    group output(disk)[Output]\n        service brief(disk)[Brief] in output\n        service analyst(server)[Analyst] in output\n        service delivery(cloud)[Delivery] in output\n\n    src_a:B --> T:db_one\n    src_b:B --> T:db_two\n    src_c:B --> T:db_three\n    db_two:B --> T:brief\n    brief:R --> L:analyst\n    analyst:R --> L:delivery\n\n    align row src_a src_b src_c\n    align row db_one db_two db_three\n    align row brief analyst delivery\n\n    align column src_a db_one\n    align column src_b db_two brief\n    align column src_c db_three",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. group api(cloud)[API]",
        source:
            "architecture-beta\n    group api(cloud)[API]\n\n    service db(database)[Database] in api\n    service disk1(disk)[Storage] in api\n    service disk2(disk)[Storage] in api\n    service server(server)[Server] in api\n\n    db:L -- R:server\n    disk1:T -- B:server\n    disk2:T -- B:db",
      ),
      PlaygroundSampleItem(
        label: "2. group api(cloud)[API]",
        source:
            "architecture-beta\n    group api(cloud)[API]\n    service db1(database)[DB1] in api\n    service db2(database)[DB2] in api\n    service db3(database)[DB3] in api\n    service mcp(server)[MCP] in api\n    db1:R --> L:mcp\n    db2:R --> L:mcp\n    db3:R --> L:mcp\n    align column db1 db2 db3",
      ),
      PlaygroundSampleItem(
        label: "3. service src1(server)[Source 1]",
        source:
            "architecture-beta\n    service src1(server)[Source 1]\n    service src2(server)[Source 2]\n    service src3(server)[Source 3]\n    service proc(server)[Processor]\n    src1:B --> T:proc\n    src2:B --> T:proc\n    src3:B --> T:proc\n    align row src1 src2 src3",
      ),
      PlaygroundSampleItem(
        label: "4. group sources(cloud)[Sources]",
        source:
            "architecture-beta\n    group sources(cloud)[Sources]\n        service src_a(server)[Source A] in sources\n        service src_b(server)[Source B] in sources\n        service src_c(server)[Source C] in sources\n\n    group storage(database)[Storage]\n        service db_one(database)[DB One] in storage\n        service db_two(database)[DB Two] in storage\n        service db_three(database)[DB Three] in storage\n\n    group output(disk)[Output]\n        service brief(disk)[Brief] in output\n        service analyst(server)[Analyst] in output\n        service delivery(cloud)[Delivery] in output\n\n    src_a:B --> T:db_one\n    src_b:B --> T:db_two\n    src_c:B --> T:db_three\n    db_two:B --> T:brief\n    brief:R --> L:analyst\n    analyst:R --> L:delivery\n\n    align row src_a src_b src_c\n    align row db_one db_two db_three\n    align row brief analyst delivery\n\n    align column src_a db_one\n    align column src_b db_two brief\n    align column src_c db_three",
      ),
      PlaygroundSampleItem(
        label: "5. service left_disk(disk)[Disk]",
        source:
            "architecture-beta\n    service left_disk(disk)[Disk]\n    service top_disk(disk)[Disk]\n    service bottom_disk(disk)[Disk]\n    service top_gateway(internet)[Gateway]\n    service bottom_gateway(internet)[Gateway]\n    junction junctionCenter\n    junction junctionRight\n\n    left_disk:R -- L:junctionCenter\n    top_disk:B -- T:junctionCenter\n    bottom_disk:T -- B:junctionCenter\n    junctionCenter:R -- L:junctionRight\n    top_gateway:B -- T:junctionRight\n    bottom_gateway:T -- B:junctionRight",
      ),
      PlaygroundSampleItem(
        label: "6. group api(logos:aws-lambda)[API]",
        source:
            "architecture-beta\n    group api(logos:aws-lambda)[API]\n\n    service db(logos:aws-aurora)[Database] in api\n    service disk1(logos:aws-glacier)[Storage] in api\n    service disk2(logos:aws-s3)[Storage] in api\n    service server(logos:aws-ec2)[Server] in api\n\n    db:L -- R:server\n    disk1:T -- B:server\n    disk2:T -- B:db",
      ),
    ],
  ),
  DiagramSample(
    id: "cynefin",
    title: "Cynefin",
    description: "Sort items into the five domains of the Cynefin framework.",
    diagramType: "cynefin",
    beta: true,
    tier: 2,
    source:
        "cynefin-beta\n  title Strategy Categorization\n\n  complex\n    \"Market research\"\n\n  complicated\n    \"Competitive analysis\"\n\n  clear\n    \"Standard pricing\"\n\n  chaotic\n    \"Crisis management\"\n\n  complex --> complicated : \"Pattern identified\"\n  complicated --> clear : \"Best practice codified\"\n  clear --> chaotic : \"Complacency\"\n  chaotic --> complex : \"Stabilized\"",
    showcaseSources: <String>[
      "cynefin-beta\n  title Strategy Categorization\n\n  complex\n    \"Market research\"\n\n  complicated\n    \"Competitive analysis\"\n\n  clear\n    \"Standard pricing\"\n\n  chaotic\n    \"Crisis management\"\n\n  complex --> complicated : \"Pattern identified\"\n  complicated --> clear : \"Best practice codified\"\n  clear --> chaotic : \"Complacency\"\n  chaotic --> complex : \"Stabilized\"",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. title Incident Response",
        source:
            "cynefin-beta\n  title Incident Response\n\n  complex\n    \"Investigate root cause\"\n    \"Run chaos experiment\"\n\n  complicated\n    \"Analyze performance data\"\n    \"Expert review needed\"\n\n  clear\n    \"Restart service\"\n    \"Apply known fix\"\n\n  chaotic\n    \"Page on-call immediately\"\n\n  confusion\n    \"Unknown failure mode\"",
      ),
      PlaygroundSampleItem(
        label: "2. title Strategy Categorization",
        source:
            "cynefin-beta\n  title Strategy Categorization\n\n  complex\n    \"Market research\"\n\n  complicated\n    \"Competitive analysis\"\n\n  clear\n    \"Standard pricing\"\n\n  chaotic\n    \"Crisis management\"\n\n  complex --> complicated : \"Pattern identified\"\n  complicated --> clear : \"Best practice codified\"\n  clear --> chaotic : \"Complacency\"\n  chaotic --> complex : \"Stabilized\"",
      ),
      PlaygroundSampleItem(
        label: "3. title Cynefin Framework",
        source:
            "cynefin-beta\n  title Cynefin Framework\n\n  complex\n  complicated\n  clear\n  chaotic",
      ),
    ],
  ),
  DiagramSample(
    id: "ishikawa",
    title: "Ishikawa",
    description: "Show the causes that contribute to a problem.",
    diagramType: "ishikawa",
    beta: true,
    tier: 2,
    source:
        "ishikawa-beta\n    Blurry Photo\n    Process\n        Out of focus\n        Shutter speed too slow\n        Protective film not removed\n        Beautification filter applied\n    User\n        Shaky hands\n    Equipment\n        LENS\n            Inappropriate lens\n            Damaged lens\n            Dirty lens\n        SENSOR\n            Damaged sensor\n            Dirty sensor\n    Environment\n        Subject moved too quickly\n        Too dark",
    showcaseSources: <String>[
      "ishikawa-beta\n    Blurry Photo\n    Process\n        Out of focus\n        Shutter speed too slow\n        Protective film not removed\n        Beautification filter applied\n    User\n        Shaky hands\n    Equipment\n        LENS\n            Inappropriate lens\n            Damaged lens\n            Dirty lens\n        SENSOR\n            Damaged sensor\n            Dirty sensor\n    Environment\n        Subject moved too quickly\n        Too dark",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. Blurry Photo",
        source:
            "ishikawa-beta\n    Blurry Photo\n    Process\n        Out of focus\n        Shutter speed too slow\n        Protective film not removed\n        Beautification filter applied\n    User\n        Shaky hands\n    Equipment\n        LENS\n            Inappropriate lens\n            Damaged lens\n            Dirty lens\n        SENSOR\n            Damaged sensor\n            Dirty sensor\n    Environment\n        Subject moved too quickly\n        Too dark",
      ),
      PlaygroundSampleItem(
        label: "2. API Latency Spike",
        source:
            "ishikawa-beta\n    API Latency Spike\n    Database\n        Missing composite index\n        Connection pool exhaustion\n        Lock contention\n    Application\n        N+1 query pattern\n        Unbounded payload serialization\n    Infrastructure\n        Cross-region network hop\n        CPU throttling on container\n    Traffic\n        Unthrottled batch webhook burst",
      ),
      PlaygroundSampleItem(
        label: "3. Build Pipeline Failure",
        source:
            "ishikawa-beta\n    Build Pipeline Failure\n    Dependencies\n        Unpinned transitive version\n        Registry timeout\n    Tests\n        Timezone-sensitive snapshot\n        Port collision in parallel runner\n    Environment\n        Disk cache full\n        Expired signing certificate",
      ),
    ],
  ),
  DiagramSample(
    id: "radar",
    title: "Radar",
    description: "Compare values across several axes.",
    diagramType: "radar",
    beta: true,
    tier: 2,
    source:
        "radar-beta\n  title Restaurant Comparison\n  axis food[\"Food Quality\"], service[\"Service\"], price[\"Price\"]\n  axis ambiance[\"Ambiance\"]\n\n  curve a[\"Restaurant A\"]{4, 3, 2, 4}\n  curve b[\"Restaurant B\"]{3, 4, 3, 3}\n  curve c[\"Restaurant C\"]{2, 3, 4, 2}\n  curve d[\"Restaurant D\"]{2, 2, 4, 3}\n\n  graticule polygon\n  max 5",
    showcaseSources: <String>[
      "radar-beta\n  title Restaurant Comparison\n  axis food[\"Food Quality\"], service[\"Service\"], price[\"Price\"]\n  axis ambiance[\"Ambiance\"]\n\n  curve a[\"Restaurant A\"]{4, 3, 2, 4}\n  curve b[\"Restaurant B\"]{3, 4, 3, 3}\n  curve c[\"Restaurant C\"]{2, 3, 4, 2}\n  curve d[\"Restaurant D\"]{2, 2, 4, 3}\n\n  graticule polygon\n  max 5",
      "---\ntitle: \"Grades\"\n---\nradar-beta\n  axis m[\"Math\"], s[\"Science\"], e[\"English\"]\n  axis h[\"History\"], g[\"Geography\"], a[\"Art\"]\n  curve a[\"Alice\"]{85, 90, 80, 70, 75, 90}\n  curve b[\"Bob\"]{70, 75, 85, 80, 90, 85}\n\n  max 100\n  min 0",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. Grades",
        source:
            "---\ntitle: \"Grades\"\n---\nradar-beta\n  axis m[\"Math\"], s[\"Science\"], e[\"English\"]\n  axis h[\"History\"], g[\"Geography\"], a[\"Art\"]\n  curve a[\"Alice\"]{85, 90, 80, 70, 75, 90}\n  curve b[\"Bob\"]{70, 75, 85, 80, 90, 85}\n\n  max 100\n  min 0",
      ),
      PlaygroundSampleItem(
        label: "2. title Restaurant Comparison",
        source:
            "radar-beta\n  title Restaurant Comparison\n  axis food[\"Food Quality\"], service[\"Service\"], price[\"Price\"]\n  axis ambiance[\"Ambiance\"]\n\n  curve a[\"Restaurant A\"]{4, 3, 2, 4}\n  curve b[\"Restaurant B\"]{3, 4, 3, 3}\n  curve c[\"Restaurant C\"]{2, 3, 4, 2}\n  curve d[\"Restaurant D\"]{2, 2, 4, 3}\n\n  graticule polygon\n  max 5",
      ),
      PlaygroundSampleItem(
        label: "3. axis A, B, C, D, E",
        source:
            "---\nconfig:\n  radar:\n    axisScaleFactor: 0.25\n    curveTension: 0.1\n  theme: base\n  themeVariables:\n    cScale0: \"#FF0000\"\n    cScale1: \"#00FF00\"\n    cScale2: \"#0000FF\"\n    radar:\n      curveOpacity: 0\n---\nradar-beta\n  axis A, B, C, D, E\n  curve c1{1,2,3,4,5}\n  curve c2{5,4,3,2,1}\n  curve c3{3,3,3,3,3}",
      ),
    ],
  ),
  DiagramSample(
    id: "railroad",
    title: "Railroad",
    description: "Show the syntax of a grammar.",
    diagramType: "railroad",
    beta: true,
    tier: 2,
    source:
        "railroad-ebnf-beta\ntitle \"Arithmetic Expression Grammar\"\n\nexpression = term ( ( \"+\" | \"-\" ) term )* ;\nterm = factor ( ( \"*\" | \"/\" ) factor )* ;\nfactor = number | \"(\" expression \")\" ;\nnumber = digit+ ;\ndigit = \"0\" | \"1\" | \"2\" | \"3\" | \"4\" | \"5\" | \"6\" | \"7\" | \"8\" | \"9\" ;",
    showcaseSources: <String>[
      "railroad-ebnf-beta\ntitle \"Arithmetic Expression Grammar\"\n\nexpression = term ( ( \"+\" | \"-\" ) term )* ;\nterm = factor ( ( \"*\" | \"/\" ) factor )* ;\nfactor = number | \"(\" expression \")\" ;\nnumber = digit+ ;\ndigit = \"0\" | \"1\" | \"2\" | \"3\" | \"4\" | \"5\" | \"6\" | \"7\" | \"8\" | \"9\" ;",
      "railroad-beta\ntitle Expression Grammar\n\nexpression = sequence(\n    nonterminal(\"term\"),\n    zeroOrMore(sequence(\n        choice(terminal(\"+\"), terminal(\"-\")),\n        nonterminal(\"term\")\n    ))\n) ;\nterm = sequence(\n    nonterminal(\"factor\"),\n    zeroOrMore(sequence(\n        choice(terminal(\"*\"), terminal(\"/\")),\n        nonterminal(\"factor\")\n    ))\n) ;\nfactor = choice(\n    nonterminal(\"number\"),\n    sequence(terminal(\"(\"), nonterminal(\"expression\"), terminal(\")\"))\n) ;\nnumber = oneOrMore(nonterminal(\"digit\")) ;\ndigit = choice(terminal(\"0\"), terminal(\"1\"), terminal(\"2\"), terminal(\"3\"), terminal(\"4\"), terminal(\"5\"), terminal(\"6\"), terminal(\"7\"), terminal(\"8\"), terminal(\"9\")) ;",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. title \"Arithmetic Expression Grammar\"",
        source:
            "railroad-ebnf-beta\ntitle \"Arithmetic Expression Grammar\"\n\nexpression = term ( ( \"+\" | \"-\" ) term )* ;\nterm = factor ( ( \"*\" | \"/\" ) factor )* ;\nfactor = number | \"(\" expression \")\" ;\nnumber = digit+ ;\ndigit = \"0\" | \"1\" | \"2\" | \"3\" | \"4\" | \"5\" | \"6\" | \"7\" | \"8\" | \"9\" ;",
      ),
      PlaygroundSampleItem(
        label: "2. title \"JSON Grammar\"",
        source:
            "railroad-ebnf-beta\ntitle \"JSON Grammar\"\n\njson = element ;\nelement = object | array | string | number | \"true\" | \"false\" | \"null\" ;\nobject = \"{\" [ member ( \",\" member )* ] \"}\" ;\narray = \"[\" [ element ( \",\" element )* ] \"]\" ;\nmember = string \":\" element ;",
      ),
      PlaygroundSampleItem(
        label: "3. title \"Email Address\"",
        source:
            "railroad-abnf-beta\ntitle \"Email Address\"\n\naddress = local-part \"@\" domain ;\nlocal-part = 1*( ALPHA / DIGIT / \".\" / \"-\" ) ;\ndomain = label *( \".\" label ) ;\nlabel = 1*( ALPHA / DIGIT / \"-\" ) ;",
      ),
      PlaygroundSampleItem(
        label: "4. title \"Calculator Grammar\"",
        source:
            "railroad-peg-beta\ntitle \"Calculator Grammar\"\n\nExpression <- Term ((\"+\" / \"-\") Term)* ;\nTerm <- Factor ((\"*\" / \"/\") Factor)* ;\nFactor <- Number / \"(\" Expression \")\" ;\nNumber <- Digit+ ;\nDigit <- \"0\" / \"1\" / \"2\" / \"3\" / \"4\" / \"5\" / \"6\" / \"7\" / \"8\" / \"9\" ;",
      ),
      PlaygroundSampleItem(
        label: "5. title \"Identifiers (keywords excluded)\"",
        source:
            "railroad-peg-beta\ntitle \"Identifiers (keywords excluded)\"\n\nIdentifier <- !Keyword Letter Letter* ;\nKeyword <- \"if\" / \"else\" / \"while\" ;\nLetter <- \"a\" / \"b\" / \"c\" / \"_\" ;",
      ),
      PlaygroundSampleItem(
        label: "6. title Expression Grammar",
        source:
            "railroad-beta\ntitle Expression Grammar\n\nexpression = sequence(\n    nonterminal(\"term\"),\n    zeroOrMore(sequence(\n        choice(terminal(\"+\"), terminal(\"-\")),\n        nonterminal(\"term\")\n    ))\n) ;\nterm = sequence(\n    nonterminal(\"factor\"),\n    zeroOrMore(sequence(\n        choice(terminal(\"*\"), terminal(\"/\")),\n        nonterminal(\"factor\")\n    ))\n) ;\nfactor = choice(\n    nonterminal(\"number\"),\n    sequence(terminal(\"(\"), nonterminal(\"expression\"), terminal(\")\"))\n) ;\nnumber = oneOrMore(nonterminal(\"digit\")) ;\ndigit = choice(terminal(\"0\"), terminal(\"1\"), terminal(\"2\"), terminal(\"3\"), terminal(\"4\"), terminal(\"5\"), terminal(\"6\"), terminal(\"7\"), terminal(\"8\"), terminal(\"9\")) ;",
      ),
    ],
  ),
  DiagramSample(
    id: "swimlane",
    title: "Swimlane",
    description: "Show a process divided by who performs each step.",
    diagramType: "swimlane",
    beta: true,
    tier: 2,
    source:
        "swimlane-beta LR\n  subgraph Customer\n    request[Request service]\n    receive[Receive update]\n  end\n\n  subgraph Support\n    triage[Triage request]\n    answer[Send answer]\n  end\n\n  subgraph Engineering\n    investigate[Investigate issue]\n    fix[Prepare fix]\n  end\n\n  request --> triage\n  triage -->|Known issue| answer\n  triage -->|Needs code change| investigate\n  investigate --> fix --> answer\n  answer --> receive",
    showcaseSources: <String>[
      "swimlane-beta LR\n  subgraph Customer\n    request[Request service]\n    receive[Receive update]\n  end\n\n  subgraph Support\n    triage[Triage request]\n    answer[Send answer]\n  end\n\n  subgraph Engineering\n    investigate[Investigate issue]\n    fix[Prepare fix]\n  end\n\n  request --> triage\n  triage -->|Known issue| answer\n  triage -->|Needs code change| investigate\n  investigate --> fix --> answer\n  answer --> receive",
      "swimlane-beta LR\n  subgraph Applicant\n    apply[Submit application]\n    sign[Sign agreement]\n  end\n\n  subgraph Reviewer\n    screen[Screen application]\n    decide{Approved?}\n  end\n\n  subgraph System\n    create[Create account]\n    notify[Send welcome email]\n  end\n\n  apply -->|Application received| screen\n  screen --> decide\n  decide -->|Approved| create --> notify --> sign\n  decide -->|Needs changes| apply",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. subgraph Customer",
        source:
            "---\nconfig:\n  theme: default\n  look: classic\n---\nswimlane-beta LR\n  subgraph Customer\n    Browse[Browse catalog]\n    Pay[Pay]\n  end\n  subgraph Warehouse\n    Pick[Pick items]\n    Ship[Ship order]\n  end\n  subgraph Finance\n    Invoice[Raise invoice]\n  end\n  Browse --> Pay\n  Pay --> Pick\n  Pick --> Ship\n  Pay --> Invoice",
      ),
      PlaygroundSampleItem(
        label: "2. subgraph Customer",
        source:
            "swimlane-beta LR\n  subgraph Customer\n    request[Request service]\n    receive[Receive update]\n  end\n\n  subgraph Support\n    triage[Triage request]\n    answer[Send answer]\n  end\n\n  subgraph Engineering\n    investigate[Investigate issue]\n    fix[Prepare fix]\n  end\n\n  request --> triage\n  triage -->|Known issue| answer\n  triage -->|Needs code change| investigate\n  investigate --> fix --> answer\n  answer --> receive",
      ),
      PlaygroundSampleItem(
        label: "3. accTitle: Support escalation",
        source:
            "swimlane-beta LR\n  accTitle: Support escalation\n  accDescr: A request starts with the customer, is triaged by support, and may be escalated to engineering.\n\n  subgraph Customer\n    request[Open request]\n  end\n\n  subgraph Support\n    triage[Triage]\n  end\n\n  subgraph Engineering\n    resolve[Resolve]\n  end\n\n  request --> triage --> resolve",
      ),
      PlaygroundSampleItem(
        label: "4. subgraph Customer",
        source:
            "swimlane-beta LR\n  subgraph Customer\n    submit[Submit order]\n    confirm[Confirm delivery]\n  end\n\n  subgraph Store\n    check[Check order]\n    pack[Pack items]\n  end\n\n  subgraph Carrier\n    collect[Collect package]\n    deliver[Deliver package]\n  end\n\n  submit --> check --> pack --> collect --> deliver --> confirm",
      ),
      PlaygroundSampleItem(
        label: "5. subgraph Applicant",
        source:
            "swimlane-beta LR\n  subgraph Applicant\n    apply[Submit application]\n    sign[Sign agreement]\n  end\n\n  subgraph Reviewer\n    screen[Screen application]\n    decide{Approved?}\n  end\n\n  subgraph System\n    create[Create account]\n    notify[Send welcome email]\n  end\n\n  apply -->|Application received| screen\n  screen --> decide\n  decide -->|Approved| create --> notify --> sign\n  decide -->|Needs changes| apply",
      ),
      PlaygroundSampleItem(
        label: "6. subgraph Intake",
        source:
            "swimlane-beta TB\n  subgraph Intake\n    collect[Collect request]\n    validate[Validate details]\n  end\n\n  subgraph Review\n    review[Review request]\n    decide{Ready?}\n  end\n\n  subgraph Delivery\n    schedule[Schedule work]\n    complete[Complete work]\n  end\n\n  collect --> validate --> review --> decide\n  decide -->|Yes| schedule --> complete\n  decide -->|No| collect",
      ),
    ],
  ),
  DiagramSample(
    id: "treemap",
    title: "Treemap",
    description: "Show hierarchical data as nested rectangles, sized by value.",
    diagramType: "treemap",
    beta: true,
    tier: 2,
    source:
        "---\nconfig:\n  treemap:\n    valueFormat: '\$0,0'\n---\ntreemap-beta\n\"Budget\"\n    \"Operations\"\n        \"Salaries\": 700000\n        \"Equipment\": 200000\n        \"Supplies\": 100000\n    \"Marketing\"\n        \"Advertising\": 400000\n        \"Events\": 100000",
    showcaseSources: <String>[
      "---\nconfig:\n  treemap:\n    valueFormat: '\$0,0'\n---\ntreemap-beta\n\"Budget\"\n    \"Operations\"\n        \"Salaries\": 700000\n        \"Equipment\": 200000\n        \"Supplies\": 100000\n    \"Marketing\"\n        \"Advertising\": 400000\n        \"Events\": 100000",
      "treemap-beta\n\"Products\"\n    \"Electronics\"\n        \"Phones\": 50\n        \"Computers\": 30\n        \"Accessories\": 20\n    \"Clothing\"\n        \"Men's\": 40\n        \"Women's\": 40",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. \"Products\"",
        source:
            "treemap-beta\n\"Products\"\n    \"Electronics\"\n        \"Phones\": 50\n        \"Computers\": 30\n        \"Accessories\": 20\n    \"Clothing\"\n        \"Men's\": 40\n        \"Women's\": 40",
      ),
      PlaygroundSampleItem(
        label: "2. \"Section 1\"",
        source:
            "treemap-beta\n\"Section 1\"\n    \"Leaf 1.1\": 12\n    \"Section 1.2\":::class1\n      \"Leaf 1.2.1\": 12\n\"Section 2\"\n    \"Leaf 2.1\": 20:::class1\n    \"Leaf 2.2\": 25\n    \"Leaf 2.3\": 12\n\nclassDef class1 fill:red,color:blue,stroke:#FFD600;",
      ),
      PlaygroundSampleItem(
        label: "3. \"Main\"",
        source:
            "treemap-beta\n\"Main\"\n    \"A\": 20\n    \"B\":::important\n        \"B1\": 10\n        \"B2\": 15\n    \"C\": 5\n\nclassDef important fill:#f96,stroke:#333,stroke-width:2px;",
      ),
      PlaygroundSampleItem(
        label: "4. \"Category A\"",
        source:
            "---\nconfig:\n  treemap:\n    diagramPadding: 200\n---\ntreemap-beta\n\"Category A\"\n    \"Item A1\": 10\n    \"Item A2\": 20\n\"Category B\"\n    \"Item B1\": 15\n    \"Item B2\": 25",
      ),
      PlaygroundSampleItem(
        label: "5. \"Budget\"",
        source:
            "---\nconfig:\n  treemap:\n    valueFormat: '\$0,0'\n---\ntreemap-beta\n\"Budget\"\n    \"Operations\"\n        \"Salaries\": 700000\n        \"Equipment\": 200000\n        \"Supplies\": 100000\n    \"Marketing\"\n        \"Advertising\": 400000\n        \"Events\": 100000",
      ),
      PlaygroundSampleItem(
        label: "6. \"Market Share\"",
        source:
            "---\nconfig:\n  treemap:\n    valueFormat: '\$.1%'\n---\ntreemap-beta\n\"Market Share\"\n    \"Company A\": 0.35\n    \"Company B\": 0.25\n    \"Company C\": 0.15\n    \"Others\": 0.25",
      ),
    ],
  ),
  DiagramSample(
    id: "treeview",
    title: "Tree view",
    description: "Show a hierarchy, such as files and folders.",
    diagramType: "treeview",
    beta: true,
    tier: 2,
    source:
        "---\nconfig:\n  treeView:\n    showIcons: true\n    defaultIconPack: material-icon-theme\n    filenameIcons:\n      Dockerfile: docker\n    extensionIcons:\n      .ts: typescript\n      .tsx: react-ts\n      .txt: none\n---\ntreeView-beta\n    src/\n        App.tsx\n        utils.ts\n    Dockerfile\n    notes.txt\n    README.md",
    showcaseSources: <String>[
      "---\nconfig:\n  treeView:\n    showIcons: true\n    defaultIconPack: material-icon-theme\n    filenameIcons:\n      Dockerfile: docker\n    extensionIcons:\n      .ts: typescript\n      .tsx: react-ts\n      .txt: none\n---\ntreeView-beta\n    src/\n        App.tsx\n        utils.ts\n    Dockerfile\n    notes.txt\n    README.md",
      "treeView-beta\n    my-project/\n        src/\n            App.tsx :::highlight icon(logos:react) ## main component\n            index.js ## entry point\n        .env ## environment variables\n        Dockerfile\n        package.json",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. ├── src/",
        source:
            "treeView-beta\n├── src/\n│   ├── App.tsx :::highlight icon(logos:react) ## main component\n│   └── index.ts ## entry point\n├── .env ## environment variables\n├── Dockerfile\n└── package.json",
      ),
      PlaygroundSampleItem(
        label: "2. ├── packages/",
        source:
            "treeView-beta\n├── packages/\n│   ├── mermaid/\n│   │   ├── src/\n│   │   │   ├── parser.ts\n│   │   │   └── renderer.ts\n│   │   └── package.json\n│   └── parser/\n│       └── src/\n└── README.md",
      ),
      PlaygroundSampleItem(
        label: "3. src/",
        source:
            "---\nconfig:\n  treeView:\n    showIcons: true\n    defaultIconPack: material-icon-theme\n    filenameIcons:\n      Dockerfile: docker\n    extensionIcons:\n      .ts: typescript\n      .tsx: react-ts\n      .txt: none\n---\ntreeView-beta\n    src/\n        App.tsx\n        utils.ts\n    Dockerfile\n    notes.txt\n    README.md",
      ),
      PlaygroundSampleItem(
        label: "4. my-project/",
        source:
            "treeView-beta\n    my-project/\n        src/\n            App.tsx :::highlight icon(logos:react) ## main component\n            index.js ## entry point\n        .env ## environment variables\n        Dockerfile\n        package.json",
      ),
      PlaygroundSampleItem(
        label: "5. 🚀 rocket-app/",
        source:
            "treeView-beta\n    🚀 rocket-app/\n        📦 packages/\n            🎨 ui/\n            🛠️ utils/\n        🧪 tests/\n        📝 README.md\n        ⚙️ config.yaml",
      ),
      PlaygroundSampleItem(
        label: "6. \"packages\"",
        source:
            "---\nconfig:\n    treeView:\n        rowIndent: 80\n        lineThickness: 3\n    themeVariables:\n        treeView:\n            labelFontSize: '20px'\n            labelColor: '#FF0000'\n            lineColor: '#00FF00'\n---\ntreeView-beta\n    \"packages\"\n        \"mermaid\"\n            \"src\"\n        \"parser\"",
      ),
    ],
  ),
  DiagramSample(
    id: "usecase",
    title: "Use case",
    description: "Show actors and the goals they reach with a system.",
    diagramType: "usecase",
    beta: true,
    tier: 2,
    source:
        "---\nconfig:\n  usecase:\n    actorFontSize: 16\n    actorFontFamily: Arial\n    actorFontWeight: bold\n    usecaseFontSize: 14\n    usecaseFontFamily: Georgia\n    usecaseFontWeight: normal\n    nodeSpacing: 60\n    rankSpacing: 70\n    diagramPadding: 24\n    colorScheme: role\n    useMaxWidth: false\n---\nusecase-beta\ndirection LR\nactor Customer\nBrowse(\"Browse catalog\")\nCustomer --> Browse",
    showcaseSources: <String>[
      "---\nconfig:\n  usecase:\n    actorFontSize: 16\n    actorFontFamily: Arial\n    actorFontWeight: bold\n    usecaseFontSize: 14\n    usecaseFontFamily: Georgia\n    usecaseFontWeight: normal\n    nodeSpacing: 60\n    rankSpacing: 70\n    diagramPadding: 24\n    colorScheme: role\n    useMaxWidth: false\n---\nusecase-beta\ndirection LR\nactor Customer\nBrowse(\"Browse catalog\")\nCustomer --> Browse",
      "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nusecase-beta\ndirection LR\nactor Customer\nactor Support\nsystemBoundary Storefront\n  Browse(\"Browse catalog\")\n  Checkout(\"Checkout\")\nend\nsystemBoundary Fulfilment\n  Track(\"Track delivery\")\nend\nCustomer --> Browse\nCustomer --> Checkout\nCustomer --> Track\nSupport --> Track\nCheckout ..> : include Browse",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. direction LR",
        source:
            "---\nconfig:\n  theme: default\n  look: classic\n  layout: dagre\n---\nusecase-beta\ndirection LR\nactor Customer\nactor Support\nsystemBoundary Storefront\n  Browse(\"Browse catalog\")\n  Checkout(\"Checkout\")\nend\nsystemBoundary Fulfilment\n  Track(\"Track delivery\")\nend\nCustomer --> Browse\nCustomer --> Checkout\nCustomer --> Track\nSupport --> Track\nCheckout ..> : include Browse",
      ),
      PlaygroundSampleItem(
        label: "2. actor Normal(\"Normal actor\")",
        source:
            "usecase-beta\nactor Normal(\"Normal actor\")\nactor Hollow(\"Hollow actor\")@{ type: hollow }\nactor Awesome(\"Awesome actor\")@{ type: awesome }\nactor Icon(\"Registered icon\")@{ icon: \"fa:user\" }\nactor Fallback(\"Missing icon fallback\")@{ icon: \"not-registered:user\" }\nNormal --> Manage\nHollow --> Manage\nAwesome --> Manage\nIcon --> Manage\nFallback --> Manage",
      ),
      PlaygroundSampleItem(
        label: "3. Inspect(\"Inspect payload\")",
        source:
            "usecase-beta\nInspect(\"Inspect payload\")\njson Payload@{\n  \"2\": \"second in source\",\n  \"1\": \"first after 2\",\n  \"enabled\": true,\n  \"count\": 3,\n  \"missing\": null,\n  \"colors\": [\"Red\", \"Green\"],\n  \"address\": { \"city\": \"Oslo\" },\n  \"items\": [{ \"name\": \"Book\" }],\n  \"emptyObject\": {},\n  \"emptyArray\": []\n}:::data\nInspect --> Payload\nclassDef data stroke:#3572a5\nstyle Payload stroke-width:2px",
      ),
      PlaygroundSampleItem(
        label: "4. actor Customer:::external",
        source:
            "usecase-beta\nactor Customer:::external\nCheckout(\"Checkout\"):::critical\nsystemBoundary Account\n  Profile[Edit profile]\nend\njson Session@{ \"active\": true }:::data\nCustomer --> Checkout\nCheckout --> Profile\nProfile --> Session\nclassDef default stroke:#7f8ea3\nclassDef external,critical stroke-width:3px\nclass Customer,Checkout external,critical\nclass Account,Session data\nstyle Checkout stroke:#c33,stroke-width:4px\nstyle Account stroke:#536878",
      ),
      PlaygroundSampleItem(
        label: "5. direction LR",
        source:
            "---\nconfig:\n  usecase:\n    actorFontSize: 16\n    actorFontFamily: Arial\n    actorFontWeight: bold\n    usecaseFontSize: 14\n    usecaseFontFamily: Georgia\n    usecaseFontWeight: normal\n    nodeSpacing: 60\n    rankSpacing: 70\n    diagramPadding: 24\n    colorScheme: role\n    useMaxWidth: false\n---\nusecase-beta\ndirection LR\nactor Customer\nBrowse(\"Browse catalog\")\nCustomer --> Browse",
      ),
      PlaygroundSampleItem(
        label: "6. direction LR",
        source:
            "usecase-beta\ndirection LR\naccTitle: Online ordering use cases\naccDescr {\n  A customer places an order through the storefront.\n  Staff review the order and inspect its data.\n}\nactor Customer(\"Customer\")\nactor Staff(\"Order staff\")@{ type: hollow, business: true } <<Employee>>\nsystemBoundary ordering[\"Ordering System\"]@{ type: package }:::system\n  Browse(\"Browse products\")\n  Checkout(\"Checkout\") <<Core>>:::critical\n  Payment(\"Process payment\")\n  Review[Review order]\nend\njson OrderData@{\n  \"status\": \"pending\",\n  \"items\": [{ \"name\": \"Book\", \"quantity\": 1 }],\n  \"total\": 29.95\n}:::data\nnote for Checkout \"`Validates the **cart** before payment`\"\nCustomer starts@-- \"places order\" ---> Checkout\nCustomer --> Browse\nCheckout pays@..> : include Payment\nStaff --> Review\nReview --> OrderData\nclassDef system stroke:#c8a02a,stroke-width:2px\nclassDef critical stroke:#c33,stroke-width:3px\nclassDef data stroke:#3572a5\nstarts@{ animation: fast }\nstyle pays stroke:#6b46c1,stroke-width:2px",
      ),
    ],
  ),
  DiagramSample(
    id: "venn",
    title: "Venn",
    description: "Show sets and where they overlap.",
    diagramType: "venn",
    beta: true,
    tier: 2,
    source:
        "---\nconfig:\n  theme: default\n  look: classic\n---\nvenn-beta\n  title What makes a good feature\n  set Desirable\n  set Feasible\n  set Viable\n  union Desirable,Feasible[\"Buildable\"]\n  union Feasible,Viable[\"Sustainable\"]\n  union Desirable,Viable[\"Marketable\"]\n  union Desirable,Feasible,Viable[\"Ship it\"]",
    showcaseSources: <String>[
      "---\nconfig:\n  theme: default\n  look: classic\n---\nvenn-beta\n  title What makes a good feature\n  set Desirable\n  set Feasible\n  set Viable\n  union Desirable,Feasible[\"Buildable\"]\n  union Feasible,Viable[\"Sustainable\"]\n  union Desirable,Viable[\"Marketable\"]\n  union Desirable,Feasible,Viable[\"Ship it\"]",
      "venn-beta\n  set A[\"Frontend\"]\n    text A1[\"React\"]\n    text A2[\"Design Systems\"]\n  set B[\"Backend\"]\n    text B1[\"API\"]\n  union A,B[\"Shared\"]\n    text AB1[\"OpenAPI\"]",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. title What makes a good feature",
        source:
            "venn-beta\n  title What makes a good feature\n  set Desirable\n  set Feasible\n  set Viable\n  union Desirable,Feasible[\"Buildable\"]\n  union Feasible,Viable[\"Sustainable\"]\n  union Desirable,Viable[\"Marketable\"]\n  union Desirable,Feasible,Viable[\"Ship it\"]",
      ),
      PlaygroundSampleItem(
        label: "2. title What makes a good feature",
        source:
            "---\nconfig:\n  theme: default\n  look: classic\n---\nvenn-beta\n  title What makes a good feature\n  set Desirable\n  set Feasible\n  set Viable\n  union Desirable,Feasible[\"Buildable\"]\n  union Feasible,Viable[\"Sustainable\"]\n  union Desirable,Viable[\"Marketable\"]\n  union Desirable,Feasible,Viable[\"Ship it\"]",
      ),
      PlaygroundSampleItem(
        label: "3. title \"Team overlap\"",
        source:
            "venn-beta\n  title \"Team overlap\"\n  set Frontend\n  set Backend\n  union Frontend,Backend[\"APIs\"]",
      ),
      PlaygroundSampleItem(
        label: "4. set Desirable",
        source:
            "venn-beta\n  set Desirable\n  set Feasible\n  set Viable\n  union Desirable,Feasible,Viable[\"Innovation\"]",
      ),
      PlaygroundSampleItem(
        label: "5. set A[\"Frontend\"]",
        source:
            "venn-beta\n  set A[\"Frontend\"]\n    text A1[\"React\"]\n    text A2[\"Design Systems\"]\n  set B[\"Backend\"]\n    text B1[\"API\"]\n  union A,B[\"Shared\"]\n    text AB1[\"OpenAPI\"]",
      ),
      PlaygroundSampleItem(
        label: "6. set A[\"Alpha\"]:20",
        source:
            "venn-beta\n  set A[\"Alpha\"]:20\n    text A1[\"React\"]\n    text A2[\"Design Systems\"]\n  set B[\"Beta\"]:12\n  union A,B[\"AB\"]:3\n  style A fill:#ff6b6b\n  style A,B color:#333\n  style A1 color:red",
      ),
    ],
  ),
  DiagramSample(
    id: "wardley",
    title: "Wardley map",
    description:
        "Plot components by their visibility to the user and their stage of evolution.",
    diagramType: "wardley",
    beta: true,
    tier: 2,
    source:
        "wardley-beta\ntitle Tea Shop Value Chain\n\nanchor Business [0.95, 0.63]\ncomponent Cup of Tea [0.79, 0.61]\ncomponent Tea [0.63, 0.81]\ncomponent Hot Water [0.52, 0.80]\ncomponent Kettle [0.43, 0.35]\ncomponent Power [0.10, 0.70]\n\nBusiness -> Cup of Tea\nCup of Tea -> Tea\nCup of Tea -> Hot Water\nHot Water -> Kettle\nKettle -> Power\n\nevolve Kettle 0.62\nevolve Power 0.89\n\nnote \"Standardizing power allows Kettles to evolve faster\" [0.30, 0.49]",
    showcaseSources: <String>[
      "wardley-beta\ntitle Tea Shop Value Chain\n\nanchor Business [0.95, 0.63]\ncomponent Cup of Tea [0.79, 0.61]\ncomponent Tea [0.63, 0.81]\ncomponent Hot Water [0.52, 0.80]\ncomponent Kettle [0.43, 0.35]\ncomponent Power [0.10, 0.70]\n\nBusiness -> Cup of Tea\nCup of Tea -> Tea\nCup of Tea -> Hot Water\nHot Water -> Kettle\nKettle -> Power\n\nevolve Kettle 0.62\nevolve Power 0.89\n\nnote \"Standardizing power allows Kettles to evolve faster\" [0.30, 0.49]",
      "wardley-beta\ntitle Sourcing Strategy\n\nanchor Customer [0.80, 0.95]\ncomponent Custom App [0.45, 0.85] (build)\ncomponent Off-the-shelf Tool [0.85, 0.65] (buy)\ncomponent Managed Service [0.60, 0.40] (outsource)\ncomponent Cloud Platform [0.95, 0.25] (market)\n\nCustomer -> Custom App\nCustom App -> Off-the-shelf Tool\nCustom App -> Managed Service\nOff-the-shelf Tool -> Cloud Platform",
    ],
    playgroundSamples: <PlaygroundSampleItem>[
      PlaygroundSampleItem(
        label: "1. title Tea Shop Value Chain",
        source:
            "wardley-beta\ntitle Tea Shop Value Chain\n\nanchor Business [0.95, 0.63]\ncomponent Cup of Tea [0.79, 0.61]\ncomponent Tea [0.63, 0.81]\ncomponent Hot Water [0.52, 0.80]\ncomponent Kettle [0.43, 0.35]\ncomponent Power [0.10, 0.70]\n\nBusiness -> Cup of Tea\nCup of Tea -> Tea\nCup of Tea -> Hot Water\nHot Water -> Kettle\nKettle -> Power\n\nevolve Kettle 0.62\nevolve Power 0.89\n\nnote \"Standardizing power allows Kettles to evolve faster\" [0.30, 0.49]",
      ),
      PlaygroundSampleItem(
        label: "2. title Coordinate Examples",
        source:
            "wardley-beta\ntitle Coordinate Examples\n\ncomponent Infrastructure [0.30, 0.20]        %% Low visibility, low evolution\ncomponent Product [0.70, 0.60]               %% High visibility, mid evolution\ncomponent User Need [0.90, 0.95]             %% High visibility, high evolution",
      ),
      PlaygroundSampleItem(
        label: "3. title Sourcing Strategy",
        source:
            "wardley-beta\ntitle Sourcing Strategy\n\nanchor Customer [0.80, 0.95]\ncomponent Custom App [0.45, 0.85] (build)\ncomponent Off-the-shelf Tool [0.85, 0.65] (buy)\ncomponent Managed Service [0.60, 0.40] (outsource)\ncomponent Cloud Platform [0.95, 0.25] (market)\n\nCustomer -> Custom App\nCustom App -> Off-the-shelf Tool\nCustom App -> Managed Service\nOff-the-shelf Tool -> Cloud Platform",
      ),
      PlaygroundSampleItem(
        label: "4. title Dual Label Stages",
        source:
            "wardley-beta\ntitle Dual Label Stages\n\nevolution Genesis / Concept -> Custom / Emerging -> Product / Converging -> Commodity / Accepted\n\ncomponent Novel Idea [0.05, 0.20]\ncomponent Custom Solution [0.35, 0.50]\ncomponent Product [0.65, 0.70]\ncomponent Utility [0.95, 0.90]",
      ),
      PlaygroundSampleItem(
        label: "5. title Annotations",
        source:
            "wardley-beta\ntitle Annotations\n\ncomponent API [0.60, 0.70]\ncomponent Cache [0.50, 0.55]\ncomponent Database [0.40, 0.40]\n\nAPI -> Cache\nCache -> Database\n\nannotations [0.10, 0.90]\nannotation 1,[0.60, 0.65] \"Critical component\"\nannotation 2,[0.50, 0.50] \"Performance layer\"\nannotation 3,[0.40, 0.35] \"Data persistence\"",
      ),
      PlaygroundSampleItem(
        label: "6. title Software Platform Strategy",
        source:
            "wardley-beta\ntitle Software Platform Strategy\nsize [1100, 800]\n\nevolution Genesis@0.25 -> Custom@0.5 -> Product@0.75 -> Commodity@1.0\n\nanchor Customer [0.90, 0.95]\n\ncomponent \"Mobile App\" [0.80, 0.85] (build)\ncomponent \"Web App\" [0.75, 0.80] label [-60, 10] (build)\ncomponent \"API Gateway\" [0.70, 0.65] (buy)\ncomponent \"Auth Service\" [0.60, 0.55] (outsource)\ncomponent \"Database\" [0.50, 0.45] (buy) (inertia)\ncomponent \"Cloud Platform\" [0.30, 0.95] (market)\n\nCustomer -> \"Mobile App\"\nCustomer -> \"Web App\"\n\"Mobile App\" -> \"API Gateway\"\n\"Web App\" -> \"API Gateway\"\n\"API Gateway\" -> \"Auth Service\"\n\"API Gateway\" -> \"Database\"\n\"Database\" -> \"Cloud Platform\"\n\nevolve \"API Gateway\" 0.85\nevolve \"Database\" 0.75\n\naccelerator \"Cloud Native\" [0.20, 0.85]\ndeaccelerator \"Legacy Data\" [0.45, 0.35]\n\nannotations [0.10, 0.20]\nannotation 1,[0.78, 0.82] \"User touchpoints\"\nannotation 2,[0.70, 0.60] \"Integration layer\"\nannotation 3,[0.50, 0.40] \"Data persistence\"\n\nnote \"Build mobile-first experience\" [0.85, 0.90]\nnote \"Migrate to cloud-native database\" [0.60, 0.50]",
      ),
    ],
  ),
];
