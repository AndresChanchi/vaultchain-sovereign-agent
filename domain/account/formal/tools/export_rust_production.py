#!/usr/bin/env python3

"""
Kipio Account — Production Dafny → Rust export.

Sibling of tools/export_rust.py. This file is dedicated to the
production pipeline (Option B: external crate + generated crate).
The experimental file tools/export_rust.py is kept for reference
and for future Dafny-version experiments.

Modes
-----

    --plan          show dependency-aware export order and stop
    --diagnose      per-file diagnostic translation, discard output
    --extern-lab    reduced extern lab (control + 3 winners)
    (default)       production export:
                        - copy .dfy to generated/dfy-annotated/
                        - inject composition .dfy from tools/dafny_inject/
                        - annotate the 5 abstract types with {:extern}
                        - obtain dafny_runtime once
                        - synthesize a single aggregator .dfy that
                          includes every runtime source plus every
                          injected composition
                        - translate ONLY the aggregator in one pass
                        - inject the 5 extern Rust types into their
                          modules
                        - generate src/lib.rs
                        - copy tools/generated_crate/ template
                        - cargo check --offline on the assembled crate
"""

from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import dependency_graph


# ============================================================================
# Domain layout
# ============================================================================

RUNTIME_LAYERS = (
    "foundation",
    "authority",
    "account",
    "authorization",
    "execution",
    "policy",
)

VERIFICATION_ONLY_LAYERS = (
    "laws",
    "proofs",
)

ALL_LAYERS = (
    *RUNTIME_LAYERS,
    *VERIFICATION_ONLY_LAYERS,
)

LAYER_PRIORITY = {
    layer: index
    for index, layer in enumerate(RUNTIME_LAYERS)
}

EXPECTED_DAFNY_VERSION = "4.11.0"

TRANSLATION_ENTRYPOINT_NAME = "__translate_entrypoint.dfy"


# ============================================================================
# Extern metadata
# ============================================================================

EXTERN_ANNOTATIONS = (
    (Path("foundation/Chain.dfy"), "Chain", "{:extern}"),
    (Path("foundation/DomainAction.dfy"), "DomainAction", "{:extern}"),
    (Path("foundation/ExecutionTarget.dfy"), "ExecutionTarget", "{:extern}"),
    (
        Path("execution/ExecutionConstraints.dfy"),
        "ExecutionConstraints",
        "{:extern}",
    ),
    (
        Path("execution/ExecutionSemantics.dfy"),
        "ExecutionEnvironment",
        "{:extern}",
    ),
)

EXTERN_MODULE_TYPE_MAP = (
    ("KipioAccountChain", "Chain"),
    ("KipioAccountDomainAction", "DomainAction"),
    ("KipioAccountExecutionTarget", "ExecutionTarget"),
    ("KipioAccountExecutionConstraints", "ExecutionConstraints"),
    ("KipioAccountExecutionSemantics", "ExecutionEnvironment"),
)


# ============================================================================
# Result model
# ============================================================================

@dataclass(frozen=True)
class TranslationResult:
    source: Path
    status: str

    output_root: Path | None = None
    generated_files: tuple[Path, ...] = ()

    stdout: str = ""
    stderr: str = ""

    detail: str = ""


@dataclass(frozen=True)
class ProductionStep:
    source: Path
    status: str
    target: Path | None = None
    detail: str = ""


@dataclass(frozen=True)
class ExternLabResult:
    candidate_id: str
    attribute: str

    verify_status: str
    translate_status: str

    generated_files: tuple[Path, ...] = ()

    verify_stdout: str = ""
    verify_stderr: str = ""

    translate_stdout: str = ""
    translate_stderr: str = ""

    detail: str = ""

    original_declaration: str = ""
    transformed_declaration: str | None = None
    original_sha256: str = ""
    transformed_sha256: str = ""

    generated_inspection: object | None = None
    standard_rustc: object | None = None
    standard_cargo: object | None = None

    include_runtime_cargo: object | None = None

    harness_cargo: object | None = None
    harness_source: str = ""

    uncompilable_translation_status: str = "NOT_RUN"
    uncompilable_stdout: str = ""
    uncompilable_stderr: str = ""
    uncompilable_inspection: object | None = None
    uncompilable_rustc: object | None = None

    include_runtime_translation_status: str = "NOT_RUN"
    include_runtime_stdout: str = ""
    include_runtime_stderr: str = ""
    include_runtime_inspection: object | None = None
    include_runtime_rustc: object | None = None

    consumer_source: str = ""


@dataclass(frozen=True)
class RustCompileResult:
    status: str
    command: tuple[str, ...] = ()
    stdout: str = ""
    stderr: str = ""
    detail: str = ""
    failure_class: str = ""


@dataclass(frozen=True)
class GeneratedInspection:
    files: tuple[Path, ...] = ()
    file_sizes: tuple[tuple[Path, int], ...] = ()
    sha256: tuple[tuple[Path, str], ...] = ()
    references: tuple[str, ...] = ()
    contents: str = ""


# ============================================================================
# Process helpers
# ============================================================================

def run(
    command: list[str],
    *,
    cwd: Path,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    print("$", " ".join(command))
    return subprocess.run(
        command,
        cwd=cwd,
        text=True,
        capture_output=capture,
        check=False,
    )


def run_captured(
    command: list[str],
    *,
    cwd: Path,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )


def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        raise RuntimeError(
            f"required tool '{name}' was not found in PATH"
        )


# ============================================================================
# Dafny environment
# ============================================================================

def dafny_version() -> str:
    result = run(
        ["dafny", "--version"],
        cwd=Path.cwd(),
        capture=True,
    )
    if result.returncode != 0:
        raise RuntimeError("unable to determine Dafny version")
    version = result.stdout.strip() or result.stderr.strip()
    if not version:
        raise RuntimeError("Dafny version command returned no version")
    return version


def dafny_base_version(version: str) -> str:
    match = re.search(r"\d+\.\d+\.\d+", version)
    if not match:
        raise RuntimeError(f"unable to parse Dafny version: {version}")
    return match.group(0)


def rust_backend_available() -> bool:
    result = run(
        ["dafny", "translate", "--help"],
        cwd=Path.cwd(),
        capture=True,
    )
    help_text = result.stdout + "\n" + result.stderr
    return bool(
        re.search(
            r"(?m)^\s*rs\s+<file>\s+Translate Dafny sources to Rust",
            help_text,
            re.IGNORECASE,
        )
    )


def check_dafny_environment() -> str:
    print()
    print("== Dafny environment ==")
    print()

    version = dafny_version()
    print(f"Dafny version: {version}")

    base_version = dafny_base_version(version)
    if base_version != EXPECTED_DAFNY_VERSION:
        print(
            "WARNING: exporter was developed against "
            f"Dafny {EXPECTED_DAFNY_VERSION}."
        )
        print(f"         Detected base version: {base_version}")
        print("         Backend output may differ.")

    if not rust_backend_available():
        raise RuntimeError(
            "Dafny Rust backend is not available. "
            "Expected `dafny translate rs <file>`."
        )

    print("Rust backend: available")
    print("Rust translation: --enforce-determinism enabled")
    return version


# ============================================================================
# Source discovery
# ============================================================================

def discover_layer_sources(
    formal_root: Path,
    layer: str,
) -> list[Path]:
    layer_root = formal_root / layer
    if not layer_root.is_dir():
        raise RuntimeError(
            f"configured layer does not exist: {layer_root}"
        )
    return sorted(
        (
            path.resolve()
            for path in layer_root.rglob("*.dfy")
            if path.is_file()
        ),
        key=lambda path: path.relative_to(formal_root).as_posix(),
    )


def discover_runtime_sources(formal_root: Path) -> list[Path]:
    sources: list[Path] = []
    for layer in RUNTIME_LAYERS:
        sources.extend(discover_layer_sources(formal_root, layer))
    return sources


def discover_all_sources(formal_root: Path) -> list[Path]:
    sources: list[Path] = []
    for layer in ALL_LAYERS:
        layer_root = formal_root / layer
        if not layer_root.is_dir():
            continue
        sources.extend(
            sorted(
                (
                    path.resolve()
                    for path in layer_root.rglob("*.dfy")
                    if path.is_file()
                ),
                key=lambda path: path.relative_to(formal_root).as_posix(),
            )
        )
    return sources


def discover_inject_sources(tools_root: Path) -> list[Path]:
    """
    Return all .dfy files under tools/dafny_inject/, sorted for
    reproducibility.
    """
    inject_root = tools_root / "dafny_inject"
    if not inject_root.is_dir():
        return []
    return sorted(
        (
            path
            for path in inject_root.rglob("*.dfy")
            if path.is_file()
        ),
        key=lambda path: path.relative_to(inject_root).as_posix(),
    )


# ============================================================================
# Layer classification
# ============================================================================

def source_layer(source: Path, formal_root: Path) -> str:
    source = source.resolve()
    formal_root = formal_root.resolve()
    relative = source.relative_to(formal_root)
    if not relative.parts:
        raise RuntimeError(f"source has no layer: {source}")
    layer = relative.parts[0]
    if layer not in ALL_LAYERS:
        raise RuntimeError(
            f"source belongs to unknown layer '{layer}': {relative}"
        )
    return layer


def classify_sources(
    sources: list[Path],
    formal_root: Path,
) -> dict[str, list[Path]]:
    classified: dict[str, list[Path]] = {layer: [] for layer in ALL_LAYERS}
    for source in sources:
        classified[source_layer(source, formal_root)].append(source)
    for layer_sources in classified.values():
        layer_sources.sort(
            key=lambda path: path.relative_to(formal_root).as_posix()
        )
    return classified


# ============================================================================
# Path helpers
# ============================================================================

def _extract_source_path(f) -> Path | None:
    if isinstance(f, (str, Path)):
        return Path(f)

    for attr in (
        "path",
        "source_path",
        "file_path",
        "filepath",
        "filename",
        "name",
        "file",
    ):
        value = getattr(f, attr, None)
        if value is None:
            continue
        try:
            return Path(value)
        except TypeError:
            continue

    d = getattr(f, "__dict__", None)
    if isinstance(d, dict):
        for key, value in d.items():
            if key.startswith("_"):
                continue
            try:
                candidate = Path(value)
            except TypeError:
                continue
            if candidate.suffix == ".dfy":
                return candidate

    return None


_DEBUG_PATH_EXTRACTION_LOGGED = False


def _is_domain_source(f, formal_root: Path) -> bool:
    global _DEBUG_PATH_EXTRACTION_LOGGED

    p = _extract_source_path(f)
    if p is None:
        if not _DEBUG_PATH_EXTRACTION_LOGGED:
            _DEBUG_PATH_EXTRACTION_LOGGED = True
            print(
                "DEBUG: cannot extract path from dependency_graph "
                f"object. type={type(f).__name__} "
                f"repr={f!r} "
                f"dict={getattr(f, '__dict__', None)}",
                file=sys.stderr,
            )
        return False

    try:
        rel = p.resolve().relative_to(formal_root.resolve())
    except (ValueError, OSError):
        return False

    if not rel.parts:
        return False
    return rel.parts[0] in ALL_LAYERS


# ============================================================================
# Dependency analysis
# ============================================================================

def analyze_dependencies(formal_root: Path):
    raw_files = dependency_graph.scan_project(formal_root)

    files = [
        f for f in raw_files
        if _is_domain_source(f, formal_root)
    ]

    if not files:
        raise RuntimeError("no Dafny source files found")

    (
        module_index,
        duplicate_module_errors,
    ) = dependency_graph.build_module_index(files)

    graph = dependency_graph.build_graph(files, module_index, formal_root)
    nodes = dependency_graph.all_project_nodes(files, formal_root)
    combined = dependency_graph.combined_edges(graph)
    cycles = dependency_graph.find_cycles(combined)
    topo = dependency_graph.topological_order(nodes, combined)

    return (
        files,
        module_index,
        graph,
        nodes,
        combined,
        cycles,
        topo,
        duplicate_module_errors,
    )


# ============================================================================
# Dependency-aware export order
# ============================================================================

def export_node_sort_key(node: Path, formal_root: Path) -> tuple[int, str]:
    layer = source_layer(formal_root / node, formal_root)
    return (
        LAYER_PRIORITY.get(layer, len(LAYER_PRIORITY)),
        node.as_posix(),
    )


def sort_export_ready_nodes(ready: list[Path], formal_root: Path) -> None:
    ready.sort(key=lambda node: export_node_sort_key(node, formal_root))


def dependency_first_runtime_order(
    formal_root: Path,
    runtime_sources: list[Path],
):
    (
        _files,
        _module_index,
        graph,
        nodes,
        combined,
        cycles,
        _topo,
        duplicate_module_errors,
    ) = analyze_dependencies(formal_root)

    nodes = [
        node
        for node in nodes
        if node.parts and node.parts[0] in ALL_LAYERS
    ]

    errors: list[str] = []
    errors.extend(duplicate_module_errors)

    if cycles:
        errors.append("dependency graph contains cycle(s)")
        for cycle in cycles:
            errors.append(
                "cycle: "
                + " -> ".join(path.as_posix() for path in cycle)
            )

    runtime_set = {source.resolve() for source in runtime_sources}
    graph_nodes = {(formal_root / node).resolve() for node in nodes}

    missing_from_graph = runtime_set - graph_nodes
    for source in sorted(
        missing_from_graph,
        key=lambda path: path.relative_to(formal_root).as_posix(),
    ):
        errors.append(
            "runtime source missing from dependency graph: "
            f"{source.relative_to(formal_root)}"
        )

    verification_set = {
        (formal_root / path).resolve()
        for path in nodes
        if source_layer(formal_root / path, formal_root)
        in VERIFICATION_ONLY_LAYERS
    }

    runtime_nodes = [
        node
        for node in nodes
        if (formal_root / node).resolve() in runtime_set
    ]
    runtime_node_set = set(runtime_nodes)

    runtime_dependencies: dict[Path, set[Path]] = {
        node: {
            dependency
            for dependency in combined.get(node, set())
            if dependency in runtime_node_set
        }
        for node in runtime_nodes
    }

    runtime_dependents = dependency_graph.reverse_edges(
        runtime_nodes,
        runtime_dependencies,
    )

    indegree = {node: len(runtime_dependencies[node]) for node in runtime_nodes}
    ready = [node for node in runtime_nodes if indegree[node] == 0]
    sort_export_ready_nodes(ready, formal_root)

    ordered_runtime_relative: list[Path] = []
    while ready:
        node = ready.pop(0)
        ordered_runtime_relative.append(node)
        for dependent in runtime_dependents.get(node, set()):
            indegree[dependent] -= 1
            if indegree[dependent] == 0:
                ready.append(dependent)
        sort_export_ready_nodes(ready, formal_root)

    if len(ordered_runtime_relative) != len(runtime_nodes):
        errors.append(
            "runtime dependency graph could not be topologically ordered"
        )
        return [], errors, graph

    ordered_runtime = [
        (formal_root / node).resolve() for node in ordered_runtime_relative
    ]

    ordered_set = set(ordered_runtime)
    missing = runtime_set - ordered_set
    for source in sorted(
        missing,
        key=lambda path: path.relative_to(formal_root).as_posix(),
    ):
        errors.append(
            "runtime source missing from export order: "
            f"{source.relative_to(formal_root)}"
        )

    for source in runtime_sources:
        relative = source.relative_to(formal_root)
        transitive = dependency_graph.reachable_nodes(relative, combined)
        forbidden = [
            path
            for path in transitive
            if (formal_root / path).resolve() in verification_set
        ]
        if forbidden:
            errors.append(
                "runtime source depends on verification-only layer: "
                f"{relative}"
            )
            for path in sorted(forbidden, key=lambda item: item.as_posix()):
                errors.append(f"  -> {path.as_posix()}")

    return ordered_runtime, errors, graph


# ============================================================================
# Formal verification
# ============================================================================

def verify_domain(formal_root: Path) -> None:
    sources = discover_all_sources(formal_root)
    if not sources:
        raise RuntimeError("no Dafny source files found")

    print()
    print("== Formal verification ==")
    print()

    command = [
        "dafny",
        "verify",
        *(
            str(path.relative_to(formal_root))
            for path in sources
        ),
    ]

    result = run(command, cwd=formal_root)
    if result.returncode != 0:
        raise RuntimeError(
            "formal verification failed; "
            "Rust export was aborted"
        )


# ============================================================================
# Generic output helpers
# ============================================================================

def clean_directory(path: Path) -> None:
    if path.exists():
        print(f"Cleaning: {path}")
        shutil.rmtree(path)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def collect_generated_files(root: Path) -> tuple[Path, ...]:
    if not root.exists():
        return ()
    return tuple(
        sorted(
            (
                path.relative_to(root)
                for path in root.rglob("*")
                if path.is_file()
            ),
            key=lambda path: path.as_posix(),
        )
    )


# ============================================================================
# Dafny abstract type helpers
# ============================================================================

def replace_abstract_type_for_extern(
    source_text: str,
    *,
    type_name: str,
    extern_attribute: str,
) -> tuple[str, int]:
    escaped_name = re.escape(type_name)
    pattern = re.compile(
        rf"(?m)^(?P<indentation>\s*)type\s+{escaped_name}"
        rf"(?P<characteristics>\([^)]*\))?"
        rf"(?P<suffix>\s*)$"
    )
    matches = list(pattern.finditer(source_text))
    if len(matches) != 1:
        return source_text, len(matches)

    match = matches[0]
    if not extern_attribute:
        return source_text, 1

    indentation = match.group("indentation")
    characteristics = match.group("characteristics") or ""

    replacement = (
        f"{indentation}"
        f"type {extern_attribute} "
        f"{type_name}"
        f"{characteristics}"
    )

    transformed = (
        source_text[: match.start()]
        + replacement
        + source_text[match.end():]
    )
    return transformed, 1


def find_single_type_declaration(
    source_text: str,
    type_name: str,
) -> str | None:
    escaped_name = re.escape(type_name)
    pattern = re.compile(
        rf"(?m)^\s*type\s+{escaped_name}"
        rf"(?:\([^)]*\))?"
        rf"\s*$"
    )
    match = pattern.search(source_text)
    return match.group(0) if match else None


# ============================================================================
# Rust source post-processing
# ============================================================================

def clean_generated_rust(text: str) -> str:
    text = re.sub(r"^#!\[.*\]\s*\n", "", text, flags=re.MULTILINE)
    text = re.sub(r"\n\n\n+", "\n\n", text)
    return text


def fix_dafny_fn_return_types(text: str) -> tuple[str, int]:
    pattern = re.compile(
        r'Rc::new\s*\(\s*move\s*\|\|\s*->\s*'
        r'(?P<rtype>[\w:<>,\s\[\]\(\)]+?)\s*'
        r'\{(?P<body>.*?)\}\s*\)\s*'
        r'as\s+Rc\s*<\s*dyn\s+::std::ops::Fn\(\)\s*->\s*_\s*>',
        re.DOTALL,
    )

    def replace(match: re.Match) -> str:
        rtype = match.group("rtype").strip()
        body = match.group("body")
        return (
            f"Rc::new(move || -> {rtype} "
            f"{{{body}}}) "
            f"as Rc<dyn ::std::ops::Fn() -> {rtype}>"
        )

    new_text, count = pattern.subn(replace, text)
    return new_text, count


# ============================================================================
# Production export
# ============================================================================

def copy_runtime_dfy_tree(
    *,
    formal_root: Path,
    annotated_root: Path,
) -> None:
    for layer in RUNTIME_LAYERS:
        layer_root = formal_root / layer
        if not layer_root.is_dir():
            continue
        for src_file in layer_root.rglob("*.dfy"):
            rel = src_file.relative_to(formal_root)
            dst = annotated_root / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src_file, dst)


def inject_dafny_files(
    *,
    tools_root: Path,
    annotated_root: Path,
) -> None:
    """
    Copy every .dfy under tools/dafny_inject/ into the annotated tree,
    preserving the layer-relative layout.

    These files express Phase 2 compositions (functions that combine
    existing runtime predicates into end-to-end decisions). They are
    not part of the formal source tree; they are derived pipeline
    artifacts that only the annotated tree sees.
    """
    inject_root = tools_root / "dafny_inject"
    if not inject_root.is_dir():
        return
    for src_file in discover_inject_sources(tools_root):
        rel = src_file.relative_to(inject_root)
        dst = annotated_root / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src_file, dst)
        print(f"Injected: {rel.as_posix()}")


def annotate_externs_in_tree(annotated_root: Path) -> list[str]:
    errors: list[str] = []
    for rel_path, type_name, extern_attr in EXTERN_ANNOTATIONS:
        target = annotated_root / rel_path
        if not target.is_file():
            errors.append(f"missing annotated file: {rel_path}")
            continue

        original = target.read_text(encoding="utf-8")
        transformed, count = replace_abstract_type_for_extern(
            original,
            type_name=type_name,
            extern_attribute=extern_attr,
        )
        if count != 1:
            errors.append(
                f"{rel_path}: expected exactly one declaration of "
                f"{type_name}, found {count}"
            )
            continue
        target.write_text(transformed, encoding="utf-8")
    return errors


def obtain_dafny_runtime(
    *,
    annotated_root: Path,
    anchor_source: Path,
    scratch: Path,
) -> Path:
    anchor_output = scratch / f"{anchor_source.stem}.rs"

    result = run_captured(
        [
            "dafny",
            "translate",
            "rs",
            str(anchor_source),
            "--output",
            str(anchor_output),
            "--enforce-determinism",
            "--include-runtime",
        ],
        cwd=annotated_root,
    )

    if result.returncode != 0:
        raise RuntimeError(
            "failed to obtain dafny_runtime via --include-runtime:\n"
            + result.stderr.strip()
        )

    runtime_root = scratch / f"{anchor_source.stem}-rust" / "runtime"

    if not runtime_root.is_dir():
        raise RuntimeError(
            f"dafny_runtime package not found at {runtime_root}"
        )

    return runtime_root


def write_translation_entrypoint(
    *,
    annotated_root: Path,
    runtime_relative_paths: list[Path],
    injected_relative_paths: list[Path],
) -> Path:
    """
    Synthesize a single .dfy entrypoint that includes every runtime
    source and every injected composition.

    Why: Dafny rejects a file that is both passed on the command
    line and pulled in transitively via `include`. Inject files DO
    include runtime files, so passing both sets explicitly triggers
    that rejection. A single aggregator sidesteps the problem: only
    one file is top-level; everything else is included exactly once
    (Dafny dedups includes by canonical path).
    """
    entrypoint_relative = Path(TRANSLATION_ENTRYPOINT_NAME)
    entrypoint_path = annotated_root / entrypoint_relative

    lines: list[str] = [
        "// Auto-generated translation entrypoint.",
        "//",
        "// Includes every runtime source plus every injected",
        "// composition. This is the only top-level .dfy passed to",
        "// `dafny translate`.",
        "",
    ]
    for rel in runtime_relative_paths:
        lines.append(f'include "{rel.as_posix()}"')
    for rel in injected_relative_paths:
        lines.append(f'include "{rel.as_posix()}"')
    lines.append("")

    entrypoint_path.write_text("\n".join(lines), encoding="utf-8")
    return entrypoint_relative


def translate_all_sources_from_annotated_tree(
    *,
    source_relative_paths: list[Path],
    annotated_root: Path,
    staging_dir: Path,
) -> Path | None:
    """
    Translate the synthesized aggregator in one Dafny invocation.

    Dafny treats the inputs as a single program and emits one
    coherent .rs file, with each Dafny module declared exactly
    once.

    --enforce-determinism is retained: Dafny's Rust backend requires
    it, and the inject files no longer contain `:|` without a
    provably-unique witness (the iteration order is defined by the
    canonical minimum over the entity Ids).
    """
    staging_dir.mkdir(parents=True, exist_ok=True)
    output_stem = "kipio_account_all"
    output_file = staging_dir / f"{output_stem}.rs"

    cmd = [
        "dafny",
        "translate",
        "rs",
        *[str(p) for p in source_relative_paths],
        "--output",
        str(output_file),
        "--enforce-determinism",
    ]

    result = run_captured(cmd, cwd=annotated_root)

    if result.returncode != 0:
        print("  FAILED", file=sys.stderr)
        if result.stdout.strip():
            print("  --- stdout ---", file=sys.stderr)
            for line in result.stdout.strip().splitlines():
                print(f"    {line}", file=sys.stderr)
        if result.stderr.strip():
            print("  --- stderr ---", file=sys.stderr)
            for line in result.stderr.strip().splitlines():
                print(f"    {line}", file=sys.stderr)
        return None

    preferred = (
        staging_dir
        / f"{output_stem}-rust"
        / "src"
        / f"{output_stem}.rs"
    )
    if preferred.is_file():
        return preferred

    candidates = list(staging_dir.rglob("*.rs"))
    if not candidates:
        print("  NO OUTPUT", file=sys.stderr)
        return None
    return max(candidates, key=lambda p: p.stat().st_size)


def inject_extern_type_into_module(
    text: str,
    *,
    module_name: str,
    type_name: str,
) -> tuple[str, bool]:
    pattern = re.compile(
        rf"pub\s+mod\s+{re.escape(module_name)}\s*\{{"
    )
    match = pattern.search(text)
    if not match:
        return text, False

    open_end = match.end()

    injection = (
        "\n"
        "    #[derive(Clone, Debug, PartialEq, Eq, Hash)]\n"
        f"    pub struct {type_name};\n"
        f"    impl ::dafny_runtime::DafnyPrint for {type_name} {{\n"
        "        fn fmt_print(\n"
        "            &self,\n"
        "            f: &mut ::std::fmt::Formatter<'_>,\n"
        "            _in_seq: bool,\n"
        "        ) -> ::std::fmt::Result {\n"
        f'            write!(f, "{type_name}")\n'
        "        }\n"
        "    }\n"
    )

    return text[:open_end] + injection + text[open_end:], True


def append_extern_module(
    text: str,
    *,
    module_name: str,
    type_name: str,
) -> str:
    return text + (
        "\n"
        f"pub mod {module_name} {{\n"
        "    #[derive(Clone, Debug, PartialEq, Eq, Hash)]\n"
        f"    pub struct {type_name};\n"
        f"    impl ::dafny_runtime::DafnyPrint for {type_name} {{\n"
        "        fn fmt_print(\n"
        "            &self,\n"
        "            f: &mut ::std::fmt::Formatter<'_>,\n"
        "            _in_seq: bool,\n"
        "        ) -> ::std::fmt::Result {\n"
        f'            write!(f, "{type_name}")\n'
        "        }\n"
        "    }\n"
        "}\n"
    )


def generate_crate_lib_rs(*, crate_root: Path) -> Path:
    lines: list[str] = [
        "//! kipio_account_generated",
        "//!",
        "//! Auto-generated by tools/export_rust_production.py.",
        "//! Do not edit by hand.",
        "",
        "#![allow(warnings, unconditional_panic)]",
        "#![allow(nonstandard_style)]",
        "#![cfg_attr(any(), rustfmt::skip)]",
        "",
        'include!("generated/kipio_account_all.rs");',
    ]

    lib_rs = crate_root / "src" / "lib.rs"
    lib_rs.parent.mkdir(parents=True, exist_ok=True)
    lib_rs.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return lib_rs


def run_cargo_check_offline(crate_root: Path) -> RustCompileResult:
    if shutil.which("cargo") is None:
        return RustCompileResult(
            status="NOT_AVAILABLE",
            detail="cargo was not found in PATH",
        )

    manifest = crate_root / "Cargo.toml"
    if not manifest.is_file():
        return RustCompileResult(
            status="NO_CARGO_MANIFEST",
            detail=f"{manifest} does not exist",
        )

    command = (
        "cargo",
        "check",
        "--manifest-path",
        str(manifest),
        "--offline",
    )

    result = run_captured(list(command), cwd=crate_root)

    failure_class = (
        ""
        if result.returncode == 0
        else classify_cargo_failure(result.stdout, result.stderr)
    )

    return RustCompileResult(
        status=("COMPILED" if result.returncode == 0 else "FAILED"),
        command=command,
        stdout=result.stdout,
        stderr=result.stderr,
        detail=(
            "cargo check succeeded"
            if result.returncode == 0
            else "cargo check failed"
        ),
        failure_class=failure_class,
    )


def run_production_export(
    *,
    formal_root: Path,
    version: str,
    runtime_sources: list[Path],
    ordered_sources: list[Path],
    no_verify: bool,
    tools_root: Path,
) -> int:
    output_root = (formal_root / "generated" / "rust").resolve()
    annotated_root = (
        formal_root / "generated" / "dfy-annotated"
    ).resolve()

    print()
    print("== Production export ==")
    print()
    print(f"Formal root     : {formal_root}")
    print(f"Annotated tree  : {annotated_root}")
    print(f"Rust crate root : {output_root}")
    print()

    generated_template = tools_root / "generated_crate"

    if not (generated_template / "Cargo.toml").is_file():
        raise RuntimeError(
            f"missing generated crate template: {generated_template}"
        )

    # ------------------------------------------------------------------
    # Optional verification on the ORIGINAL tree (no {:extern} edits).
    # ------------------------------------------------------------------
    if not no_verify:
        verify_domain(formal_root)

    # ------------------------------------------------------------------
    # 1. Build annotated Dafny tree.
    # ------------------------------------------------------------------
    print()
    print("== Building annotated Dafny tree ==")
    print()
    clean_directory(annotated_root)
    annotated_root.mkdir(parents=True)
    copy_runtime_dfy_tree(
        formal_root=formal_root,
        annotated_root=annotated_root,
    )

    inject_dafny_files(
        tools_root=tools_root,
        annotated_root=annotated_root,
    )

    annotate_errors = annotate_externs_in_tree(annotated_root)
    if annotate_errors:
        for err in annotate_errors:
            print(f"ERROR: {err}", file=sys.stderr)
        return 2
    print("Annotation OK.")

    # ------------------------------------------------------------------
    # 2. Prepare Rust crate root.
    # ------------------------------------------------------------------
    print()
    print("== Preparing Rust crate ==")
    print()
    clean_directory(output_root)
    output_root.mkdir(parents=True)
    src_root = output_root / "src"
    src_root.mkdir(parents=True, exist_ok=True)
    generated_src = src_root / "generated"
    generated_src.mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------------------
    # 3. Obtain dafny_runtime once.
    # ------------------------------------------------------------------
    anchor = Path("foundation/DomainPrimitives.dfy")

    with tempfile.TemporaryDirectory(
        prefix="kipio-runtime-anchor-"
    ) as tmp_runtime:
        tmp_runtime_path = Path(tmp_runtime)
        runtime_source = obtain_dafny_runtime(
            annotated_root=annotated_root,
            anchor_source=anchor,
            scratch=tmp_runtime_path,
        )
        runtime_target = output_root / "runtime"
        shutil.copytree(runtime_source, runtime_target)
        print(f"Runtime copied to {runtime_target}")

    # ------------------------------------------------------------------
    # 4. Synthesize the single translation entrypoint and translate
    #    it in one Dafny invocation.
    #
    #    The entrypoint includes every runtime source plus every
    #    injected composition. It is the ONLY top-level .dfy passed
    #    to Dafny. This avoids the "file is both top-level and
    #    included transitively" rejection: inject files DO include
    #    runtime files, so listing both sets as inputs would fail.
    # ------------------------------------------------------------------
    print()
    print("== Translating annotated runtime sources (single pass) ==")
    print()

    runtime_relative_paths = [
        source.relative_to(formal_root)
        for source in ordered_sources
    ]

    inject_root = tools_root / "dafny_inject"
    injected_relative_paths: list[Path] = []
    if inject_root.is_dir():
        injected_relative_paths = [
            src_file.relative_to(inject_root)
            for src_file in discover_inject_sources(tools_root)
        ]

    entrypoint_relative = write_translation_entrypoint(
        annotated_root=annotated_root,
        runtime_relative_paths=runtime_relative_paths,
        injected_relative_paths=injected_relative_paths,
    )

    print(
        f"  Translation entrypoint: {entrypoint_relative.as_posix()}"
    )
    print(f"    runtime includes: {len(runtime_relative_paths)}")
    print(
        f"    injected includes: {len(injected_relative_paths)}"
    )
    for rel in injected_relative_paths:
        print(f"      + {rel.as_posix()}")

    with tempfile.TemporaryDirectory(
        prefix="kipio-stage-"
    ) as tmp_stage:
        tmp_stage_path = Path(tmp_stage)

        rs_file = translate_all_sources_from_annotated_tree(
            source_relative_paths=[entrypoint_relative],
            annotated_root=annotated_root,
            staging_dir=tmp_stage_path,
        )

        if rs_file is None:
            print()
            print(
                "Dafny translation failed; "
                "the crate was not assembled."
            )
            return 2

        cleaned = clean_generated_rust(
            rs_file.read_text(encoding="utf-8")
        )

        cleaned, fn_fixed = fix_dafny_fn_return_types(cleaned)
        if fn_fixed:
            print(
                f"  Fixed {fn_fixed} dyn-Fn return type(s) "
                f"(Dafny 4.11 leaves them as `_`)"
            )

        for module_name, type_name in EXTERN_MODULE_TYPE_MAP:
            cleaned, injected = inject_extern_type_into_module(
                cleaned,
                module_name=module_name,
                type_name=type_name,
            )
            if not injected:
                cleaned = append_extern_module(
                    cleaned,
                    module_name=module_name,
                    type_name=type_name,
                )

        target = generated_src / "kipio_account_all.rs"
        target.write_text(cleaned, encoding="utf-8")
        print(f"  OK -> {target.relative_to(output_root)}")

    # ------------------------------------------------------------------
    # 5. Generate the crate's lib.rs.
    # ------------------------------------------------------------------
    generate_crate_lib_rs(crate_root=output_root)
    print()
    print(f"Generated {output_root / 'src' / 'lib.rs'}")

    # ------------------------------------------------------------------
    # 6. Copy the generated crate template's Cargo.toml.
    # ------------------------------------------------------------------
    shutil.copyfile(
        generated_template / "Cargo.toml",
        output_root / "Cargo.toml",
    )
    print(f"Cargo.toml copied to {output_root / 'Cargo.toml'}")

    # ------------------------------------------------------------------
    # 7. cargo check --offline.
    # ------------------------------------------------------------------
    print()
    print("== cargo check --offline ==")
    print()

    cargo_result = run_cargo_check_offline(output_root)

    print(f"status        : {cargo_result.status}")
    print(f"detail        : {cargo_result.detail}")
    if cargo_result.failure_class:
        print(f"failure_class : {cargo_result.failure_class}")

    if cargo_result.stdout.strip():
        print("stdout:")
        for line in cargo_result.stdout.strip().splitlines():
            print(f"  {line}")

    if cargo_result.stderr.strip():
        print("stderr:")
        for line in cargo_result.stderr.strip().splitlines():
            print(f"  {line}")

    if cargo_result.status == "COMPILED":
        print()
        print("Production export completed successfully.")
        return 0

    if cargo_result.failure_class == "ENVIRONMENT_BLOCKED":
        print()
        print(
            "Cargo was environment-blocked (dependency cache, registry, "
            "or network). The generated crate itself is not at fault."
        )
        return 2

    print()
    print("Cargo compilation failed.")
    return 2


# ============================================================================
# Diagnose / plan helpers
# ============================================================================

def translate_source(
    source: Path,
    *,
    formal_root: Path,
    output_root: Path,
    include_runtime: bool,
    emit_uncompilable_code: bool,
    commit_output: bool,
) -> TranslationResult:
    source = source.resolve()
    formal_root = formal_root.resolve()
    relative = source.relative_to(formal_root)

    final_output_root = (
        output_root / relative.parts[0] / source.stem
    )

    if commit_output:
        final_output_root.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(
        prefix="kipio-dafny-rs-"
    ) as temporary_directory:
        staging_root = Path(temporary_directory) / source.stem
        staging_root.mkdir(parents=True, exist_ok=True)
        output_file = staging_root / f"{source.stem}.rs"

        command = [
            "dafny",
            "translate",
            "rs",
            str(relative),
            "--output",
            str(output_file),
            "--enforce-determinism",
        ]
        if include_runtime:
            command.append("--include-runtime")
        if emit_uncompilable_code:
            command.append("--emit-uncompilable-code")

        result = run(command, cwd=formal_root, capture=True)
        generated_files = collect_generated_files(staging_root)

        if result.returncode != 0:
            return TranslationResult(
                source=relative,
                status=(
                    "DIAGNOSTIC_FAILED"
                    if not commit_output
                    else "FAILED"
                ),
                stdout=result.stdout,
                stderr=result.stderr,
                detail=(
                    result.stderr.strip()
                    or result.stdout.strip()
                    or "Dafny Rust translation failed"
                ),
            )

        if not generated_files:
            return TranslationResult(
                source=relative,
                status="NO_OUTPUT",
                output_root=(
                    final_output_root if commit_output else None
                ),
                stdout=result.stdout,
                stderr=result.stderr,
                detail=(
                    "Dafny translation succeeded but produced no files"
                ),
            )

        if not commit_output:
            return TranslationResult(
                source=relative,
                status="DIAGNOSTIC_OK",
                generated_files=generated_files,
                stdout=result.stdout,
                stderr=result.stderr,
                detail=(
                    f"translation succeeded; "
                    f"{len(generated_files)} staged file(s) discarded"
                ),
            )

        if final_output_root.exists():
            shutil.rmtree(final_output_root)
        shutil.copytree(staging_root, final_output_root)

        final_files = collect_generated_files(final_output_root)
        return TranslationResult(
            source=relative,
            status="GENERATED",
            output_root=final_output_root,
            generated_files=final_files,
            stdout=result.stdout,
            stderr=result.stderr,
            detail=f"generated {len(final_files)} file(s)",
        )


def run_plan(
    *,
    formal_root: Path,
    runtime_sources: list[Path],
    ordered_sources: list[Path],
) -> int:
    print()
    print("== Runtime export plan ==")
    print()
    print(f"Runtime files: {len(runtime_sources)}")
    print()
    for index, source in enumerate(ordered_sources, start=1):
        print(f"{index:02d}. {source.relative_to(formal_root)}")
    return 0


def run_diagnose(
    *,
    formal_root: Path,
    output_root: Path,
    ordered_sources: list[Path],
    runtime_sources: list[Path],
    include_runtime: bool,
    emit_uncompilable_code: bool,
) -> int:
    print()
    print("== Diagnostic translation of all runtime sources ==")
    print()
    print("Generated artifacts will be discarded.")

    results: list[TranslationResult] = []
    for source in ordered_sources:
        print()
        print(f"Diagnosing: {source.relative_to(formal_root)}")
        result = translate_source(
            source,
            formal_root=formal_root,
            output_root=output_root,
            include_runtime=include_runtime,
            emit_uncompilable_code=emit_uncompilable_code,
            commit_output=False,
        )
        results.append(result)

        if result.status == "DIAGNOSTIC_OK":
            print(f"  OK — {result.detail}")
        elif result.status == "NO_OUTPUT":
            print(f"  NO OUTPUT — {result.detail}")
        else:
            print("  FAILED")
            if result.detail:
                print(f"  {result.detail}", file=sys.stderr)

    passed = [r for r in results if r.status == "DIAGNOSTIC_OK"]
    failed = [r for r in results if r.status == "DIAGNOSTIC_FAILED"]

    print()
    print("== Diagnostic summary ==")
    print()
    print(f"Tested  : {len(runtime_sources)}")
    print(f"OK      : {len(passed)}")
    print(f"FAILED  : {len(failed)}")

    return 0 if not failed and len(results) == len(runtime_sources) else 2


# ============================================================================
# Extern lab (reduced to control + 3 winners)
# ============================================================================

EXTERN_LAB_SOURCE = Path("foundation/Chain.dfy")
EXTERN_LAB_TYPE = "Chain"

DEFAULT_EXTERN_CANDIDATES = (
    ("control-no-extern", ""),
    ("extern-empty", "{:extern}"),
    ("extern-same-name", '{:extern "Chain"}'),
    (
        "extern-two-args",
        '{:extern "KipioAccountChain", "Chain"}',
    ),
)

EXTERN_LAB_CONSUMER_SOURCE = Path("ExternChainConsumer.dfy")

EXTERN_LAB_CONSUMER_FIXTURE = (
    Path(__file__).resolve().parent
    / "extern_lab"
    / "fixtures"
    / "ExternChainConsumer.dfy"
)

EXTERN_LAB_MODULE = "KipioAccountChain"

LAB_COMMAND_OUTPUT_MAX_CHARS = 20_000
LAB_FILE_PREVIEW_MAX_CHARS = 12_000
LAB_REFERENCE_MAX_LINES = 120


def normalize_extern_declaration(declaration: str) -> str:
    declaration = declaration.strip()
    if not declaration:
        return ""
    if not declaration.startswith("{:extern"):
        raise ValueError(f"invalid extern attribute: {declaration}")
    if not declaration.endswith("}"):
        raise ValueError(f"invalid extern attribute: {declaration}")
    return declaration


def load_extern_lab_consumer() -> str:
    text = EXTERN_LAB_CONSUMER_FIXTURE.read_text(encoding="utf-8")
    if "import ChainModule = KipioAccountChain" not in text:
        raise RuntimeError(
            "extern lab consumer fixture does not contain "
            "the required module import"
        )
    return text


def truncate_for_report(text: str, *, max_chars: int) -> str:
    if len(text) <= max_chars:
        return text
    return (
        text[:max_chars]
        + "\n\n... [TRUNCATED BY EXPORTER] ...\n"
        + f"original characters: {len(text)}\n"
    )


def classify_cargo_failure(stdout: str, stderr: str) -> str:
    text = (stdout + "\n" + stderr).lower()
    environment_markers = (
        "attempting to make an http request, but --offline was specified",
        "failed to download",
        "failed to fetch",
        "network failure",
        "could not resolve host",
        "no matching package named",
        "failed to get",
        "unable to update registry",
        "download of ",
        "failed to load source for dependency",
    )
    if any(marker in text for marker in environment_markers):
        return "ENVIRONMENT_BLOCKED"
    return "CARGO_COMPILE_ERROR"


def run_extern_lab_case(
    *,
    formal_root: Path,
    candidate_id: str,
    attribute: str,
) -> ExternLabResult:
    source = formal_root / EXTERN_LAB_SOURCE
    if not source.is_file():
        raise RuntimeError(
            f"extern lab source does not exist: {source}"
        )

    original_text = source.read_text(encoding="utf-8")
    consumer_text = load_extern_lab_consumer()

    original_declaration = find_single_type_declaration(
        original_text, EXTERN_LAB_TYPE
    )
    if original_declaration is None:
        raise RuntimeError(
            f"extern lab could not find abstract type "
            f"{EXTERN_LAB_TYPE} in {EXTERN_LAB_SOURCE}"
        )

    extern_attribute = normalize_extern_declaration(attribute)

    with tempfile.TemporaryDirectory(
        prefix="kipio-extern-lab-"
    ) as temporary_directory:
        temporary_root = Path(temporary_directory)
        lab_root = temporary_root / "formal"
        shutil.copytree(formal_root, lab_root)

        lab_source = lab_root / EXTERN_LAB_SOURCE
        lab_text = lab_source.read_text(encoding="utf-8")
        transformed_text, match_count = replace_abstract_type_for_extern(
            lab_text,
            type_name=EXTERN_LAB_TYPE,
            extern_attribute=extern_attribute,
        )
        if match_count != 1:
            return ExternLabResult(
                candidate_id=candidate_id,
                attribute=attribute,
                verify_status="NOT_RUN",
                translate_status="NOT_RUN",
                detail=(
                    f"expected exactly one abstract type declaration "
                    f"for {EXTERN_LAB_TYPE}; found {match_count}"
                ),
            )
        lab_source.write_text(transformed_text, encoding="utf-8")

        consumer_source = lab_root / EXTERN_LAB_CONSUMER_SOURCE
        consumer_source.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(EXTERN_LAB_CONSUMER_FIXTURE, consumer_source)

        generated_root = temporary_root / "generated"
        generated_root.mkdir(parents=True, exist_ok=True)

        transformed_declaration = find_single_type_declaration(
            transformed_text, EXTERN_LAB_TYPE
        )

        original_sha256 = hashlib.sha256(
            original_text.encode("utf-8")
        ).hexdigest()
        transformed_sha256 = hashlib.sha256(
            transformed_text.encode("utf-8")
        ).hexdigest()

        verify_result = run_captured(
            ["dafny", "verify", str(EXTERN_LAB_CONSUMER_SOURCE)],
            cwd=lab_root,
        )
        if verify_result.returncode != 0:
            return ExternLabResult(
                candidate_id=candidate_id,
                attribute=attribute,
                verify_status="FAILED",
                translate_status="NOT_RUN",
                verify_stdout=truncate_for_report(
                    verify_result.stdout,
                    max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
                ),
                verify_stderr=truncate_for_report(
                    verify_result.stderr,
                    max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
                ),
                detail="Dafny verification failed for extern variant",
                original_declaration=original_declaration,
                transformed_declaration=transformed_declaration,
                original_sha256=original_sha256,
                transformed_sha256=transformed_sha256,
                consumer_source=consumer_text,
            )

        translation_root = generated_root / "standard"
        translation_root.mkdir(parents=True, exist_ok=True)
        output_file = translation_root / "ExternChainConsumer.rs"

        translate_result = run_captured(
            [
                "dafny",
                "translate",
                "rs",
                str(EXTERN_LAB_CONSUMER_SOURCE),
                "--output",
                str(output_file),
                "--enforce-determinism",
            ],
            cwd=lab_root,
        )

        generated_files = collect_generated_files(translation_root)

        if translate_result.returncode != 0:
            return ExternLabResult(
                candidate_id=candidate_id,
                attribute=attribute,
                verify_status="OK",
                translate_status="FAILED",
                generated_files=generated_files,
                verify_stdout=truncate_for_report(
                    verify_result.stdout,
                    max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
                ),
                verify_stderr=truncate_for_report(
                    verify_result.stderr,
                    max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
                ),
                translate_stdout=truncate_for_report(
                    translate_result.stdout,
                    max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
                ),
                translate_stderr=truncate_for_report(
                    translate_result.stderr,
                    max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
                ),
                detail=(
                    "Dafny verification succeeded but Rust "
                    "translation failed"
                ),
                original_declaration=original_declaration,
                transformed_declaration=transformed_declaration,
                original_sha256=original_sha256,
                transformed_sha256=transformed_sha256,
                consumer_source=consumer_text,
            )

        return ExternLabResult(
            candidate_id=candidate_id,
            attribute=attribute,
            verify_status="OK",
            translate_status="OK",
            generated_files=generated_files,
            verify_stdout=truncate_for_report(
                verify_result.stdout,
                max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
            ),
            verify_stderr=truncate_for_report(
                verify_result.stderr,
                max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
            ),
            translate_stdout=truncate_for_report(
                translate_result.stdout,
                max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
            ),
            translate_stderr=truncate_for_report(
                translate_result.stderr,
                max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
            ),
            detail="verification and translation succeeded",
            original_declaration=original_declaration,
            transformed_declaration=transformed_declaration,
            original_sha256=original_sha256,
            transformed_sha256=transformed_sha256,
            consumer_source=consumer_text,
        )


def parse_extern_candidates(
    raw_candidates: list[str] | None,
) -> list[tuple[str, str]]:
    if not raw_candidates:
        return list(DEFAULT_EXTERN_CANDIDATES)

    candidates: list[tuple[str, str]] = []
    for index, value in enumerate(raw_candidates, start=1):
        if "=" in value:
            candidate_id, attribute = value.split("=", 1)
            candidate_id = candidate_id.strip()
            attribute = attribute.strip()
            if not candidate_id:
                candidate_id = f"custom-{index}"
        else:
            candidate_id = f"custom-{index}"
            attribute = value.strip()
        candidates.append((candidate_id, attribute))
    return candidates


def write_extern_lab_report(
    path: Path,
    *,
    formal_root: Path,
    dafny_version_value: str,
    results: list[ExternLabResult],
) -> None:
    lines: list[str] = [
        "KIPIO DAFNY → RUST EXTERN LAB REPORT (reduced)",
        "===============================================",
        "",
        f"Formal root : {formal_root}",
        f"Dafny       : {dafny_version_value}",
        f"Source      : {EXTERN_LAB_SOURCE}",
        f"Type        : {EXTERN_LAB_TYPE}",
        f"Candidates  : {len(results)}",
        "",
        "CANDIDATE MATRIX",
        "----------------",
        "",
    ]

    for result in results:
        lines.extend(
            [
                "=" * 72,
                f"CANDIDATE: {result.candidate_id}",
                "=" * 72,
                "",
                f"attribute          : "
                f"{result.attribute or '<control: no extern>'}",
                f"verify_status      : {result.verify_status}",
                f"translate_status   : {result.translate_status}",
                f"original_sha256    : {result.original_sha256}",
                f"transformed_sha256 : {result.transformed_sha256}",
                "",
                "ORIGINAL DECLARATION",
                "--------------------",
                result.original_declaration or "<none>",
                "",
                "TRANSFORMED DECLARATION",
                "-----------------------",
                str(result.transformed_declaration) or "<none>",
                "",
                "GENERATED FILES",
                "---------------",
            ]
        )
        if result.generated_files:
            for gf in result.generated_files:
                lines.append(f"  - {gf}")
        else:
            lines.append("  <none>")

        if result.detail:
            lines.extend(["", f"detail: {result.detail}"])

        if result.verify_stdout.strip():
            lines.extend(
                [
                    "",
                    "VERIFY STDOUT",
                    "-------------",
                    result.verify_stdout.strip(),
                ]
            )
        if result.verify_stderr.strip():
            lines.extend(
                [
                    "",
                    "VERIFY STDERR",
                    "-------------",
                    result.verify_stderr.strip(),
                ]
            )
        if result.translate_stdout.strip():
            lines.extend(
                [
                    "",
                    "TRANSLATE STDOUT",
                    "----------------",
                    result.translate_stdout.strip(),
                ]
            )
        if result.translate_stderr.strip():
            lines.extend(
                [
                    "",
                    "TRANSLATE STDERR",
                    "----------------",
                    result.translate_stderr.strip(),
                ]
            )
        lines.append("")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def run_extern_lab(
    *,
    formal_root: Path,
    version: str,
    raw_candidates: list[str] | None,
    report_path: Path,
) -> int:
    candidates = parse_extern_candidates(raw_candidates)

    print()
    print("== Extern lab (control + 3 winners) ==")
    print()
    print(f"Source    : {EXTERN_LAB_SOURCE}")
    print(f"Type      : {EXTERN_LAB_TYPE}")
    print(f"Candidates: {len(candidates)}")
    print()

    results: list[ExternLabResult] = []
    for candidate_id, attribute in candidates:
        print("=" * 72)
        print(f"Testing: {candidate_id}")
        print(f"  attribute: {attribute or '<control: no extern>'}")

        result = run_extern_lab_case(
            formal_root=formal_root,
            candidate_id=candidate_id,
            attribute=attribute,
        )
        results.append(result)

        print(f"  verify     : {result.verify_status}")
        print(f"  translate  : {result.translate_status}")

    print()
    print("== Summary ==")
    print()
    for result in results:
        print(
            f"  [{result.candidate_id}] "
            f"verify={result.verify_status} "
            f"translate={result.translate_status}"
        )
    print()

    write_extern_lab_report(
        report_path,
        formal_root=formal_root,
        dafny_version_value=version,
        results=results,
    )
    print(f"Extern lab report: {report_path}")

    any_success = any(
        r.verify_status == "OK" and r.translate_status == "OK"
        for r in results
    )
    return 0 if any_success else 2


# ============================================================================
# CLI
# ============================================================================

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Production Dafny → Rust export for the Kipio Account "
            "formal domain."
        )
    )

    parser.add_argument(
        "--no-verify",
        action="store_true",
        help="skip repository-wide Dafny verification",
    )
    parser.add_argument(
        "--plan",
        action="store_true",
        help="show the dependency-aware export plan and stop",
    )
    parser.add_argument(
        "--diagnose",
        action="store_true",
        help=(
            "translate every runtime source independently, "
            "continue after failures, discard output"
        ),
    )
    parser.add_argument(
        "--extern-lab",
        action="store_true",
        help=(
            "experiment with {:extern} representations for Chain "
            "(control + 3 winners)"
        ),
    )
    parser.add_argument(
        "--extern-candidate",
        action="append",
        help=(
            "custom extern-lab candidate. Format: id={:extern ...} "
            "or simply {:extern ...}"
        ),
    )
    parser.add_argument(
        "--include-runtime",
        action="store_true",
        help="include the Dafny runtime in diagnostic output",
    )
    parser.add_argument(
        "--emit-uncompilable-code",
        action="store_true",
        help="allow Dafny to emit Rust identified as uncompilable",
    )
    return parser.parse_args()


# ============================================================================
# Main
# ============================================================================

def main() -> int:
    args = parse_args()

    selected_modes = sum(
        [args.plan, args.diagnose, args.extern_lab]
    )
    if selected_modes > 1:
        raise RuntimeError(
            "--plan, --diagnose and --extern-lab are mutually exclusive"
        )

    formal_root = (
        Path(__file__).resolve().parent.parent
    )
    tools_root = Path(__file__).resolve().parent

    output_root = (formal_root / "generated" / "rust").resolve()

    require_tool("dafny")
    version = check_dafny_environment()

    if args.extern_lab:
        report_path = tools_root / "extern-lab-report.txt"
        return run_extern_lab(
            formal_root=formal_root,
            version=version,
            raw_candidates=args.extern_candidate,
            report_path=report_path,
        )

    runtime_sources = discover_runtime_sources(formal_root)
    if not runtime_sources:
        raise RuntimeError("no runtime Dafny sources found")

    classified = classify_sources(
        discover_all_sources(formal_root),
        formal_root,
    )

    print()
    print("KIPIO DAFNY → RUST PRODUCTION EXPORT")
    print("=====================================")
    print()
    print(f"Formal root  : {formal_root}")
    print(f"Output root  : {output_root}")
    print(f"Runtime files: {len(runtime_sources)}")
    for layer in RUNTIME_LAYERS:
        print(f"  {layer:<15} {len(classified[layer])}")
    print()
    for layer in VERIFICATION_ONLY_LAYERS:
        print(
            f"  {layer:<15} {len(classified[layer])} "
            f"(verification-only)"
        )

    ordered_sources, structural_errors, _graph = (
        dependency_first_runtime_order(formal_root, runtime_sources)
    )

    if structural_errors:
        print()
        print("== Structural export checks ==")
        print()
        for error in structural_errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 2

    if args.plan:
        return run_plan(
            formal_root=formal_root,
            runtime_sources=runtime_sources,
            ordered_sources=ordered_sources,
        )

    if args.diagnose:
        return run_diagnose(
            formal_root=formal_root,
            output_root=output_root,
            ordered_sources=ordered_sources,
            runtime_sources=runtime_sources,
            include_runtime=args.include_runtime,
            emit_uncompilable_code=args.emit_uncompilable_code,
        )

    return run_production_export(
        formal_root=formal_root,
        version=version,
        runtime_sources=runtime_sources,
        ordered_sources=ordered_sources,
        no_verify=args.no_verify,
        tools_root=tools_root,
    )


if __name__ == "__main__":
    raise SystemExit(main())
