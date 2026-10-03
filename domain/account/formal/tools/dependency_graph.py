#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import defaultdict, deque
from dataclasses import dataclass, field
from pathlib import Path


# ============================================================================
# Dafny Dependency Analyzer
# ============================================================================
#
# PURPOSE
# -------
#
# This analyzer is intentionally NOT a full Dafny parser.
#
# Its purpose is to deterministically answer:
#
#   - Which .dfy files exist?
#   - Which module belongs to each file?
#   - What does each file directly depend on?
#   - Who directly depends on each file?
#   - What are the transitive dependencies?
#   - What are the transitive dependents?
#   - What is the dependency-first implementation/refactor order?
#   - Which files are foundational?
#   - Which files have high fan-in?
#   - Which files have high fan-out?
#   - Are there cycles?
#   - Are there unresolved includes/modules?
#
# The generated JSON is intended to be a COMPLETE SNAPSHOT of the
# deterministic analysis so that another AI can consume the JSON directly
# without reconstructing the dependency graph from the raw .dfy files.
#
#
# SOURCE OF TRUTH
# ---------------
#
# The current filesystem is ALWAYS the source of truth.
#
# Every execution:
#
#   1. Discovers every *.dfy currently on disk.
#   2. Scans every file.
#   3. Rebuilds the module index.
#   4. Rebuilds every dependency edge.
#   5. Rebuilds fan-in/fan-out.
#   6. Rebuilds transitive dependency information.
#   7. Rebuilds dependency order/layers.
#   8. Rebuilds cycles.
#   9. Completely rewrites all generated artifacts.
#
# No cache.
# No manifest.
# No previous graph.
# No hardcoded .dfy list.
#
#
# GENERATED FILES
# ---------------
#
#   dependencies.dot
#   dependency-report.txt
#   dependencies.json
#
#
# IMPORTANT GRAPH SEMANTICS
# -------------------------
#
# An edge:
#
#       A -> B
#
# means:
#
#       A DEPENDS ON B
#
# Therefore:
#
#   fan-out(A) = files A depends on
#   fan-in(A)  = files that depend on A
#
# Example:
#
#       DomainTypes.dfy
#              ^
#              |
#       Account.dfy
#
# Then:
#
#   Account.dfy:
#       fan-out = 1
#       depends_on = [DomainTypes.dfy]
#
#   DomainTypes.dfy:
#       fan-out = 0
#       fan-in = 1
#       depended_on_by = [Account.dfy]
#
#
# DEPENDENCY ORDER
# ----------------
#
# Dependencies appear BEFORE their dependents.
#
# If:
#
#       A -> B
#
# then:
#
#       B
#       A
#
# is the valid dependency-first order.
#
#
# NOTE ABOUT "INDEPENDENT"
# ------------------------
#
# fan-out == 0 means:
#
#   "no explicit dependencies detected"
#
# It does NOT prove semantic architectural independence.
#
# A file with:
#
#   fan-out = 0
#   fan-in  = 28
#
# is nevertheless a very important foundational node in the observed graph.
#
# ============================================================================


SCHEMA_VERSION = 2


# ============================================================================
# Regexes
# ============================================================================

MODULE_RE = re.compile(
    r"^\s*module\s+([A-Za-z_][A-Za-z0-9_]*)\b"
)

INCLUDE_RE = re.compile(
    r'^\s*include\s+"([^"]+)"'
)

IMPORT_OPENED_RE = re.compile(
    r"^\s*import\s+opened\s+([A-Za-z_][A-Za-z0-9_]*)\b"
)

IMPORT_NORMAL_RE = re.compile(
    r"^\s*import\s+(?!opened\b)([A-Za-z_][A-Za-z0-9_]*)\b"
)


# ============================================================================
# Data model
# ============================================================================


@dataclass(frozen=True)
class IncludeDependency:
    raw: str
    line: int


@dataclass(frozen=True)
class ImportOpenedDependency:
    module: str
    line: int


@dataclass(frozen=True)
class ImportDependency:
    module: str
    line: int


@dataclass
class DafnyFile:
    path: Path

    module: str | None = None
    module_line: int | None = None

    includes: list[IncludeDependency] = field(
        default_factory=list
    )

    imports_opened: list[ImportOpenedDependency] = field(
        default_factory=list
    )

    imports: list[ImportDependency] = field(
        default_factory=list
    )

    parse_errors: list[str] = field(
        default_factory=list
    )

    @property
    def has_explicit_dependencies(self) -> bool:
        return bool(
            self.includes
            or self.imports_opened
            or self.imports
        )

    @property
    def no_explicit_dependencies(self) -> bool:
        return not self.has_explicit_dependencies


@dataclass
class Graph:
    """
    Directed dependency graph.

    Edge semantics:

        source -> target

    means:

        source depends on target
    """

    include_edges: dict[Path, set[Path]] = field(
        default_factory=lambda: defaultdict(set)
    )

    import_opened_edges: dict[Path, set[Path]] = field(
        default_factory=lambda: defaultdict(set)
    )

    import_edges: dict[Path, set[Path]] = field(
        default_factory=lambda: defaultdict(set)
    )

    missing_includes: list[
        tuple[Path, str, Path | None]
    ] = field(default_factory=list)

    missing_modules: list[
        tuple[Path, str]
    ] = field(default_factory=list)

    invisible_imports: list[
        tuple[Path, str, Path]
    ] = field(default_factory=list)


# ============================================================================
# General helpers
# ============================================================================


def path_key(path: Path) -> str:
    return path.as_posix()


def sort_paths(paths: set[Path] | list[Path]) -> list[Path]:
    return sorted(
        paths,
        key=path_key,
    )


def relative_path(
    path: Path,
    root: Path,
) -> Path:
    return path.resolve().relative_to(
        root.resolve()
    )


def relative_string(
    path: Path,
    root: Path,
) -> str:
    return relative_path(
        path,
        root,
    ).as_posix()


# ============================================================================
# Comment stripping
# ============================================================================


def strip_comments(text: str) -> str:
    """
    Remove // and /* */ comments while preserving strings.

    This is intentionally a small lexer rather than a regex replacement.
    """

    result: list[str] = []

    i = 0
    length = len(text)

    in_string = False
    in_line_comment = False
    in_block_comment = False

    while i < length:
        char = text[i]
        next_char = (
            text[i + 1]
            if i + 1 < length
            else ""
        )

        # ---------------------------------------------------------------
        # Line comment
        # ---------------------------------------------------------------

        if in_line_comment:
            if char == "\n":
                in_line_comment = False
                result.append("\n")
            else:
                result.append(" ")

            i += 1
            continue

        # ---------------------------------------------------------------
        # Block comment
        # ---------------------------------------------------------------

        if in_block_comment:
            if char == "*" and next_char == "/":
                in_block_comment = False
                result.append(" ")
                result.append(" ")
                i += 2
            else:
                if char == "\n":
                    result.append("\n")
                else:
                    result.append(" ")

                i += 1

            continue

        # ---------------------------------------------------------------
        # String
        # ---------------------------------------------------------------

        if in_string:
            result.append(char)

            if char == "\\" and next_char:
                result.append(next_char)
                i += 2
                continue

            if char == '"':
                in_string = False

            i += 1
            continue

        # ---------------------------------------------------------------
        # Start comments
        # ---------------------------------------------------------------

        if char == "/" and next_char == "/":
            in_line_comment = True
            result.append(" ")
            result.append(" ")
            i += 2
            continue

        if char == "/" and next_char == "*":
            in_block_comment = True
            result.append(" ")
            result.append(" ")
            i += 2
            continue

        # ---------------------------------------------------------------
        # Start string
        # ---------------------------------------------------------------

        if char == '"':
            in_string = True
            result.append(char)
            i += 1
            continue

        result.append(char)
        i += 1

    return "".join(result)


# ============================================================================
# File scanning
# ============================================================================


def scan_file(path: Path) -> DafnyFile:
    result = DafnyFile(
        path=path
    )

    try:
        text = path.read_text(
            encoding="utf-8"
        )

    except UnicodeDecodeError as exc:
        result.parse_errors.append(
            f"could not decode file as UTF-8: {exc}"
        )
        return result

    except OSError as exc:
        result.parse_errors.append(
            f"could not read file: {exc}"
        )
        return result

    clean_text = strip_comments(text)

    for line_number, line in enumerate(
        clean_text.splitlines(),
        start=1,
    ):
        # ---------------------------------------------------------------
        # module
        # ---------------------------------------------------------------

        module_match = MODULE_RE.match(line)

        if module_match:
            module_name = module_match.group(1)

            if result.module is not None:
                result.parse_errors.append(
                    "multiple module declarations: "
                    f"{result.module} and {module_name} "
                    f"(line {line_number})"
                )

            else:
                result.module = module_name
                result.module_line = line_number

            continue

        # ---------------------------------------------------------------
        # include
        # ---------------------------------------------------------------

        include_match = INCLUDE_RE.match(line)

        if include_match:
            result.includes.append(
                IncludeDependency(
                    raw=include_match.group(1),
                    line=line_number,
                )
            )

            continue

        # ---------------------------------------------------------------
        # import opened
        # ---------------------------------------------------------------

        import_opened_match = (
            IMPORT_OPENED_RE.match(line)
        )

        if import_opened_match:
            result.imports_opened.append(
                ImportOpenedDependency(
                    module=import_opened_match.group(1),
                    line=line_number,
                )
            )

            continue

        # ---------------------------------------------------------------
        # normal import
        # ---------------------------------------------------------------

        import_match = IMPORT_NORMAL_RE.match(line)

        if import_match:
            result.imports.append(
                ImportDependency(
                    module=import_match.group(1),
                    line=line_number,
                )
            )

            continue

    return result


# ============================================================================
# Project discovery
# ============================================================================


def discover_dafny_files(
    root: Path,
) -> list[Path]:
    """
    Discover the REAL .dfy files currently present on disk.
    """

    return sorted(
        (
            path
            for path in root.rglob("*.dfy")
            if path.is_file()
        ),
        key=lambda path: relative_string(
            path,
            root,
        ),
    )


def scan_project(
    root: Path,
) -> list[DafnyFile]:
    paths = discover_dafny_files(
        root
    )

    return [
        scan_file(path)
        for path in paths
    ]


# ============================================================================
# Include resolution
# ============================================================================


def resolve_include(
    source: DafnyFile,
    include_path: str,
    root: Path,
) -> tuple[str, Path | None]:
    """
    Resolve include relative to source file.

    Returns:

        ("project", relative_path)

    or:

        ("external", None)
    """

    candidate = (
        source.path.parent / include_path
    ).resolve()

    try:
        relative = candidate.relative_to(
            root.resolve()
        )

    except ValueError:
        return "external", None

    return "project", relative


# ============================================================================
# Module index
# ============================================================================


def build_module_index(
    files: list[DafnyFile],
) -> tuple[
    dict[str, DafnyFile],
    list[str],
]:
    index: dict[str, DafnyFile] = {}
    errors: list[str] = []

    for file in files:
        if not file.module:
            continue

        module = file.module

        if module in index:
            previous = index[module]

            errors.append(
                "duplicate module declaration:\n"
                f"  module {module}\n"
                f"  - {previous.path}\n"
                f"  - {file.path}"
            )

            continue

        index[module] = file

    return index, errors


# ============================================================================
# Graph construction
# ============================================================================


def build_graph(
    files: list[DafnyFile],
    module_index: dict[str, DafnyFile],
    root: Path,
) -> Graph:
    graph = Graph()

    file_set = {
        relative_path(
            file.path,
            root,
        )
        for file in files
    }

    # -----------------------------------------------------------------------
    # include
    # -----------------------------------------------------------------------

    for file in files:
        source = relative_path(
            file.path,
            root,
        )

        for dependency in file.includes:
            kind, target = resolve_include(
                file,
                dependency.raw,
                root,
            )

            if kind == "external":
                graph.missing_includes.append(
                    (
                        source,
                        dependency.raw,
                        None,
                    )
                )

                continue

            assert target is not None

            if target not in file_set:
                graph.missing_includes.append(
                    (
                        source,
                        dependency.raw,
                        target,
                    )
                )

                continue

            graph.include_edges[
                source
            ].add(target)

    # -----------------------------------------------------------------------
    # import opened
    # -----------------------------------------------------------------------

    for file in files:
        source = relative_path(
            file.path,
            root,
        )

        for dependency in file.imports_opened:
            target_file = module_index.get(
                dependency.module
            )

            if target_file is None:
                graph.missing_modules.append(
                    (
                        source,
                        dependency.module,
                    )
                )

                continue

            target = relative_path(
                target_file.path,
                root,
            )

            graph.import_opened_edges[
                source
            ].add(target)

    # -----------------------------------------------------------------------
    # normal import
    # -----------------------------------------------------------------------

    for file in files:
        source = relative_path(
            file.path,
            root,
        )

        for dependency in file.imports:
            target_file = module_index.get(
                dependency.module
            )

            if target_file is None:
                graph.missing_modules.append(
                    (
                        source,
                        dependency.module,
                    )
                )

                continue

            target = relative_path(
                target_file.path,
                root,
            )

            graph.import_edges[
                source
            ].add(target)

    # -----------------------------------------------------------------------
    # import opened visibility
    # -----------------------------------------------------------------------

    for file in files:
        source = relative_path(
            file.path,
            root,
        )

        reachable = reachable_nodes(
            source,
            graph.include_edges,
        )

        for dependency in file.imports_opened:
            target_file = module_index.get(
                dependency.module
            )

            if target_file is None:
                continue

            target = relative_path(
                target_file.path,
                root,
            )

            if source == target:
                continue

            if target not in reachable:
                graph.invisible_imports.append(
                    (
                        source,
                        dependency.module,
                        target,
                    )
                )

    return graph


# ============================================================================
# Graph composition
# ============================================================================


def all_project_nodes(
    files: list[DafnyFile],
    root: Path,
) -> list[Path]:
    return sorted(
        (
            relative_path(
                file.path,
                root,
            )
            for file in files
        ),
        key=path_key,
    )


def combined_edges(
    graph: Graph,
) -> dict[Path, set[Path]]:
    """
    Combined architectural dependency graph.

    Includes:

        include
        import opened
        import

    Every explicit dependency contributes to the combined graph.
    """

    result: dict[
        Path,
        set[Path],
    ] = defaultdict(set)

    for source, targets in (
        graph.include_edges.items()
    ):
        result[source].update(targets)

    for source, targets in (
        graph.import_opened_edges.items()
    ):
        result[source].update(targets)

    for source, targets in (
        graph.import_edges.items()
    ):
        result[source].update(targets)

    return result


def edge_kinds(
    graph: Graph,
    source: Path,
    target: Path,
) -> list[str]:
    kinds: list[str] = []

    if target in graph.include_edges.get(
        source,
        set(),
    ):
        kinds.append("include")

    if target in graph.import_opened_edges.get(
        source,
        set(),
    ):
        kinds.append("import_opened")

    if target in graph.import_edges.get(
        source,
        set(),
    ):
        kinds.append("import")

    return kinds


# ============================================================================
# Reachability
# ============================================================================


def reachable_nodes(
    start: Path,
    edges: dict[Path, set[Path]],
) -> set[Path]:
    visited: set[Path] = set()

    queue: deque[Path] = deque(
        edges.get(
            start,
            set(),
        )
    )

    while queue:
        current = queue.popleft()

        if current in visited:
            continue

        visited.add(current)

        for target in edges.get(
            current,
            set(),
        ):
            if target not in visited:
                queue.append(target)

    return visited


def reverse_edges(
    nodes: list[Path],
    edges: dict[Path, set[Path]],
) -> dict[Path, set[Path]]:
    result: dict[
        Path,
        set[Path],
    ] = defaultdict(set)

    for node in nodes:
        result[node] = set()

    for source, targets in edges.items():
        for target in targets:
            result[target].add(source)

    return result


# ============================================================================
# Cycles
# ============================================================================


def find_cycles(
    edges: dict[Path, set[Path]],
) -> list[list[Path]]:
    """
    Find directed cycles using DFS.

    The output is deterministic and normalized.
    """

    WHITE = 0
    GRAY = 1
    BLACK = 2

    state: dict[
        Path,
        int,
    ] = defaultdict(
        lambda: WHITE
    )

    stack: list[Path] = []
    cycles: list[list[Path]] = []

    def visit(node: Path) -> None:
        state[node] = GRAY
        stack.append(node)

        for target in sort_paths(
            edges.get(
                node,
                set(),
            )
        ):
            if state[target] == WHITE:
                visit(target)

            elif state[target] == GRAY:
                try:
                    index = stack.index(
                        target
                    )

                except ValueError:
                    continue

                cycle = (
                    stack[index:]
                    + [target]
                )

                cycles.append(cycle)

        stack.pop()
        state[node] = BLACK

    nodes = set(edges.keys())

    for targets in edges.values():
        nodes.update(targets)

    for node in sort_paths(nodes):
        if state[node] == WHITE:
            visit(node)

    normalized: set[
        tuple[str, ...]
    ] = set()

    result: list[list[Path]] = []

    for cycle in cycles:
        names = [
            path.as_posix()
            for path in cycle[:-1]
        ]

        if not names:
            continue

        rotations = []

        for i in range(len(names)):
            rotation = (
                names[i:]
                + names[:i]
            )

            rotations.append(
                tuple(rotation)
            )

        canonical = min(
            rotations
        )

        if canonical in normalized:
            continue

        normalized.add(canonical)

        canonical_paths = [
            Path(name)
            for name in canonical
        ]

        canonical_paths.append(
            canonical_paths[0]
        )

        result.append(
            canonical_paths
        )

    result.sort(
        key=lambda cycle: [
            path.as_posix()
            for path in cycle
        ]
    )

    return result


# ============================================================================
# Topological order
# ============================================================================


def topological_order(
    nodes: list[Path],
    edges: dict[Path, set[Path]],
) -> list[Path] | None:
    """
    Dependency-first topological ordering.

    A -> B means:

        A depends on B

    Therefore B appears before A.
    """

    dependents = reverse_edges(
        nodes,
        edges,
    )

    indegree: dict[
        Path,
        int,
    ] = {
        node: 0
        for node in nodes
    }

    for source in nodes:
        for dependency in edges.get(
            source,
            set(),
        ):
            indegree[source] += 1

    ready = [
        node
        for node in nodes
        if indegree[node] == 0
    ]

    ready.sort(
        key=path_key
    )

    result: list[Path] = []

    while ready:
        node = ready.pop(0)
        result.append(node)

        for dependent in sort_paths(
            dependents.get(
                node,
                set(),
            )
        ):
            indegree[dependent] -= 1

            if indegree[dependent] == 0:
                ready.append(
                    dependent
                )

                ready.sort(
                    key=path_key
                )

    if len(result) != len(nodes):
        return None

    return result


# ============================================================================
# Dependency layers
# ============================================================================


def dependency_layers(
    nodes: list[Path],
    edges: dict[Path, set[Path]],
) -> dict[Path, int]:
    """
    Assign deterministic dependency layers.

    Layer 0:
        no dependencies.

    Layer N:
        depends only on nodes from lower layers.

    If a cycle exists, nodes involved in the unresolved portion receive
    -1.
    """

    dependencies = {
        node: set(
            edges.get(
                node,
                set(),
            )
        )
        for node in nodes
    }

    layers: dict[
        Path,
        int,
    ] = {}

    remaining = set(nodes)

    layer = 0

    while remaining:
        ready = sorted(
            (
                node
                for node in remaining
                if all(
                    dependency in layers
                    for dependency in dependencies[node]
                )
            ),
            key=path_key,
        )

        if not ready:
            break

        for node in ready:
            layers[node] = layer
            remaining.remove(node)

        layer += 1

    for node in remaining:
        layers[node] = -1

    return layers


# ============================================================================
# Graph metrics
# ============================================================================


def compute_metrics(
    nodes: list[Path],
    graph: Graph,
) -> dict[Path, dict]:
    """
    Compute all per-file graph metrics.

    This is the heart of the analyzer.

    Every file receives a metric object, including files with zero
    dependencies and zero dependents.
    """

    combined = combined_edges(
        graph
    )

    reverse = reverse_edges(
        nodes,
        combined,
    )

    layers = dependency_layers(
        nodes,
        combined,
    )

    metrics: dict[
        Path,
        dict,
    ] = {}

    for node in nodes:
        direct_dependencies = set(
            combined.get(
                node,
                set(),
            )
        )

        direct_dependents = set(
            reverse.get(
                node,
                set(),
            )
        )

        transitive_dependencies = (
            reachable_nodes(
                node,
                combined,
            )
        )

        transitive_dependents = (
            reachable_nodes(
                node,
                reverse,
            )
        )

        metrics[node] = {
            "fan_out": len(
                direct_dependencies
            ),
            "fan_in": len(
                direct_dependents
            ),

            "direct_dependency_count": len(
                direct_dependencies
            ),

            "direct_dependent_count": len(
                direct_dependents
            ),

            "transitive_dependency_count": len(
                transitive_dependencies
            ),

            "transitive_dependent_count": len(
                transitive_dependents
            ),

            "dependency_depth": (
                layers.get(
                    node,
                    -1,
                )
            ),

            "is_foundation": (
                len(direct_dependencies) == 0
            ),

            "is_leaf": (
                len(direct_dependents) == 0
            ),

            "is_high_fan_in": (
                len(direct_dependents) >= 5
            ),

            "is_high_fan_out": (
                len(direct_dependencies) >= 5
            ),

            "direct_dependencies": (
                direct_dependencies
            ),

            "direct_dependents": (
                direct_dependents
            ),

            "transitive_dependencies": (
                transitive_dependencies
            ),

            "transitive_dependents": (
                transitive_dependents
            ),
        }

    return metrics


# ============================================================================
# Refactor priority
# ============================================================================


def calculate_refactor_priority(
    metric: dict,
) -> int:
    """
    Deterministic heuristic priority.

    Higher number = more structurally important to understand first.

    The score intentionally uses graph information only.

    Factors:

        + foundation status
        + fan-in
        + transitive fan-in
        - fan-out
        - dependency depth

    This is NOT a semantic quality score.
    It is a graph-oriented prioritization aid.
    """

    score = 0

    if metric["is_foundation"]:
        score += 100

    score += (
        metric["fan_in"] * 10
    )

    score += (
        metric["transitive_dependent_count"]
        * 2
    )

    score -= (
        metric["fan_out"] * 3
    )

    depth = metric[
        "dependency_depth"
    ]

    if depth >= 0:
        score -= depth

    return score


# ============================================================================
# DOT helpers
# ============================================================================


def dot_escape(
    value: str,
) -> str:
    return (
        value
        .replace("\\", "\\\\")
        .replace('"', '\\"')
    )


def stable_id(
    prefix: str,
    value: str,
) -> str:
    digest = hashlib.sha1(
        value.encode("utf-8")
    ).hexdigest()[:12]

    return f"{prefix}_{digest}"


def dot_node_id(
    path: Path,
) -> str:
    return stable_id(
        "file",
        path.as_posix(),
    )


# ============================================================================
# DOT output
# ============================================================================


def write_dot(
    files: list[DafnyFile],
    graph: Graph,
    root: Path,
    output: Path,
    metrics: dict[Path, dict],
) -> None:
    colors = {
        "foundation": "#8BC34A",
        "authority": "#42A5F5",
        "authorization": "#FF9800",
        "execution": "#EF5350",
        "account": "#FFCA28",
        "policy": "#AB47BC",
        "laws": "#78909C",
        "proofs": "#26A69A",
    }

    lines: list[str] = []

    lines.append(
        "digraph DafnyDependencies {"
    )

    lines.append(
        "    rankdir=LR;"
    )

    lines.append(
        '    graph [fontname="Helvetica", '
        'bgcolor="white", '
        'pad="0.2"];'
    )

    lines.append(
        '    node [fontname="Helvetica"];'
    )

    lines.append(
        '    edge [fontname="Helvetica"];'
    )

    lines.append("")

    node_ids: dict[
        Path,
        str,
    ] = {}

    # -----------------------------------------------------------------------
    # Nodes
    # -----------------------------------------------------------------------

    for file in files:
        relative = relative_path(
            file.path,
            root,
        )

        node_id = dot_node_id(
            relative
        )

        node_ids[
            relative
        ] = node_id

        folder = (
            relative.parts[0]
            if len(relative.parts) > 1
            else ""
        )

        color = colors.get(
            folder,
            "#BDBDBD",
        )

        metric = metrics[
            relative
        ]

        label = (
            f"{relative.as_posix()}"
        )

        if file.module:
            label += (
                f"\\nmodule {file.module}"
            )

        label += (
            f"\\nfan-out: "
            f"{metric['fan_out']}"
            f" | fan-in: "
            f"{metric['fan_in']}"
        )

        label += (
            f"\\ntransitive out: "
            f"{metric['transitive_dependency_count']}"
            f" | transitive in: "
            f"{metric['transitive_dependent_count']}"
        )

        label += (
            f"\\nlayer: "
            f"{metric['dependency_depth']}"
        )

        if metric["is_foundation"]:
            label += "\\n[FOUNDATION]"

        lines.append(
            f'    {node_id} ['
            f'label="{dot_escape(label)}", '
            f'shape=box, '
            f'style="rounded,filled", '
            f'fillcolor="{color}20", '
            f'color="{color}"'
            f'];'
        )

    lines.append("")

    # -----------------------------------------------------------------------
    # include
    # -----------------------------------------------------------------------

    for source in sort_paths(
        set(graph.include_edges.keys())
    ):
        for target in sort_paths(
            graph.include_edges[source]
        ):
            lines.append(
                f'    {node_ids[source]} -> '
                f'{node_ids[target]} '
                f'[label="include", '
                f'color="#1565C0"];'
            )

    # -----------------------------------------------------------------------
    # import opened
    # -----------------------------------------------------------------------

    for source in sort_paths(
        set(
            graph.import_opened_edges.keys()
        )
    ):
        for target in sort_paths(
            graph.import_opened_edges[source]
        ):
            lines.append(
                f'    {node_ids[source]} -> '
                f'{node_ids[target]} '
                f'[label="import opened", '
                f'color="#6A1B9A", '
                f'style=dashed];'
            )

    # -----------------------------------------------------------------------
    # normal import
    # -----------------------------------------------------------------------

    for source in sort_paths(
        set(graph.import_edges.keys())
    ):
        for target in sort_paths(
            graph.import_edges[source]
        ):
            lines.append(
                f'    {node_ids[source]} -> '
                f'{node_ids[target]} '
                f'[label="import", '
                f'color="#00897B", '
                f'style=dotted];'
            )

    # -----------------------------------------------------------------------
    # Missing includes
    # -----------------------------------------------------------------------

    for source, raw, target in sorted(
        graph.missing_includes,
        key=lambda item: (
            item[0].as_posix(),
            item[1],
        ),
    ):
        source_id = node_ids[
            source
        ]

        if target is None:
            label = (
                f"{raw}\\n"
                "[external include]"
            )

            node_key = (
                f"external:"
                f"{source.as_posix()}:"
                f"{raw}"
            )

            color = "#616161"

        else:
            label = (
                f"{target.as_posix()}"
                "\\n[MISSING FILE]"
            )

            node_key = (
                f"missing:"
                f"{target.as_posix()}"
            )

            color = "#D32F2F"

        external_id = stable_id(
            "external",
            node_key,
        )

        lines.append(
            f'    {external_id} ['
            f'label="{dot_escape(label)}", '
            f'shape=box, '
            f'style=dashed, '
            f'color="{color}"'
            f'];'
        )

        lines.append(
            f'    {source_id} -> '
            f'{external_id} '
            f'[label="include", '
            f'color="{color}"];'
        )

    # -----------------------------------------------------------------------
    # Missing modules
    # -----------------------------------------------------------------------

    for source, module in sorted(
        graph.missing_modules,
        key=lambda item: (
            item[0].as_posix(),
            item[1],
        ),
    ):
        source_id = node_ids[
            source
        ]

        missing_id = stable_id(
            "missing_module",
            module,
        )

        lines.append(
            f'    {missing_id} ['
            f'label="module '
            f'{dot_escape(module)}'
            f'\\n[MODULE NOT FOUND]", '
            f'shape=box, '
            f'style=dashed, '
            f'color="#D32F2F"'
            f'];'
        )

        lines.append(
            f'    {source_id} -> '
            f'{missing_id} '
            f'[label="module import", '
            f'color="#D32F2F", '
            f'style=dashed];'
        )

    lines.append("}")

    output.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )


# ============================================================================
# JSON serialization helpers
# ============================================================================


def serialize_path_list(
    paths: set[Path] | list[Path],
) -> list[str]:
    return [
        path.as_posix()
        for path in sort_paths(
            set(paths)
        )
    ]


def build_dependency_records(
    node: Path,
    dependencies: set[Path],
    graph: Graph,
) -> list[dict]:
    records: list[dict] = []

    for target in sort_paths(
        dependencies
    ):
        records.append(
            {
                "path": target.as_posix(),
                "edge_types": edge_kinds(
                    graph,
                    node,
                    target,
                ),
            }
        )

    return records


def build_dependent_records(
    node: Path,
    dependents: set[Path],
    graph: Graph,
) -> list[dict]:
    records: list[dict] = []

    for source in sort_paths(
        dependents
    ):
        records.append(
            {
                "path": source.as_posix(),
                "edge_types": edge_kinds(
                    graph,
                    source,
                    node,
                ),
            }
        )

    return records


# ============================================================================
# JSON output
# ============================================================================


def write_json(
    files: list[DafnyFile],
    module_index: dict[str, DafnyFile],
    graph: Graph,
    root: Path,
    output: Path,
    duplicate_module_errors: list[str],
    cycles: list[list[Path]],
    errors: list[str],
    metrics: dict[Path, dict],
    topo: list[Path] | None,
) -> None:
    """
    Build a complete machine-readable snapshot.

    The JSON intentionally contains BOTH:

        - source-level observations
        - calculated graph facts

    so consumers do not have to reconstruct the graph.
    """

    nodes = all_project_nodes(
        files,
        root,
    )

    file_set = set(nodes)

    combined = combined_edges(
        graph
    )

    reverse = reverse_edges(
        nodes,
        combined,
    )

    # -----------------------------------------------------------------------
    # Order metadata
    # -----------------------------------------------------------------------

    order_index: dict[
        Path,
        int,
    ] = {}

    if topo is not None:
        for index, path in enumerate(
            topo,
            start=1,
        ):
            order_index[path] = index

    # -----------------------------------------------------------------------
    # Files
    # -----------------------------------------------------------------------

    files_json: list[dict] = []

    for file in files:
        relative = relative_path(
            file.path,
            root,
        )

        metric = metrics[
            relative
        ]

        direct_dependencies = (
            metric["direct_dependencies"]
        )

        direct_dependents = (
            metric["direct_dependents"]
        )

        transitive_dependencies = (
            metric["transitive_dependencies"]
        )

        transitive_dependents = (
            metric["transitive_dependents"]
        )

        # ---------------------------------------------------------------
        # includes
        # ---------------------------------------------------------------

        includes_json: list[dict] = []

        for dependency in file.includes:
            kind, target = resolve_include(
                file,
                dependency.raw,
                root,
            )

            target_exists = (
                target is not None
                and target in file_set
            )

            includes_json.append(
                {
                    "raw": dependency.raw,
                    "line": dependency.line,
                    "kind": kind,
                    "target": (
                        target.as_posix()
                        if target is not None
                        else None
                    ),
                    "exists": target_exists,
                }
            )

        # ---------------------------------------------------------------
        # import opened
        # ---------------------------------------------------------------

        imports_opened_json: list[dict] = []

        include_reachable = (
            reachable_nodes(
                relative,
                graph.include_edges,
            )
        )

        for dependency in (
            file.imports_opened
        ):
            target_file = module_index.get(
                dependency.module
            )

            if target_file is None:
                imports_opened_json.append(
                    {
                        "module": dependency.module,
                        "line": dependency.line,
                        "target": None,
                        "exists": False,
                        "reachable_via_include": False,
                    }
                )

                continue

            target = relative_path(
                target_file.path,
                root,
            )

            imports_opened_json.append(
                {
                    "module": dependency.module,
                    "line": dependency.line,
                    "target": target.as_posix(),
                    "exists": True,
                    "reachable_via_include": (
                        relative == target
                        or target in include_reachable
                    ),
                }
            )

        # ---------------------------------------------------------------
        # normal import
        # ---------------------------------------------------------------

        imports_json: list[dict] = []

        for dependency in file.imports:
            target_file = module_index.get(
                dependency.module
            )

            imports_json.append(
                {
                    "module": dependency.module,
                    "line": dependency.line,
                    "target": (
                        relative_path(
                            target_file.path,
                            root,
                        ).as_posix()
                        if target_file is not None
                        else None
                    ),
                    "exists": (
                        target_file is not None
                    ),
                }
            )

        # ---------------------------------------------------------------
        # edge breakdown
        # ---------------------------------------------------------------

        direct_by_type = {
            "include": [],
            "import_opened": [],
            "import": [],
        }

        for target in sort_paths(
            graph.include_edges.get(
                relative,
                set(),
            )
        ):
            direct_by_type[
                "include"
            ].append(
                target.as_posix()
            )

        for target in sort_paths(
            graph.import_opened_edges.get(
                relative,
                set(),
            )
        ):
            direct_by_type[
                "import_opened"
            ].append(
                target.as_posix()
            )

        for target in sort_paths(
            graph.import_edges.get(
                relative,
                set(),
            )
        ):
            direct_by_type[
                "import"
            ].append(
                target.as_posix()
            )

        # ---------------------------------------------------------------
        # calculated status
        # ---------------------------------------------------------------

        if metric["is_foundation"]:
            graph_role = "foundation"

        elif metric["is_leaf"]:
            graph_role = "leaf"

        elif metric["fan_in"] > metric["fan_out"]:
            graph_role = "shared"

        else:
            graph_role = "intermediate"

        priority = calculate_refactor_priority(
            metric
        )

        files_json.append(
            {
                "path": relative.as_posix(),

                "module": file.module,

                "module_line": file.module_line,

                "source": {
                    "absolute_path": file.path.as_posix(),
                    "relative_path": relative.as_posix(),
                },

                "explicit_dependencies": {
                    "has_any": (
                        file.has_explicit_dependencies
                    ),

                    "includes": includes_json,

                    "imports_opened": (
                        imports_opened_json
                    ),

                    "imports": imports_json,
                },

                "graph": {
                    "fan_out": metric["fan_out"],
                    "fan_in": metric["fan_in"],

                    "direct_dependency_count": (
                        metric[
                            "direct_dependency_count"
                        ]
                    ),

                    "direct_dependent_count": (
                        metric[
                            "direct_dependent_count"
                        ]
                    ),

                    "transitive_dependency_count": (
                        metric[
                            "transitive_dependency_count"
                        ]
                    ),

                    "transitive_dependent_count": (
                        metric[
                            "transitive_dependent_count"
                        ]
                    ),

                    "dependency_depth": (
                        metric[
                            "dependency_depth"
                        ]
                    ),

                    "dependency_order": (
                        order_index.get(
                            relative
                        )
                    ),

                    "layer": (
                        metric[
                            "dependency_depth"
                        ]
                    ),

                    "role": graph_role,

                    "is_foundation": (
                        metric[
                            "is_foundation"
                        ]
                    ),

                    "is_leaf": (
                        metric["is_leaf"]
                    ),

                    "is_high_fan_in": (
                        metric[
                            "is_high_fan_in"
                        ]
                    ),

                    "is_high_fan_out": (
                        metric[
                            "is_high_fan_out"
                        ]
                    ),

                    "direct_dependencies": (
                        serialize_path_list(
                            direct_dependencies
                        )
                    ),

                    "direct_dependents": (
                        serialize_path_list(
                            direct_dependents
                        )
                    ),

                    "transitive_dependencies": (
                        serialize_path_list(
                            transitive_dependencies
                        )
                    ),

                    "transitive_dependents": (
                        serialize_path_list(
                            transitive_dependents
                        )
                    ),

                    "direct_dependencies_by_type": (
                        direct_by_type
                    ),

                    "dependency_records": (
                        build_dependency_records(
                            relative,
                            direct_dependencies,
                            graph,
                        )
                    ),

                    "dependent_records": (
                        build_dependent_records(
                            relative,
                            direct_dependents,
                            graph,
                        )
                    ),
                },

                "refactor": {
                    "priority": priority,

                    "recommended_start": (
                        metric[
                            "is_foundation"
                        ]
                    ),

                    "reason": (
                        "foundation"
                        if metric["is_foundation"]
                        else (
                            "high fan-in"
                            if metric["fan_in"] > 0
                            else (
                                "intermediate dependency"
                                if metric["fan_out"] > 0
                                else "isolated node"
                            )
                        )
                    ),
                },

                "validation": {
                    "parse_errors": list(
                        file.parse_errors
                    ),

                    "has_parse_errors": bool(
                        file.parse_errors
                    ),
                },
            }
        )

    # -----------------------------------------------------------------------
    # Dependency edge records
    # -----------------------------------------------------------------------

    include_edges_json = [
        {
            "source": source.as_posix(),
            "target": target.as_posix(),
            "type": "include",
        }
        for source in sort_paths(
            set(graph.include_edges.keys())
        )
        for target in sort_paths(
            graph.include_edges[source]
        )
    ]

    import_opened_edges_json = [
        {
            "source": source.as_posix(),
            "target": target.as_posix(),
            "type": "import_opened",
        }
        for source in sort_paths(
            set(
                graph.import_opened_edges.keys()
            )
        )
        for target in sort_paths(
            graph.import_opened_edges[source]
        )
    ]

    import_edges_json = [
        {
            "source": source.as_posix(),
            "target": target.as_posix(),
            "type": "import",
        }
        for source in sort_paths(
            set(graph.import_edges.keys())
        )
        for target in sort_paths(
            graph.import_edges[source]
        )
    ]

    all_edges_json = [
        {
            "source": source.as_posix(),
            "target": target.as_posix(),
            "edge_types": edge_kinds(
                graph,
                source,
                target,
            ),
        }
        for source in sort_paths(
            set(combined.keys())
        )
        for target in sort_paths(
            combined[source]
        )
    ]

    # -----------------------------------------------------------------------
    # Missing includes
    # -----------------------------------------------------------------------

    missing_includes_json = [
        {
            "source": source.as_posix(),
            "raw": raw,
            "target": (
                target.as_posix()
                if target is not None
                else None
            ),
            "external": (
                target is None
            ),
        }
        for source, raw, target in sorted(
            graph.missing_includes,
            key=lambda item: (
                item[0].as_posix(),
                item[1],
            ),
        )
    ]

    # -----------------------------------------------------------------------
    # Missing modules
    # -----------------------------------------------------------------------

    missing_modules_json = [
        {
            "source": source.as_posix(),
            "module": module,
        }
        for source, module in sorted(
            graph.missing_modules,
            key=lambda item: (
                item[0].as_posix(),
                item[1],
            ),
        )
    ]

    # -----------------------------------------------------------------------
    # Invisible imports
    # -----------------------------------------------------------------------

    invisible_imports_json = [
        {
            "source": source.as_posix(),
            "module": module,
            "target": target.as_posix(),
        }
        for source, module, target in sorted(
            graph.invisible_imports,
            key=lambda item: (
                item[0].as_posix(),
                item[1],
            ),
        )
    ]

    # -----------------------------------------------------------------------
    # Cycles
    # -----------------------------------------------------------------------

    cycles_json = [
        [
            path.as_posix()
            for path in cycle
        ]
        for cycle in cycles
    ]

    # -----------------------------------------------------------------------
    # Order
    # -----------------------------------------------------------------------

    dependency_order = (
        [
            path.as_posix()
            for path in topo
        ]
        if topo is not None
        else None
    )

    # -----------------------------------------------------------------------
    # Foundation / leaf / high fan-in lists
    # -----------------------------------------------------------------------

    foundation_nodes = sorted(
        (
            node
            for node in nodes
            if metrics[node][
                "is_foundation"
            ]
        ),
        key=path_key,
    )

    leaf_nodes = sorted(
        (
            node
            for node in nodes
            if metrics[node]["is_leaf"]
        ),
        key=path_key,
    )

    high_fan_in_nodes = sorted(
        (
            node
            for node in nodes
            if metrics[node]["fan_in"] > 0
        ),
        key=lambda node: (
            -metrics[node]["fan_in"],
            path_key(node),
        ),
    )

    high_fan_out_nodes = sorted(
        (
            node
            for node in nodes
            if metrics[node]["fan_out"] > 0
        ),
        key=lambda node: (
            -metrics[node]["fan_out"],
            path_key(node),
        ),
    )

    # -----------------------------------------------------------------------
    # Refactor order
    # -----------------------------------------------------------------------

    refactor_order = sorted(
        nodes,
        key=lambda node: (
            -calculate_refactor_priority(
                metrics[node]
            ),
            metrics[node][
                "dependency_depth"
            ]
            if metrics[node][
                "dependency_depth"
            ] >= 0
            else 999999,
            path_key(node),
        ),
    )

    # -----------------------------------------------------------------------
    # Layers
    # -----------------------------------------------------------------------

    layers: dict[
        str,
        list[str],
    ] = defaultdict(list)

    for node in nodes:
        layer = metrics[node][
            "dependency_depth"
        ]

        layers[str(layer)].append(
            node.as_posix()
        )

    for layer_nodes in layers.values():
        layer_nodes.sort()

    # -----------------------------------------------------------------------
    # Module index
    # -----------------------------------------------------------------------

    modules_json = {
        module: relative_path(
            file.path,
            root,
        ).as_posix()
        for module, file in sorted(
            module_index.items(),
            key=lambda item: item[0],
        )
    }

    # -----------------------------------------------------------------------
    # Validation
    # -----------------------------------------------------------------------

    data = {
        "schema_version": SCHEMA_VERSION,

        "analyzer": {
            "name": "Dafny Dependency Analyzer",
            "purpose": (
                "Deterministic filesystem-based dependency graph "
                "analysis for Dafny projects."
            ),
            "source_of_truth": (
                "current .dfy files on disk"
            ),
            "graph_semantics": {
                "edge_direction": (
                    "source depends on target"
                ),
                "fan_out": (
                    "number of direct dependencies"
                ),
                "fan_in": (
                    "number of direct dependents"
                ),
                "dependency_order": (
                    "dependencies appear before dependents"
                ),
            },
        },

        "project": {
            "root": root.as_posix(),
            "files_discovered": len(files),
        },

        "summary": {
            "files": len(files),
            "modules": len(module_index),

            "files_with_no_explicit_dependencies": sum(
                1
                for file in files
                if file.no_explicit_dependencies
            ),

            "foundation_files": len(
                foundation_nodes
            ),

            "leaf_files": len(
                leaf_nodes
            ),

            "include_edges": len(
                include_edges_json
            ),

            "import_opened_edges": len(
                import_opened_edges_json
            ),

            "normal_import_edges": len(
                import_edges_json
            ),

            "combined_edges": len(
                all_edges_json
            ),

            "missing_includes": len(
                missing_includes_json
            ),

            "missing_modules": len(
                missing_modules_json
            ),

            "invisible_import_opened": len(
                invisible_imports_json
            ),

            "cycles": len(
                cycles_json
            ),

            "errors": len(
                errors
            ),
        },

        "files": files_json,

        "modules": modules_json,

        "graph": {
            "edges": {
                "include": include_edges_json,
                "import_opened": (
                    import_opened_edges_json
                ),
                "import": import_edges_json,
                "combined": all_edges_json,
            },

            "reverse_edges": [
                {
                    "source": target.as_posix(),
                    "dependents": (
                        serialize_path_list(
                            reverse.get(
                                target,
                                set(),
                            )
                        )
                    ),
                }
                for target in nodes
            ],
        },

        "analysis": {
            "foundation_files": [
                node.as_posix()
                for node in foundation_nodes
            ],

            "leaf_files": [
                node.as_posix()
                for node in leaf_nodes
            ],

            "highest_fan_in": [
                {
                    "path": node.as_posix(),
                    "fan_in": metrics[node][
                        "fan_in"
                    ],
                    "fan_out": metrics[node][
                        "fan_out"
                    ],
                }
                for node in high_fan_in_nodes
            ],

            "highest_fan_out": [
                {
                    "path": node.as_posix(),
                    "fan_out": metrics[node][
                        "fan_out"
                    ],
                    "fan_in": metrics[node][
                        "fan_in"
                    ],
                }
                for node in high_fan_out_nodes
            ],

            "layers": dict(
                sorted(
                    layers.items(),
                    key=lambda item: (
                        int(item[0])
                    ),
                )
            ),

            "dependency_order": (
                dependency_order
            ),

            "refactor_order": [
                {
                    "rank": index,
                    "path": node.as_posix(),
                    "priority": (
                        calculate_refactor_priority(
                            metrics[node]
                        )
                    ),
                    "fan_in": metrics[node][
                        "fan_in"
                    ],
                    "fan_out": metrics[node][
                        "fan_out"
                    ],
                    "dependency_depth": (
                        metrics[node][
                            "dependency_depth"
                        ]
                    ),
                    "reason": (
                        "foundation"
                        if metrics[node][
                            "is_foundation"
                        ]
                        else (
                            "high fan-in"
                            if metrics[node][
                                "fan_in"
                            ] > 0
                            else (
                                "intermediate dependency"
                                if metrics[node][
                                    "fan_out"
                                ] > 0
                                else "isolated node"
                            )
                        )
                    ),
                }
                for index, node in enumerate(
                    refactor_order,
                    start=1,
                )
            ],
        },

        "missing_includes": (
            missing_includes_json
        ),

        "missing_modules": (
            missing_modules_json
        ),

        "invisible_imports": (
            invisible_imports_json
        ),

        "cycles": cycles_json,

        "validation": {
            "ok": not errors,

            "error_count": len(
                errors
            ),

            "errors": errors,

            "duplicate_module_errors": (
                duplicate_module_errors
            ),

            "files_without_module": [
                relative_string(
                    file.path,
                    root,
                )
                for file in files
                if file.module is None
            ],

            "files_with_parse_errors": [
                relative_string(
                    file.path,
                    root,
                )
                for file in files
                if file.parse_errors
            ],
        },
    }

    output.write_text(
        json.dumps(
            data,
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )


# ============================================================================
# Human-readable report
# ============================================================================


def write_report(
    files: list[DafnyFile],
    module_index: dict[str, DafnyFile],
    graph: Graph,
    root: Path,
    output: Path,
    duplicate_module_errors: list[str],
    cycles: list[list[Path]],
    errors: list[str],
    metrics: dict[Path, dict],
    topo: list[Path] | None,
) -> None:
    nodes = all_project_nodes(
        files,
        root
    )

    combined = combined_edges(
        graph
    )

    reverse = reverse_edges(
        nodes,
        combined
    )

    no_explicit = [
        file
        for file in files
        if file.no_explicit_dependencies
    ]

    files_without_module = [
        file
        for file in files
        if file.module is None
    ]

    files_with_parse_errors = [
        file
        for file in files
        if file.parse_errors
    ]

    # -----------------------------------------------------------------------
    # Report header
    # -----------------------------------------------------------------------

    lines: list[str] = []

    lines.append(
        "Dafny Dependency Report"
    )

    lines.append(
        "======================="
    )

    lines.append("")

    lines.append(
        f"Root: {root}"
    )

    lines.append(
        f"Dafny files: {len(files)}"
    )

    lines.append(
        f"Modules found: {len(module_index)}"
    )

    lines.append("")

    lines.append(
        "SOURCE OF TRUTH: current .dfy files on disk"
    )

    lines.append(
        "This report was rebuilt completely during this execution."
    )

    lines.append("")

    # -----------------------------------------------------------------------
    # Structural validation
    # -----------------------------------------------------------------------

    lines.append(
        "Structural validation"
    )

    lines.append(
        "---------------------"
    )

    if files_without_module:
        lines.append(
            "ERROR: files without module declaration"
        )

        for file in files_without_module:
            lines.append(
                f"- {relative_string(file.path, root)}"
            )

    else:
        lines.append(
            "OK: every .dfy file declares a module"
        )

    lines.append("")

    if duplicate_module_errors:
        lines.append(
            "ERROR: duplicate module declarations"
        )

        for error in duplicate_module_errors:
            lines.append(error)
            lines.append("")

    else:
        lines.append(
            "OK: module names are unique"
        )

    lines.append("")

    if files_with_parse_errors:
        lines.append(
            "ERROR: file parsing problems"
        )

        for file in files_with_parse_errors:
            lines.append(
                f"- {relative_string(file.path, root)}"
            )

            for error in file.parse_errors:
                lines.append(
                    f"    {error}"
                )

    else:
        lines.append(
            "OK: files scanned successfully"
        )

    lines.append("")

    # -----------------------------------------------------------------------
    # Graph overview
    # -----------------------------------------------------------------------

    lines.append(
        "Graph overview"
    )

    lines.append(
        "--------------"
    )

    lines.append(
        "Edge semantics: A -> B means A depends on B."
    )

    lines.append(
        "fan-out = direct dependencies."
    )

    lines.append(
        "fan-in  = direct dependents."
    )

    lines.append("")

    lines.append(
        f"Combined edges: {sum(len(v) for v in combined.values())}"
    )

    lines.append(
        f"Foundation files: "
        f"{sum(1 for node in nodes if metrics[node]['is_foundation'])}"
    )

    lines.append(
        f"Leaf files: "
        f"{sum(1 for node in nodes if metrics[node]['is_leaf'])}"
    )

    lines.append("")

    # -----------------------------------------------------------------------
    # ALL FILES — FAN OUT / FAN IN
    # -----------------------------------------------------------------------

    lines.append(
        "All Dafny files — fan-out / fan-in"
    )

    lines.append(
        "----------------------------------"
    )

    lines.append(
        "This section is the complete file-level dependency map."
    )

    lines.append(
        "Every discovered .dfy file is listed, including files with zero"
    )

    lines.append(
        "dependencies and zero dependents."
    )

    lines.append("")

    for index, file in enumerate(
        files,
        start=1,
    ):
        path = relative_path(
            file.path,
            root
        )

        metric = metrics[path]

        lines.append(
            f"{index:02d}. {path.as_posix()}"
        )

        lines.append(
            f"    module       : "
            f"{file.module or '[NO MODULE]'}"
        )

        lines.append(
            f"    fan-out      : "
            f"{metric['fan_out']}"
        )

        lines.append(
            f"    fan-in       : "
            f"{metric['fan_in']}"
        )

        lines.append(
            f"    transitive-out: "
            f"{metric['transitive_dependency_count']}"
        )

        lines.append(
            f"    transitive-in : "
            f"{metric['transitive_dependent_count']}"
        )

        lines.append(
            f"    layer        : "
            f"{metric['dependency_depth']}"
        )

        lines.append(
            f"    role         : "
            f"{'FOUNDATION' if metric['is_foundation'] else 'LEAF' if metric['is_leaf'] else 'INTERMEDIATE'}"
        )

        lines.append(
            f"    refactor score: "
            f"{calculate_refactor_priority(metric)}"
        )

        # ---------------------------------------------------------------
        # Direct dependencies
        # ---------------------------------------------------------------

        if metric[
            "direct_dependencies"
        ]:
            lines.append(
                "    depends on:"
            )

            for dependency in sort_paths(
                metric[
                    "direct_dependencies"
                ]
            ):
                kinds = edge_kinds(
                    graph,
                    path,
                    dependency,
                )

                lines.append(
                    f"      -> "
                    f"{dependency.as_posix()} "
                    f"[{', '.join(kinds)}]"
                )

        else:
            lines.append(
                "    depends on: NONE"
            )

        # ---------------------------------------------------------------
        # Direct dependents
        # ---------------------------------------------------------------

        if metric[
            "direct_dependents"
        ]:
            lines.append(
                "    depended on by:"
            )

            for dependent in sort_paths(
                metric[
                    "direct_dependents"
                ]
            ):
                kinds = edge_kinds(
                    graph,
                    dependent,
                    path,
                )

                lines.append(
                    f"      <- "
                    f"{dependent.as_posix()} "
                    f"[{', '.join(kinds)}]"
                )

        else:
            lines.append(
                "    depended on by: NONE"
            )

        lines.append("")

    # -----------------------------------------------------------------------
    # Foundation files
    # -----------------------------------------------------------------------

    foundation_files = [
        node
        for node in nodes
        if metrics[node][
            "is_foundation"
        ]
    ]

    lines.append(
        "Foundation files"
    )

    lines.append(
        "-----------------"
    )

    lines.append(
        "Files with fan-out = 0."
    )

    lines.append(
        "These are the natural starting candidates for dependency-first"
    )

    lines.append(
        "refactoring, although fan-in and semantic importance must also be"
    )

    lines.append(
        "considered."
    )

    lines.append("")

    if foundation_files:
        for node in sorted(
            foundation_files,
            key=lambda node: (
                -metrics[node]["fan_in"],
                node.as_posix(),
            ),
        ):
            lines.append(
                f"- {node.as_posix()} "
                f"(fan-in: "
                f"{metrics[node]['fan_in']})"
            )

    else:
        lines.append(
            "- none"
        )

    lines.append("")

    # -----------------------------------------------------------------------
    # Highest fan-in
    # -----------------------------------------------------------------------

    high_fan_in = sorted(
        nodes,
        key=lambda node: (
            -metrics[node]["fan_in"],
            node.as_posix(),
        ),
    )

    lines.append(
        "Highest fan-in files"
    )

    lines.append(
        "--------------------"
    )

    lines.append(
        "These files are consumed by the greatest number of other files."
    )

    lines.append("")

    for node in high_fan_in:
        if metrics[node]["fan_in"] == 0:
            continue

        lines.append(
            f"- {node.as_posix()} "
            f"fan-in={metrics[node]['fan_in']} "
            f"fan-out={metrics[node]['fan_out']}"
        )

    if all(
        metrics[node]["fan_in"] == 0
        for node in nodes
    ):
        lines.append(
            "- none"
        )

    lines.append("")

    # -----------------------------------------------------------------------
    # Dependency-first order
    # -----------------------------------------------------------------------

    lines.append(
        "Dependency-first order"
    )

    lines.append(
        "-----------------------"
    )

    lines.append(
        "A dependency appears before every file that depends on it."
    )

    lines.append("")

    if topo is None:
        lines.append(
            "UNAVAILABLE: dependency graph contains a cycle."
        )

    else:
        for index, node in enumerate(
            topo,
            start=1,
        ):
            metric = metrics[node]

            lines.append(
                f"{index:02d}. "
                f"{node.as_posix()} "
                f"(layer={metric['dependency_depth']}, "
                f"fan-in={metric['fan_in']}, "
                f"fan-out={metric['fan_out']})"
            )

    lines.append("")

    # -----------------------------------------------------------------------
    # Refactor priority
    # -----------------------------------------------------------------------

    refactor_order = sorted(
        nodes,
        key=lambda node: (
            -calculate_refactor_priority(
                metrics[node]
            ),
            node.as_posix(),
        ),
    )

    lines.append(
        "Suggested refactor priority"
    )

    lines.append(
        "---------------------------"
    )

    lines.append(
        "This is a graph-derived priority, NOT a semantic correctness score."
    )

    lines.append("")

    for index, node in enumerate(
        refactor_order,
        start=1,
    ):
        metric = metrics[node]

        lines.append(
            f"{index:02d}. "
            f"{node.as_posix()} "
            f"score={calculate_refactor_priority(metric)} "
            f"fan-in={metric['fan_in']} "
            f"fan-out={metric['fan_out']} "
            f"layer={metric['dependency_depth']}"
        )

    lines.append("")

    # -----------------------------------------------------------------------
    # Cycles
    # -----------------------------------------------------------------------

    lines.append(
        "Cycles"
    )

    lines.append(
        "------"
    )

    if cycles:
        lines.append(
            f"ERROR: {len(cycles)} cycle(s) detected."
        )

        lines.append("")

        for index, cycle in enumerate(
            cycles,
            start=1,
        ):
            lines.append(
                f"Cycle {index}:"
            )

            lines.append(
                "  "
                + " -> ".join(
                    path.as_posix()
                    for path in cycle
                )
            )

            lines.append("")

    else:
        lines.append(
            "OK: no cycles detected."
        )

    lines.append("")

    # -----------------------------------------------------------------------
    # Missing includes
    # -----------------------------------------------------------------------

    lines.append(
        "Missing / external includes"
    )

    lines.append(
        "---------------------------"
    )

    if graph.missing_includes:
        for source, raw, target in sorted(
            graph.missing_includes,
            key=lambda item: (
                item[0].as_posix(),
                item[1],
            ),
        ):
            if target is None:
                lines.append(
                    f"- {source.as_posix()}: "
                    f'include "{raw}" [EXTERNAL]'
                )

            else:
                lines.append(
                    f"- {source.as_posix()}: "
                    f'include "{raw}" -> '
                    f"{target.as_posix()} [MISSING]"
                )

    else:
        lines.append(
            "OK: all project includes resolve."
        )

    lines.append("")

    # -----------------------------------------------------------------------
    # Missing modules
    # -----------------------------------------------------------------------

    lines.append(
        "Missing modules"
    )

    lines.append(
        "---------------"
    )

    if graph.missing_modules:
        for source, module in sorted(
            graph.missing_modules,
            key=lambda item: (
                item[0].as_posix(),
                item[1],
            ),
        ):
            lines.append(
                f"- {source.as_posix()}: "
                f"module {module} [NOT FOUND]"
            )

    else:
        lines.append(
            "OK: all referenced modules exist."
        )

    lines.append("")

    # -----------------------------------------------------------------------
    # Invisible imports
    # -----------------------------------------------------------------------

    lines.append(
        "import opened visibility"
    )

    lines.append(
        "------------------------"
    )

    if graph.invisible_imports:
        lines.append(
            "WARNING: import opened references a module that is not"
        )

        lines.append(
            "reachable through the source file's include graph."
        )

        lines.append("")

        for source, module, target in sorted(
            graph.invisible_imports,
            key=lambda item: (
                item[0].as_posix(),
                item[1],
            ),
        ):
            lines.append(
                f"- {source.as_posix()}: "
                f"import opened {module}"
            )

            lines.append(
                f"    module defined by: "
                f"{target.as_posix()}"
            )

    else:
        lines.append(
            "OK: no invisible import opened dependencies."
        )

    lines.append("")

    # -----------------------------------------------------------------------
    # Module index
    # -----------------------------------------------------------------------

    lines.append(
        "Module index"
    )

    lines.append(
        "------------"
    )

    for module, file in sorted(
        module_index.items(),
        key=lambda item: item[0],
    ):
        lines.append(
            f"- {module} -> "
            f"{relative_string(file.path, root)}"
        )

    lines.append("")

    # -----------------------------------------------------------------------
    # Summary
    # -----------------------------------------------------------------------

    lines.append(
        "Summary"
    )

    lines.append(
        "-------"
    )

    lines.append(
        f"- files: {len(files)}"
    )

    lines.append(
        f"- modules: {len(module_index)}"
    )

    lines.append(
        f"- no explicit dependencies: "
        f"{len(no_explicit)}"
    )

    lines.append(
        f"- include edges: "
        f"{sum(len(v) for v in graph.include_edges.values())}"
    )

    lines.append(
        f"- import opened edges: "
        f"{sum(len(v) for v in graph.import_opened_edges.values())}"
    )

    lines.append(
        f"- normal import edges: "
        f"{sum(len(v) for v in graph.import_edges.values())}"
    )

    lines.append(
        f"- combined edges: "
        f"{sum(len(v) for v in combined.values())}"
    )

    lines.append(
        f"- missing includes: "
        f"{len(graph.missing_includes)}"
    )

    lines.append(
        f"- missing modules: "
        f"{len(graph.missing_modules)}"
    )

    lines.append(
        f"- invisible import opened: "
        f"{len(graph.invisible_imports)}"
    )

    lines.append(
        f"- cycles: {len(cycles)}"
    )

    lines.append(
        f"- errors: {len(errors)}"
    )

    output.write_text(
        "\n".join(lines) + "\n",
        encoding="utf-8",
    )


# ============================================================================
# Validation
# ============================================================================


def validation_errors(
    files: list[DafnyFile],
    graph: Graph,
    duplicate_module_errors: list[str],
) -> list[str]:
    errors: list[str] = []

    errors.extend(
        duplicate_module_errors
    )

    for file in files:
        if file.module is None:
            errors.append(
                f"{file.path}: "
                "missing module declaration"
            )

        for error in file.parse_errors:
            errors.append(
                f"{file.path}: {error}"
            )

    for source, raw, target in (
        graph.missing_includes
    ):
        if target is not None:
            errors.append(
                f"{source}: include "
                f'"{raw}" -> {target} [MISSING]'
            )

    for source, module in (
        graph.missing_modules
    ):
        errors.append(
            f"{source}: module "
            f"{module} [NOT FOUND]"
        )

    return errors


# ============================================================================
# Console output
# ============================================================================


def print_console_summary(
    files: list[DafnyFile],
    module_index: dict[str, DafnyFile],
    graph: Graph,
    root: Path,
    dot_path: Path,
    report_path: Path,
    json_path: Path,
    errors: list[str],
    cycles: list[list[Path]],
    metrics: dict[Path, dict],
    topo: list[Path] | None,
) -> None:
    nodes = all_project_nodes(
        files,
        root,
    )

    combined = combined_edges(
        graph
    )

    print()
    print(
        "Dafny Dependency Analyzer"
    )

    print(
        "========================="
    )

    print(
        f"Root        : {root}"
    )

    print(
        f"Dafny files : {len(files)}"
    )

    print(
        f"Modules     : {len(module_index)}"
    )

    print(
        f"No explicit : "
        f"{sum(1 for file in files if file.no_explicit_dependencies)}"
    )

    print(
        f"Include     : "
        f"{sum(len(v) for v in graph.include_edges.values())}"
    )

    print(
        f"Import open : "
        f"{sum(len(v) for v in graph.import_opened_edges.values())}"
    )

    print(
        f"Import      : "
        f"{sum(len(v) for v in graph.import_edges.values())}"
    )

    print(
        f"Combined    : "
        f"{sum(len(v) for v in combined.values())}"
    )

    print(
        f"Cycles      : {len(cycles)}"
    )

    print(
        f"Errors      : {len(errors)}"
    )

    print(
        f"DOT         : {dot_path}"
    )

    print(
        f"Report      : {report_path}"
    )

    print(
        f"JSON        : {json_path}"
    )

    # ======================================================================
    # FAN-IN / FAN-OUT
    # ======================================================================

    print()
    print(
        "Dependency fan-in / fan-out"
    )

    print(
        "==========================="
    )

    print(
        "A -> B means A depends on B."
    )

    print(
        "fan-out = dependencies | fan-in = dependents"
    )

    print()

    for index, node in enumerate(
        nodes,
        start=1,
    ):
        metric = metrics[
            node
        ]

        print(
            f"{index:02d}. {node.as_posix()}"
        )

        print(
            f"    fan-out : "
            f"{metric['fan_out']}"
        )

        print(
            f"    fan-in  : "
            f"{metric['fan_in']}"
        )

        print(
            f"    transitive-out : "
            f"{metric['transitive_dependency_count']}"
        )

        print(
            f"    transitive-in  : "
            f"{metric['transitive_dependent_count']}"
        )

        print(
            f"    layer   : "
            f"{metric['dependency_depth']}"
        )

        print(
            f"    role    : "
            f"{'FOUNDATION' if metric['is_foundation'] else 'LEAF' if metric['is_leaf'] else 'INTERMEDIATE'}"
        )

        if metric[
            "direct_dependencies"
        ]:
            print(
                "    depends on:"
            )

            for dependency in sort_paths(
                metric[
                    "direct_dependencies"
                ]
            ):
                kinds = edge_kinds(
                    graph,
                    node,
                    dependency,
                )

                print(
                    f"      -> "
                    f"{dependency.as_posix()} "
                    f"[{', '.join(kinds)}]"
                )

        else:
            print(
                "    depends on: NONE"
            )

        if metric[
            "direct_dependents"
        ]:
            print(
                "    depended on by:"
            )

            for dependent in sort_paths(
                metric[
                    "direct_dependents"
                ]
            ):
                kinds = edge_kinds(
                    graph,
                    dependent,
                    node,
                )

                print(
                    f"      <- "
                    f"{dependent.as_posix()} "
                    f"[{', '.join(kinds)}]"
                )

        else:
            print(
                "    depended on by: NONE"
            )

        print()

    # ======================================================================
    # Dependency order
    # ======================================================================

    print(
        "Dependency-first order"
    )

    print(
        "======================"
    )

    if topo is None:
        print(
            "UNAVAILABLE: cycles detected."
        )

    else:
        for index, node in enumerate(
            topo,
            start=1,
        ):
            metric = metrics[node]

            print(
                f"{index:02d}. "
                f"{node.as_posix()} "
                f"(layer={metric['dependency_depth']})"
            )

    print()


# ============================================================================
# CLI
# ============================================================================


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Build a deterministic, machine-readable dependency "
            "snapshot for the CURRENT Dafny project."
        )
    )

    parser.add_argument(
        "root",
        nargs="?",
        default=".",
        help=(
            "Dafny project root. Every *.dfy currently present "
            "under this directory is discovered automatically."
        ),
    )

    parser.add_argument(
        "--dot",
        default="dependencies.dot",
        help=(
            "Output DOT file "
            "(default: dependencies.dot)"
        ),
    )

    parser.add_argument(
        "--report",
        default="dependency-report.txt",
        help=(
            "Output text report "
            "(default: dependency-report.txt)"
        ),
    )

    parser.add_argument(
        "--strict",
        action="store_true",
        help=(
            "Exit with code 1 when structural dependency "
            "errors are detected."
        ),
    )

    args = parser.parse_args()

    root = Path(
        args.root
    ).resolve()

    if not root.is_dir():
        print(
            f"error: project root does not exist: {root}",
            file=sys.stderr,
        )

        return 1

    # ======================================================================
    # SOURCE OF TRUTH
    # ======================================================================

    files = scan_project(
        root
    )

    if not files:
        print(
            f"error: no .dfy files found under {root}",
            file=sys.stderr,
        )

        return 1

    # ======================================================================
    # Module index
    # ======================================================================

    (
        module_index,
        duplicate_module_errors,
    ) = build_module_index(
        files
    )

    # ======================================================================
    # Graph
    # ======================================================================

    graph = build_graph(
        files,
        module_index,
        root,
    )

    # ======================================================================
    # Nodes
    # ======================================================================

    nodes = all_project_nodes(
        files,
        root,
    )

    # ======================================================================
    # Combined graph
    # ======================================================================

    combined = combined_edges(
        graph
    )

    # ======================================================================
    # Cycles
    # ======================================================================

    cycles = find_cycles(
        combined
    )

    # ======================================================================
    # Topological order
    # ======================================================================

    topo = topological_order(
        nodes,
        combined,
    )

    # ======================================================================
    # Per-file metrics
    # ======================================================================

    metrics = compute_metrics(
        nodes,
        graph,
    )

    # ======================================================================
    # Validation
    # ======================================================================

    errors = validation_errors(
        files,
        graph,
        duplicate_module_errors,
    )

    # ======================================================================
    # Generated paths
    # ======================================================================

    dot_path = (
        root / args.dot
    )

    report_path = (
        root / args.report
    )

    json_path = (
        root / "dependencies.json"
    )

    # ======================================================================
    # Write DOT
    # ======================================================================

    write_dot(
        files,
        graph,
        root,
        dot_path,
        metrics,
    )

    # ======================================================================
    # Write report
    # ======================================================================

    write_report(
        files,
        module_index,
        graph,
        root,
        report_path,
        duplicate_module_errors,
        cycles,
        errors,
        metrics,
        topo,
    )

    # ======================================================================
    # Write JSON
    # ======================================================================

    write_json(
        files,
        module_index,
        graph,
        root,
        json_path,
        duplicate_module_errors,
        cycles,
        errors,
        metrics,
        topo,
    )

    # ======================================================================
    # Console
    # ======================================================================

    print_console_summary(
        files,
        module_index,
        graph,
        root,
        dot_path,
        report_path,
        json_path,
        errors,
        cycles,
        metrics,
        topo,
    )

    # ======================================================================
    # Validation errors
    # ======================================================================

    if errors:
        print(
            "Validation errors:",
            file=sys.stderr,
        )

        for error in errors:
            print(
                f"  - {error}",
                file=sys.stderr,
            )

    # ======================================================================
    # Strict mode
    # ======================================================================

    if args.strict and errors:
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main()
    )
