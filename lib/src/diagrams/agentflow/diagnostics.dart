// Upstream: src/diagrams/agentflow/diagnostics.ts

import 'types.dart';

// Mermaid's diagnostic vocabulary for agentflow. Only the ids in EMITTED are raised by a parser;
// the rest are reserved for tools that check a diagram's meaning.
const Map<DiagnosticId, DiagnosticId> AgentflowWarning =
    <DiagnosticId, DiagnosticId>{
      'SHAPE_UNSUPPORTED': 'SHAPE_UNSUPPORTED',
      'SHAPE_REMOVED': 'SHAPE_REMOVED',
      'EDGE_OPERATOR_UNSUPPORTED': 'EDGE_OPERATOR_UNSUPPORTED',
      'REFERENCE_EDGE_LABEL_REJECTED': 'REFERENCE_EDGE_LABEL_REJECTED',
      'CONNECTOR_REF_UNRESOLVED': 'CONNECTOR_REF_UNRESOLVED',
      'CONNECTOR_REF_NOT_A_CONNECTOR': 'CONNECTOR_REF_NOT_A_CONNECTOR',
      'METADATA_KEY_MISAPPLIED': 'METADATA_KEY_MISAPPLIED',
      'DUPLICATE_ID_NODE': 'DUPLICATE_ID_NODE',
      'RESERVED_SYNTHETIC_ID': 'RESERVED_SYNTHETIC_ID',
      'CONTAINMENT_VIOLATION': 'CONTAINMENT_VIOLATION',
      'EDGE_SEMANTIC_CONTRADICTION': 'EDGE_SEMANTIC_CONTRADICTION',
      'FLOW_NO_INPUT': 'FLOW_NO_INPUT',
    };

const Set<DiagnosticId> EMITTED = <DiagnosticId>{
  'SHAPE_UNSUPPORTED',
  'SHAPE_REMOVED',
  'CONTAINMENT_VIOLATION',
};

final Set<DiagnosticId> RESERVED = Set<DiagnosticId>.unmodifiable(
  AgentflowWarning.values.where((id) => !EMITTED.contains(id)),
);
