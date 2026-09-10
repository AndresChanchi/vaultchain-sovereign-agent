#!/usr/bin/env python3

"""
Dafny → Rust export pipeline for the Kipio Account formal domain.

The formal Dafny model is the source of truth.


CURRENT PHASE
-------------

This exporter currently implements:

    PHASE 1 — GENERIC RUST

The current evidence boundary is:

    A. DAFNY SEMANTICS
       1. isolated source transformation
       2. Dafny verification

    B. DAFNY → RUST
       3. standard Rust translation
       4. generated-file inspection
       5. symbol/reference inspection

    C. RUST BASELINE
       6. rustc compilation attempt
       7. cargo check when applicable

    E. DIAGNOSTIC DAFNY MODES
       11. translation with --emit-uncompilable-code
       12. rustc attempt on that output
       13. translation with --include-runtime
       14. rustc attempt on include-runtime output


FUTURE PHASE — STYLUS / ARBITRUM
--------------------------------

The following are intentionally NOT implemented here:

    8.  inject generated Rust into Stylus harness
    9.  cargo stylus check
    10. cargo stylus build
    15. cargo stylus check/build with generated output
    16. inspect generated WASM
    17. record WASM artifact size and build metadata

These belong to the later Stylus integration phase.

The generic Rust boundary must be characterized first.


RUNTIME LAYERS
--------------

    foundation
    authority
    account
    authorization
    execution
    policy


VERIFICATION-ONLY LAYERS
------------------------

    laws
    proofs


IMPORTANT
---------

This tool does NOT reinterpret Dafny semantics.

Dafny remains responsible for determining whether Dafny sources
can be translated to Rust.

This exporter is responsible for:

    - deterministic source discovery
    - runtime / verification-only separation
    - dependency analysis
    - runtime dependency boundary checks
    - dependency-aware processing order
    - architectural layer priority
    - Dafny verification gating
    - Rust backend detection
    - Rust deterministic-compilation requirements
    - isolated translation staging
    - generated artifact collection
    - translation diagnostics
    - reproducible export reports
    - controlled extern experimentation
    - generic Rust Cargo-harness compilation diagnostics
    - distinguishing Cargo environment failures from Rust failures

The generated Rust is a derived artifact.

It is NOT the formal source of truth.


EXTERN LAB
----------

The --extern-lab mode is an experimental harness.

It NEVER modifies the real formal source tree.

It creates an isolated temporary copy of the Dafny project, modifies
only the selected abstract type declaration in that copy, then runs:

    Dafny verify
        +
    Dafny translate rs
        +
    generated-file inspection
        +
    symbol/reference inspection
        +
    rustc diagnostic
        +
    Cargo diagnostic
        +
    external-symbol Cargo harness

The semantic consumer and minimal external Rust representation are kept as
fixtures under tools/extern_lab/fixtures.

The Python tool remains the orchestrator.

A successful Dafny translation does NOT by itself establish that the
resulting Rust is production-ready.

The laboratory treats these as independent checkpoints:

    VERIFY
        =
    Dafny accepts the transformed model

    TRANSLATE
        =
    Dafny produces Rust

    RUSTC
        =
    generated Rust can be compiled as standalone Rust input

    CARGO
        =
    generated Rust can be evaluated in a Cargo environment

    EXTERN HARNESS
        =
    generated Rust can consume the expected external Rust symbol contract


CARGO FAILURE CLASSIFICATION
----------------------------

A Cargo non-zero exit code is NOT automatically evidence that the generated
Rust is incompatible.

For example:

    failed to download ...
    attempting to make an HTTP request, but --offline was specified
    failed to fetch ...
    network failure
    no matching package named ...

represent an environment/dependency-resolution problem.

Those are classified as:

    ENVIRONMENT_BLOCKED

Actual Rust/Cargo compilation failures are classified separately as:

    CARGO_COMPILE_ERROR

This distinction is diagnostic only.

No automatic network retry is performed by default.


DDD BOUNDARY
------------

The DDD remains the semantic source of truth.

This exporter does not redesign concepts such as:

    Identity
    Account
    Credential
    Session
    Delegation
    Capability
    Authorization
    EffectiveAuthority
    ExecutionContext
    Chain

In particular, Chain remains a semantic part of Authorization context
where defined by the domain.

The extern laboratory is concerned only with the target-language
representation needed to materialize the already-defined model as
generic Rust.

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
    print(
        "$",
        " ".join(command),
    )

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


def require_tool(
    name: str,
) -> None:
    if shutil.which(name) is None:
        raise RuntimeError(
            f"required tool '{name}' was not found in PATH"
        )


# ============================================================================
# Dafny environment
# ============================================================================

def dafny_version() -> str:
    result = run(
        [
            "dafny",
            "--version",
        ],
        cwd=Path.cwd(),
        capture=True,
    )

    if result.returncode != 0:
        raise RuntimeError(
            "unable to determine Dafny version"
        )

    version = (
        result.stdout.strip()
        or result.stderr.strip()
    )

    if not version:
        raise RuntimeError(
            "Dafny version command returned no version"
        )

    return version


def dafny_base_version(
    version: str,
) -> str:
    """
    Extract the semantic version from Dafny's version string.

    Examples:

        4.11.0
        4.11.0+fcb2042d6d...
        4.11.0-preview...

    all resolve to:

        4.11.0
    """

    match = re.search(
        r"\d+\.\d+\.\d+",
        version,
    )

    if not match:
        raise RuntimeError(
            f"unable to parse Dafny version: {version}"
        )

    return match.group(0)


def rust_backend_available() -> bool:
    result = run(
        [
            "dafny",
            "translate",
            "--help",
        ],
        cwd=Path.cwd(),
        capture=True,
    )

    help_text = (
        result.stdout
        + "\n"
        + result.stderr
    )

    return bool(
        re.search(
            r"(?m)^\s*rs\s+<file>\s+Translate Dafny sources to Rust",
            help_text,
            re.IGNORECASE,
        )
    )


def check_dafny_environment() -> str:
    print()
    print(
        "== Dafny environment =="
    )
    print()

    version = dafny_version()

    print(
        f"Dafny version: {version}"
    )

    base_version = dafny_base_version(
        version
    )

    if base_version != EXPECTED_DAFNY_VERSION:
        print(
            "WARNING: exporter was developed against "
            f"Dafny {EXPECTED_DAFNY_VERSION}."
        )

        print(
            f"         Detected base version: {base_version}"
        )

        print(
            "         Backend output may differ."
        )

    if not rust_backend_available():
        raise RuntimeError(
            "Dafny Rust backend is not available. "
            "Expected `dafny translate rs <file>`."
        )

    print(
        "Rust backend: available"
    )

    print(
        "Rust translation: --enforce-determinism enabled"
    )

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
        key=lambda path: (
            path.relative_to(
                formal_root
            ).as_posix()
        ),
    )


def discover_runtime_sources(
    formal_root: Path,
) -> list[Path]:
    sources: list[Path] = []

    for layer in RUNTIME_LAYERS:
        sources.extend(
            discover_layer_sources(
                formal_root,
                layer,
            )
        )

    return sources


def discover_all_sources(
    formal_root: Path,
) -> list[Path]:
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
                key=lambda path: (
                    path.relative_to(
                        formal_root
                    ).as_posix()
                ),
            )
        )

    return sources


# ============================================================================
# Layer classification
# ============================================================================

def source_layer(
    source: Path,
    formal_root: Path,
) -> str:
    source = source.resolve()
    formal_root = formal_root.resolve()

    relative = source.relative_to(
        formal_root
    )

    if not relative.parts:
        raise RuntimeError(
            f"source has no layer: {source}"
        )

    layer = relative.parts[0]

    if layer not in ALL_LAYERS:
        raise RuntimeError(
            f"source belongs to unknown layer '{layer}': "
            f"{relative}"
        )

    return layer


def classify_sources(
    sources: list[Path],
    formal_root: Path,
) -> dict[str, list[Path]]:
    classified: dict[
        str,
        list[Path],
    ] = {
        layer: []
        for layer in ALL_LAYERS
    }

    for source in sources:
        layer = source_layer(
            source,
            formal_root,
        )

        classified[layer].append(
            source
        )

    for layer_sources in classified.values():
        layer_sources.sort(
            key=lambda path: (
                path.relative_to(
                    formal_root
                ).as_posix()
            )
        )

    return classified


# ============================================================================
# Dependency analysis
# ============================================================================

def analyze_dependencies(
    formal_root: Path,
):
    """
    Reuse dependency_graph.py directly.

    The dependency analyzer remains the source of truth for graph
    construction and graph semantics.

    No subprocess.
    No generated dependency files.
    No duplicated graph parsing logic.
    """

    files = dependency_graph.scan_project(
        formal_root
    )

    if not files:
        raise RuntimeError(
            "no Dafny source files found"
        )

    (
        module_index,
        duplicate_module_errors,
    ) = dependency_graph.build_module_index(
        files
    )

    graph = dependency_graph.build_graph(
        files,
        module_index,
        formal_root,
    )

    nodes = dependency_graph.all_project_nodes(
        files,
        formal_root,
    )

    combined = dependency_graph.combined_edges(
        graph
    )

    cycles = dependency_graph.find_cycles(
        combined
    )

    topo = dependency_graph.topological_order(
        nodes,
        combined,
    )

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

def export_node_sort_key(
    node: Path,
    formal_root: Path,
) -> tuple[int, str]:
    """
    Sort a relative graph node by:

        1. architectural layer
        2. deterministic path

    The architectural layer is only a tie-breaker.

    Actual dependency order always takes precedence.
    """

    layer = source_layer(
        formal_root / node,
        formal_root,
    )

    return (
        LAYER_PRIORITY.get(
            layer,
            len(LAYER_PRIORITY),
        ),
        node.as_posix(),
    )


def sort_export_ready_nodes(
    ready: list[Path],
    formal_root: Path,
) -> None:
    """
    Sort currently-ready graph nodes using architectural layer priority.

    A node only becomes ready after all of its dependencies are processed,
    so layer priority cannot violate an actual dependency.
    """

    ready.sort(
        key=lambda node: export_node_sort_key(
            node,
            formal_root,
        )
    )


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
    ) = analyze_dependencies(
        formal_root
    )

    # ------------------------------------------------------------------
    # Restrict the node set to known domain layers.
    #
    # dependency_graph.scan_project() recurses into the entire project
    # tree, including tools/ (which holds the extern lab fixtures such
    # as tools/extern_lab/fixtures/ExternChainConsumer.dfy). Those
    # files are not part of the formal domain and must not participate
    # in layer classification, verification-only classification nor in
    # the export ordering. Any downstream call to source_layer() would
    # raise on a 'tools' path because 'tools' is not in ALL_LAYERS, so
    # we filter them out immediately after graph analysis.
    # ------------------------------------------------------------------
    nodes = [
        node
        for node in nodes
        if node.parts and node.parts[0] in ALL_LAYERS
    ]

    errors: list[str] = []

    errors.extend(
        duplicate_module_errors
    )

    if cycles:
        errors.append(
            "dependency graph contains cycle(s)"
        )

        for cycle in cycles:
            errors.append(
                "cycle: "
                + " -> ".join(
                    path.as_posix()
                    for path in cycle
                )
            )

    runtime_set = {
        source.resolve()
        for source in runtime_sources
    }

    graph_nodes = {
        (
            formal_root / node
        ).resolve()
        for node in nodes
    }

    missing_from_graph = (
        runtime_set
        - graph_nodes
    )

    for source in sorted(
        missing_from_graph,
        key=lambda path: (
            path.relative_to(
                formal_root
            ).as_posix()
        ),
    ):
        errors.append(
            "runtime source missing from dependency graph: "
            f"{source.relative_to(formal_root)}"
        )

    verification_set = {
        (
            formal_root / path
        ).resolve()
        for path in nodes
        if source_layer(
            formal_root / path,
            formal_root,
        ) in VERIFICATION_ONLY_LAYERS
    }

    runtime_nodes = [
        node
        for node in nodes
        if (
            formal_root / node
        ).resolve() in runtime_set
    ]

    runtime_node_set = set(
        runtime_nodes
    )

    runtime_dependencies: dict[
        Path,
        set[Path],
    ] = {
        node: {
            dependency
            for dependency in combined.get(
                node,
                set(),
            )
            if dependency in runtime_node_set
        }
        for node in runtime_nodes
    }

    runtime_dependents = (
        dependency_graph.reverse_edges(
            runtime_nodes,
            runtime_dependencies,
        )
    )

    indegree = {
        node: len(
            runtime_dependencies[node]
        )
        for node in runtime_nodes
    }

    ready = [
        node
        for node in runtime_nodes
        if indegree[node] == 0
    ]

    sort_export_ready_nodes(
        ready,
        formal_root,
    )

    ordered_runtime_relative: list[Path] = []

    while ready:
        node = ready.pop(0)

        ordered_runtime_relative.append(
            node
        )

        for dependent in runtime_dependents.get(
            node,
            set(),
        ):
            indegree[dependent] -= 1

            if indegree[dependent] == 0:
                ready.append(
                    dependent
                )

        sort_export_ready_nodes(
            ready,
            formal_root,
        )

    if len(ordered_runtime_relative) != len(
        runtime_nodes
    ):
        errors.append(
            "runtime dependency graph could not be "
            "topologically ordered"
        )

        return [], errors, graph

    ordered_runtime = [
        (
            formal_root / node
        ).resolve()
        for node in ordered_runtime_relative
    ]

    ordered_set = set(
        ordered_runtime
    )

    missing = (
        runtime_set
        - ordered_set
    )

    for source in sorted(
        missing,
        key=lambda path: (
            path.relative_to(
                formal_root
            ).as_posix()
        ),
    ):
        errors.append(
            "runtime source missing from export order: "
            f"{source.relative_to(formal_root)}"
        )

    for source in runtime_sources:
        relative = source.relative_to(
            formal_root
        )

        transitive = (
            dependency_graph.reachable_nodes(
                relative,
                combined,
            )
        )

        forbidden = [
            path
            for path in transitive
            if (
                formal_root / path
            ).resolve() in verification_set
        ]

        if forbidden:
            errors.append(
                "runtime source depends on "
                "verification-only layer: "
                f"{relative}"
            )

            for path in sorted(
                forbidden,
                key=lambda item: item.as_posix(),
            ):
                errors.append(
                    f"  -> {path.as_posix()}"
                )

    return (
        ordered_runtime,
        errors,
        graph,
    )


# ============================================================================
# Formal verification
# ============================================================================

def verify_domain(
    formal_root: Path,
) -> None:
    sources = discover_all_sources(
        formal_root
    )

    if not sources:
        raise RuntimeError(
            "no Dafny source files found"
        )

    print()
    print(
        "== Formal verification =="
    )
    print()

    command = [
        "dafny",
        "verify",
        *(
            str(
                path.relative_to(
                    formal_root
                )
            )
            for path in sources
        ),
    ]

    result = run(
        command,
        cwd=formal_root,
    )

    if result.returncode != 0:
        raise RuntimeError(
            "formal verification failed; "
            "Rust export was aborted"
        )


# ============================================================================
# Generated output
# ============================================================================

def clean_output_root(
    output_root: Path,
) -> None:
    if output_root.exists():
        print()
        print(
            f"Cleaning generated output: {output_root}"
        )

        shutil.rmtree(
            output_root
        )


def source_output_directory(
    source: Path,
    formal_root: Path,
    output_root: Path,
) -> Path:
    relative = source.relative_to(
        formal_root
    )

    layer = relative.parts[0]

    return (
        output_root
        / layer
        / source.stem
    )


def collect_generated_files(
    root: Path,
) -> tuple[Path, ...]:
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


def sha256_file(
    path: Path,
) -> str:
    digest = hashlib.sha256()

    with path.open(
        "rb"
    ) as handle:
        for chunk in iter(
            lambda: handle.read(1024 * 1024),
            b"",
        ):
            digest.update(
                chunk
            )

    return digest.hexdigest()


# ============================================================================
# Translation
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

    relative = source.relative_to(
        formal_root
    )

    final_output_root = source_output_directory(
        source,
        formal_root,
        output_root,
    )

    if commit_output:
        final_output_root.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

    with tempfile.TemporaryDirectory(
        prefix="kipio-dafny-rs-"
    ) as temporary_directory:
        staging_root = (
            Path(temporary_directory)
            / source.stem
        )

        staging_root.mkdir(
            parents=True,
            exist_ok=True,
        )

        output_file = (
            staging_root
            / f"{source.stem}.rs"
        )

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
            command.append(
                "--include-runtime"
            )

        if emit_uncompilable_code:
            command.append(
                "--emit-uncompilable-code"
            )

        result = run(
            command,
            cwd=formal_root,
            capture=True,
        )

        generated_files = (
            collect_generated_files(
                staging_root
            )
        )

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
                    final_output_root
                    if commit_output
                    else None
                ),
                stdout=result.stdout,
                stderr=result.stderr,
                detail=(
                    "Dafny translation succeeded "
                    "but produced no files"
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
                    f"{len(generated_files)} staged file(s) "
                    f"discarded"
                ),
            )

        if final_output_root.exists():
            shutil.rmtree(
                final_output_root
            )

        shutil.copytree(
            staging_root,
            final_output_root,
        )

        final_files = collect_generated_files(
            final_output_root
        )

        return TranslationResult(
            source=relative,
            status="GENERATED",
            output_root=final_output_root,
            generated_files=final_files,
            stdout=result.stdout,
            stderr=result.stderr,
            detail=(
                f"generated {len(final_files)} file(s)"
            ),
        )


# ============================================================================
# Extern laboratory
# ============================================================================

EXTERN_LAB_SOURCE = Path(
    "foundation/Chain.dfy"
)

EXTERN_LAB_TYPE = "Chain"

DEFAULT_EXTERN_CANDIDATES = (
    ("control-no-extern", ""),
    ("extern-empty", "{:extern}"),
    ("extern-same-name", '{:extern "Chain"}'),
    ("extern-kipio-chain", '{:extern "KipioChain"}'),
    (
        "extern-qualified-chain",
        '{:extern "KipioAccountChain::Chain"}',
    ),
    (
        "extern-crate-chain",
        '{:extern "crate::Chain"}',
    ),
    ("extern-struct-hint", '{:extern "struct"}'),
    (
        "extern-two-args",
        '{:extern "KipioAccountChain", "Chain"}',
    ),
)


EXTERN_LAB_CONSUMER_SOURCE = Path(
    "ExternChainConsumer.dfy"
)

EXTERN_LAB_CONSUMER_MODULES = (
    "KipioExternLabConsumer",
    "KipioExternLabOpenedConsumer",
    "KipioExternLabQualifiedConsumer",
)

EXTERN_LAB_CONSUMER_FIXTURE = (
    Path(__file__).resolve().parent
    / "extern_lab"
    / "fixtures"
    / "ExternChainConsumer.dfy"
)

EXTERN_LAB_RUST_FIXTURE = (
    Path(__file__).resolve().parent
    / "extern_lab"
    / "fixtures"
    / "ExternChain.rs"
)

EXTERN_LAB_MODULE = "KipioAccountChain"


LAB_REPORT_DEFAULT = Path(
    "extern-lab-report.txt"
)

LAB_FILE_PREVIEW_MAX_CHARS = 12_000
LAB_REFERENCE_MAX_LINES = 120
LAB_COMMAND_OUTPUT_MAX_CHARS = 20_000


# ============================================================================
# Extern laboratory helpers
# ============================================================================

def normalize_extern_declaration(
    declaration: str,
) -> str:
    """
    Normalize an extern attribute for the laboratory.

    The empty declaration is a deliberate control case meaning:

        keep the original abstract type declaration unchanged.

    Non-empty declarations must be complete {:extern ...} attributes.
    """

    declaration = declaration.strip()

    if not declaration:
        return ""

    if not declaration.startswith("{:extern"):
        raise ValueError(
            f"invalid extern attribute: {declaration}"
        )

    if not declaration.endswith("}"):
        raise ValueError(
            f"invalid extern attribute: {declaration}"
        )

    return declaration


def replace_abstract_type_for_extern(
    source_text: str,
    *,
    type_name: str,
    extern_attribute: str,
) -> tuple[str, int]:
    """
    Replace exactly one abstract type declaration.

    Empty extern_attribute is the control case and leaves the declaration
    unchanged while still requiring exactly one matching declaration.
    """

    escaped_name = re.escape(type_name)

    pattern = re.compile(
        rf"(?m)^(?P<indentation>\s*)type\s+{escaped_name}"
        rf"(?P<characteristics>\([^)]*\))?"
        rf"(?P<suffix>\s*)$"
    )

    matches = list(
        pattern.finditer(
            source_text
        )
    )

    if len(matches) != 1:
        return source_text, len(matches)

    match = matches[0]

    if not extern_attribute:
        return source_text, 1

    indentation = match.group("indentation")
    characteristics = (
        match.group("characteristics")
        or ""
    )

    replacement = (
        f"{indentation}"
        f"type {extern_attribute} "
        f"{type_name}"
        f"{characteristics}"
    )

    transformed = (
        source_text[:match.start()]
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

    match = pattern.search(
        source_text
    )

    if not match:
        return None

    return match.group(0)


def load_extern_lab_consumer() -> str:
    text = EXTERN_LAB_CONSUMER_FIXTURE.read_text(
        encoding="utf-8"
    )

    if "import ChainModule = KipioAccountChain" not in text:
        raise RuntimeError(
            "extern lab consumer fixture does not contain "
            "the required module import"
        )

    return text


def load_extern_lab_rust_fixture() -> str:
    text = EXTERN_LAB_RUST_FIXTURE.read_text(
        encoding="utf-8"
    )

    required = (
        "pub struct Chain;",
        "impl ::dafny_runtime::DafnyPrint for Chain",
    )

    missing = [
        fragment
        for fragment in required
        if fragment not in text
    ]

    if missing:
        raise RuntimeError(
            "extern lab Rust fixture is incomplete; missing: "
            + ", ".join(missing)
        )

    return text


def truncate_for_report(
    text: str,
    *,
    max_chars: int,
) -> str:
    if len(text) <= max_chars:
        return text

    return (
        text[:max_chars]
        + "\n\n"
        + "... [TRUNCATED BY EXPORTER] ...\n"
        + f"original characters: {len(text)}\n"
    )


def classify_cargo_failure(
    stdout: str,
    stderr: str,
) -> str:
    """
    Distinguish Cargo/environment failures from compiler failures.

    This is intentionally conservative.

    Only obvious dependency-resolution, cache, registry, or network
    failures are classified as ENVIRONMENT_BLOCKED.

    Everything else is treated as an actual Cargo compilation failure.
    """

    text = (
        stdout
        + "\n"
        + stderr
    ).lower()

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

    if any(
        marker in text
        for marker in environment_markers
    ):
        return "ENVIRONMENT_BLOCKED"

    return "CARGO_COMPILE_ERROR"


def collect_full_generated_inspection(
    root: Path,
) -> GeneratedInspection:
    files = collect_generated_files(
        root
    )

    file_sizes: list[tuple[Path, int]] = []
    hashes: list[tuple[Path, str]] = []
    references: list[str] = []
    contents: list[str] = []

    for relative_file in files:
        absolute_file = root / relative_file

        try:
            size = absolute_file.stat().st_size
            text = absolute_file.read_text(
                encoding="utf-8",
                errors="replace",
            )
        except OSError as exc:
            file_sizes.append(
                (relative_file, -1)
            )
            hashes.append(
                (relative_file, "<unreadable>")
            )
            contents.append(
                f"--- {relative_file} ---\n"
                f"<unable to inspect: {exc}>"
            )
            continue

        file_sizes.append(
            (relative_file, size)
        )

        digest = hashlib.sha256(
            text.encode(
                "utf-8",
                errors="replace",
            )
        ).hexdigest()

        hashes.append(
            (relative_file, digest)
        )

        for line_number, line in enumerate(
            text.splitlines(),
            start=1,
        ):
            if (
                EXTERN_LAB_TYPE in line
                or EXTERN_LAB_MODULE in line
                or "ExternChainLab" in line
            ):
                references.append(
                    f"{relative_file}:{line_number}: {line}"
                )

        contents.append(
            f"--- {relative_file} ---\n"
            + truncate_for_report(
                text,
                max_chars=LAB_FILE_PREVIEW_MAX_CHARS,
            )
        )

    return GeneratedInspection(
        files=files,
        file_sizes=tuple(file_sizes),
        sha256=tuple(hashes),
        references=tuple(
            references[:LAB_REFERENCE_MAX_LINES]
        ),
        contents="\n\n".join(contents),
    )


# ============================================================================
# Rust diagnostics
# ============================================================================

def run_rustc_check(
    rust_file: Path,
    *,
    working_directory: Path,
) -> RustCompileResult:
    if shutil.which("rustc") is None:
        return RustCompileResult(
            status="NOT_AVAILABLE",
            detail="rustc was not found in PATH",
        )

    output_file = (
        working_directory
        / "rustc-check-output.rlib"
    )

    command = (
        "rustc",
        "--crate-type",
        "lib",
        "--edition",
        "2021",
        str(rust_file),
        "-o",
        str(output_file),
    )

    result = run_captured(
        list(command),
        cwd=working_directory,
    )

    return RustCompileResult(
        status=(
            "COMPILED"
            if result.returncode == 0
            else "FAILED"
        ),
        command=command,
        stdout=result.stdout,
        stderr=result.stderr,
        detail=(
            "rustc compilation succeeded"
            if result.returncode == 0
            else "rustc compilation failed"
        ),
        failure_class=(
            ""
            if result.returncode == 0
            else "RUSTC_COMPILE_ERROR"
        ),
    )


def run_cargo_check(
    generated_root: Path,
) -> RustCompileResult:
    if shutil.which("cargo") is None:
        return RustCompileResult(
            status="NOT_AVAILABLE",
            detail="cargo was not found in PATH",
        )

    cargo_files = tuple(
        path
        for path in generated_root.rglob("Cargo.toml")
        if path.is_file()
    )

    if not cargo_files:
        return RustCompileResult(
            status="NO_CARGO_MANIFEST",
            detail=(
                "generated artifacts contain no Cargo.toml; "
                "cargo check was not applicable"
            ),
        )

    manifest = cargo_files[0]

    command = (
        "cargo",
        "check",
        "--manifest-path",
        str(manifest),
        "--offline",
    )

    result = run_captured(
        list(command),
        cwd=manifest.parent,
    )

    failure_class = (
        ""
        if result.returncode == 0
        else classify_cargo_failure(
            result.stdout,
            result.stderr,
        )
    )

    return RustCompileResult(
        status=(
            "COMPILED"
            if result.returncode == 0
            else "FAILED"
        ),
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


# ============================================================================
# Extern cargo harness assembly
# ============================================================================

def prepare_extern_cargo_harness(
    *,
    harness_root: Path,
    generated_rust_source: Path,
    include_runtime_root: Path,
) -> str:
    """
    Assemble an isolated Cargo crate around the generated generic Rust.

    Strategy:
      1. Read the generated Rust file.
      2. Remove inner attributes (#![...]) — they are redundant because
         lib.rs already declares them at the crate root.
      3. Locate the *empty* `pub mod KipioAccountChain { }` that Dafny
         emits for the abstract extern type and fill it with the fixture
         body. This is REQUIRED because the generated code already
         declares that module; a separate module + re-export would
         collide with it.
      4. lib.rs simply includes the patched generated file.
    """
    runtime_root = (
        include_runtime_root
        / "ExternChainConsumer-rust"
        / "runtime"
    )

    if not runtime_root.is_dir():
        raise RuntimeError(
            "include-runtime output does not contain the expected "
            f"runtime package: {runtime_root}"
        )

    source_text = generated_rust_source.read_text(
        encoding="utf-8"
    )

    # Remove inner attributes so they don't error out inside include!().
    source_text = re.sub(
        r'^#!\[.*\]\s*\n',
        '',
        source_text,
        flags=re.MULTILINE,
    )

    # Fixture body (without the surrounding `pub mod ... { }`).
    fixture_body = (
        "    #[derive(Clone, Debug, PartialEq, Eq, Hash)]\n"
        "    pub struct Chain;\n"
        "\n"
        "    impl ::dafny_runtime::DafnyPrint for Chain {\n"
        "        fn fmt_print(\n"
        "            &self,\n"
        "            f: &mut ::std::fmt::Formatter<'_>,\n"
        "            _in_seq: bool,\n"
        "        ) -> ::std::fmt::Result {\n"
        "            write!(f, \"Chain\")\n"
        "        }\n"
        "    }\n"
    )

    # Match the EMPTY module emitted by Dafny.
    pattern = re.compile(
        r'pub mod KipioAccountChain\s*\{\s*\}'
    )

    if not pattern.search(source_text):
        raise RuntimeError(
            "could not find empty 'pub mod KipioAccountChain { }' "
            "in the generated Rust; the extern harness cannot "
            "proceed without it."
        )

    patched_source = pattern.sub(
        "pub mod KipioAccountChain {\n"
        + fixture_body
        + "}",
        source_text,
        count=1,
    )

    if harness_root.exists():
        shutil.rmtree(harness_root)

    harness_root.mkdir(parents=True, exist_ok=True)

    shutil.copytree(
        runtime_root,
        harness_root / "runtime",
    )

    generated_dir = harness_root / "generated"
    generated_dir.mkdir(parents=True, exist_ok=True)
    (generated_dir / "ExternChainConsumer.rs").write_text(
        patched_source,
        encoding="utf-8",
    )

    src_dir = harness_root / "src"
    src_dir.mkdir(parents=True, exist_ok=True)

    # lib.rs: the generated file is already self-contained
    # (it declares its own KipioAccountChain module, now populated).
    (src_dir / "lib.rs").write_text(
        """#![allow(warnings, unconditional_panic)]
#![allow(nonstandard_style)]
#![cfg_attr(any(), rustfmt::skip)]

include!("../generated/ExternChainConsumer.rs");
""",
        encoding="utf-8",
    )

    (harness_root / "Cargo.toml").write_text(
        """[package]
name = "kipio_extern_harness"
version = "0.1.0"
edition = "2021"

[dependencies]
dafny_runtime = { path = "runtime" }
""",
        encoding="utf-8",
    )

    return patched_source


def run_extern_cargo_harness(
    harness_root: Path,
) -> RustCompileResult:
    if shutil.which("cargo") is None:
        return RustCompileResult(
            status="NOT_AVAILABLE",
            detail="cargo was not found in PATH",
        )

    manifest = harness_root / "Cargo.toml"

    if not manifest.is_file():
        return RustCompileResult(
            status="NO_CARGO_MANIFEST",
            detail=(
                "extern Cargo harness manifest "
                "was not created"
            ),
        )

    command = (
        "cargo",
        "check",
        "--manifest-path",
        str(manifest),
        "--offline",
    )

    result = run_captured(
        list(command),
        cwd=harness_root,
    )

    failure_class = (
        ""
        if result.returncode == 0
        else classify_cargo_failure(
            result.stdout,
            result.stderr,
        )
    )

    return RustCompileResult(
        status=(
            "COMPILED"
            if result.returncode == 0
            else "FAILED"
        ),
        command=command,
        stdout=result.stdout,
        stderr=result.stderr,
        detail=(
            "extern Cargo harness compiled successfully"
            if result.returncode == 0
            else "extern Cargo harness compilation failed"
        ),
        failure_class=failure_class,
    )


def find_primary_generated_rust_file(
    inspection: GeneratedInspection,
) -> Path | None:
    preferred = [
        path
        for path in inspection.files
        if path.name.endswith(".rs")
        and "ExternChainConsumer" in path.name
    ]

    if preferred:
        return preferred[0]

    rust_files = [
        path
        for path in inspection.files
        if path.suffix == ".rs"
    ]

    if rust_files:
        return rust_files[0]

    return None


# ============================================================================
# Extern laboratory case execution
# ============================================================================

def run_extern_lab_case(
    *,
    formal_root: Path,
    candidate_id: str,
    attribute: str,
    output_root: Path,
) -> ExternLabResult:
    source = (
        formal_root
        / EXTERN_LAB_SOURCE
    )

    if not source.is_file():
        raise RuntimeError(
            "extern lab source does not exist: "
            f"{source}"
        )

    original_text = source.read_text(
        encoding="utf-8"
    )

    consumer_text = load_extern_lab_consumer()

    original_declaration = (
        find_single_type_declaration(
            original_text,
            EXTERN_LAB_TYPE,
        )
    )

    if original_declaration is None:
        raise RuntimeError(
            "extern lab could not find abstract type "
            f"{EXTERN_LAB_TYPE} in {EXTERN_LAB_SOURCE}"
        )

    extern_attribute = normalize_extern_declaration(
        attribute
    )

    with tempfile.TemporaryDirectory(
        prefix="kipio-extern-lab-"
    ) as temporary_directory:
        temporary_root = Path(
            temporary_directory
        )

        lab_root = (
            temporary_root
            / "formal"
        )

        shutil.copytree(
            formal_root,
            lab_root,
        )

        lab_source = (
            lab_root
            / EXTERN_LAB_SOURCE
        )

        lab_text = lab_source.read_text(
            encoding="utf-8"
        )

        transformed_text, match_count = (
            replace_abstract_type_for_extern(
                lab_text,
                type_name=EXTERN_LAB_TYPE,
                extern_attribute=extern_attribute,
            )
        )

        if match_count != 1:
            return ExternLabResult(
                candidate_id=candidate_id,
                attribute=attribute,
                verify_status="NOT_RUN",
                translate_status="NOT_RUN",
                detail=(
                    "expected exactly one abstract type "
                    f"declaration for {EXTERN_LAB_TYPE}; "
                    f"found {match_count}"
                ),
            )

        lab_source.write_text(
            transformed_text,
            encoding="utf-8",
        )

        consumer_source = (
            lab_root
            / EXTERN_LAB_CONSUMER_SOURCE
        )

        consumer_source.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        shutil.copyfile(
            EXTERN_LAB_CONSUMER_FIXTURE,
            consumer_source,
        )

        generated_root = (
            temporary_root
            / "generated"
        )

        generated_root.mkdir(
            parents=True,
            exist_ok=True,
        )

        transformed_declaration = (
            find_single_type_declaration(
                transformed_text,
                EXTERN_LAB_TYPE,
            )
        )

        original_sha256 = hashlib.sha256(
            original_text.encode(
                "utf-8"
            )
        ).hexdigest()

        transformed_sha256 = hashlib.sha256(
            transformed_text.encode(
                "utf-8"
            )
        ).hexdigest()

        verify_command = [
            "dafny",
            "verify",
            str(EXTERN_LAB_CONSUMER_SOURCE),
        ]

        verify_result = run_captured(
            verify_command,
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
                detail=(
                    "Dafny verification failed for the "
                    "temporary extern + consumer variant"
                ),
            )

        translation_root = (
            generated_root
            / "standard"
        )

        translation_root.mkdir(
            parents=True,
            exist_ok=True,
        )

        output_file = (
            translation_root
            / "ExternChainConsumer.rs"
        )

        translate_command = [
            "dafny",
            "translate",
            "rs",
            str(EXTERN_LAB_CONSUMER_SOURCE),
            "--output",
            str(output_file),
            "--enforce-determinism",
        ]

        translate_result = run_captured(
            translate_command,
            cwd=lab_root,
        )

        standard_inspection = (
            collect_full_generated_inspection(
                translation_root
            )
        )

        if translate_result.returncode != 0:
            return ExternLabResult(
                candidate_id=candidate_id,
                attribute=attribute,
                verify_status="OK",
                translate_status="FAILED",
                generated_files=standard_inspection.files,
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
                    "Dafny verification succeeded, "
                    "but standard Rust translation failed"
                ),
                original_declaration=original_declaration,
                transformed_declaration=transformed_declaration,
                original_sha256=original_sha256,
                transformed_sha256=transformed_sha256,
                generated_inspection=standard_inspection,
                standard_rustc=None,
                standard_cargo=None,
                include_runtime_cargo=None,
                harness_cargo=None,
                harness_source="",
                uncompilable_translation_status="NOT_RUN",
                uncompilable_stdout="",
                uncompilable_stderr="",
                uncompilable_inspection=None,
                uncompilable_rustc=None,
                include_runtime_translation_status="NOT_RUN",
                include_runtime_stdout="",
                include_runtime_stderr="",
                include_runtime_inspection=None,
                include_runtime_rustc=None,
                consumer_source=consumer_text,
            )

        primary_relative = (
            find_primary_generated_rust_file(
                standard_inspection
            )
        )

        standard_rustc = None

        if primary_relative is not None:
            standard_rustc = run_rustc_check(
                translation_root / primary_relative,
                working_directory=translation_root,
            )

        standard_cargo = run_cargo_check(
            translation_root
        )

        # --------------------------------------------------------------------
        # Second translation path:
        # --emit-uncompilable-code
        # --------------------------------------------------------------------

        uncompilable_root = (
            generated_root
            / "emit-uncompilable"
        )

        uncompilable_root.mkdir(
            parents=True,
            exist_ok=True,
        )

        uncompilable_output = (
            uncompilable_root
            / "ExternChainConsumer.rs"
        )

        uncompilable_command = [
            "dafny",
            "translate",
            "rs",
            str(EXTERN_LAB_CONSUMER_SOURCE),
            "--output",
            str(uncompilable_output),
            "--enforce-determinism",
            "--emit-uncompilable-code",
        ]

        uncompilable_result = run_captured(
            uncompilable_command,
            cwd=lab_root,
        )

        uncompilable_inspection = (
            collect_full_generated_inspection(
                uncompilable_root
            )
        )

        uncompilable_rustc = None

        uncompilable_primary = (
            find_primary_generated_rust_file(
                uncompilable_inspection
            )
        )

        if uncompilable_result.returncode == 0 and (
            uncompilable_primary is not None
        ):
            uncompilable_rustc = run_rustc_check(
                uncompilable_root / uncompilable_primary,
                working_directory=uncompilable_root,
            )

        # --------------------------------------------------------------------
        # Third translation path:
        # --include-runtime
        # --------------------------------------------------------------------

        include_runtime_root = (
            generated_root
            / "include-runtime"
        )

        include_runtime_root.mkdir(
            parents=True,
            exist_ok=True,
        )

        include_runtime_output = (
            include_runtime_root
            / "ExternChainConsumer.rs"
        )

        include_runtime_command = [
            "dafny",
            "translate",
            "rs",
            str(EXTERN_LAB_CONSUMER_SOURCE),
            "--output",
            str(include_runtime_output),
            "--enforce-determinism",
            "--include-runtime",
        ]

        include_runtime_result = run_captured(
            include_runtime_command,
            cwd=lab_root,
        )

        include_runtime_inspection = (
            collect_full_generated_inspection(
                include_runtime_root
            )
        )

        include_runtime_rustc = None

        include_runtime_primary = (
            find_primary_generated_rust_file(
                include_runtime_inspection
            )
        )

        if include_runtime_result.returncode == 0 and (
            include_runtime_primary is not None
        ):
            include_runtime_rustc = run_rustc_check(
                include_runtime_root / include_runtime_primary,
                working_directory=include_runtime_root,
            )

        include_runtime_cargo = run_cargo_check(
            include_runtime_root
        )

        harness_cargo = None
        harness_source = ""

        if (
            translate_result.returncode == 0
            and include_runtime_result.returncode == 0
            and primary_relative is not None
            and include_runtime_primary is not None
        ):
            harness_root = generated_root / "cargo-harness"

            try:
                harness_source = prepare_extern_cargo_harness(
                    harness_root=harness_root,
                    generated_rust_source=(
                        translation_root / primary_relative
                    ),
                    include_runtime_root=include_runtime_root,
                )

                harness_cargo = run_extern_cargo_harness(
                    harness_root
                )

            except (OSError, RuntimeError) as exc:
                harness_cargo = RustCompileResult(
                    status="FAILED",
                    detail=(
                        "unable to prepare extern Cargo harness: "
                        f"{exc}"
                    ),
                )

        return ExternLabResult(
            candidate_id=candidate_id,
            attribute=attribute,
            verify_status="OK",
            translate_status=(
                "OK"
                if translate_result.returncode == 0
                else "FAILED"
            ),
            generated_files=standard_inspection.files,
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
                "verification, translation, reference inspection, "
                "and additional Rust compilation experiments completed"
            ),
            original_declaration=original_declaration,
            transformed_declaration=transformed_declaration,
            original_sha256=original_sha256,
            transformed_sha256=transformed_sha256,
            generated_inspection=standard_inspection,
            standard_rustc=standard_rustc,
            standard_cargo=standard_cargo,
            include_runtime_cargo=include_runtime_cargo,
            harness_cargo=harness_cargo,
            harness_source=harness_source,
            uncompilable_translation_status=(
                "OK"
                if uncompilable_result.returncode == 0
                else "FAILED"
            ),
            uncompilable_stdout=truncate_for_report(
                uncompilable_result.stdout,
                max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
            ),
            uncompilable_stderr=truncate_for_report(
                uncompilable_result.stderr,
                max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
            ),
            uncompilable_inspection=uncompilable_inspection,
            uncompilable_rustc=uncompilable_rustc,
            include_runtime_translation_status=(
                "OK"
                if include_runtime_result.returncode == 0
                else "FAILED"
            ),
            include_runtime_stdout=truncate_for_report(
                include_runtime_result.stdout,
                max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
            ),
            include_runtime_stderr=truncate_for_report(
                include_runtime_result.stderr,
                max_chars=LAB_COMMAND_OUTPUT_MAX_CHARS,
            ),
            include_runtime_inspection=include_runtime_inspection,
            include_runtime_rustc=include_runtime_rustc,
            consumer_source=consumer_text,
        )


def parse_extern_candidates(
    raw_candidates: list[str] | None,
) -> list[tuple[str, str]]:
    if not raw_candidates:
        return list(
            DEFAULT_EXTERN_CANDIDATES
        )

    candidates: list[
        tuple[str, str]
    ] = []

    for index, value in enumerate(
        raw_candidates,
        start=1,
    ):
        if "=" in value:
            candidate_id, attribute = (
                value.split(
                    "=",
                    1,
                )
            )

            candidate_id = candidate_id.strip()
            attribute = attribute.strip()

            if not candidate_id:
                candidate_id = (
                    f"custom-{index}"
                )

        else:
            candidate_id = (
                f"custom-{index}"
            )

            attribute = value.strip()

        candidates.append(
            (
                candidate_id,
                attribute,
            )
        )

    return candidates


def format_compile_result(
    result: RustCompileResult | None,
) -> list[str]:
    if result is None:
        return [
            "status: NOT_RUN"
        ]

    lines = [
        f"status: {result.status}",
        f"detail: {result.detail}",
    ]

    if result.failure_class:
        lines.append(
            f"failure_class: {result.failure_class}"
        )

    if result.command:
        lines.append(
            "command: "
            + " ".join(result.command)
        )

    if result.stdout.strip():
        lines.extend(
            [
                "stdout:",
                *(
                    "  " + line
                    for line in result.stdout.strip().splitlines()
                ),
            ]
        )

    if result.stderr.strip():
        lines.extend(
            [
                "stderr:",
                *(
                    "  " + line
                    for line in result.stderr.strip().splitlines()
                ),
            ]
        )

    return lines


def format_generated_inspection(
    inspection: GeneratedInspection | None,
) -> list[str]:
    if inspection is None:
        return [
            "<not available>"
        ]

    lines: list[str] = []

    lines.append(
        "files:"
    )

    for relative_file in inspection.files:
        lines.append(
            f"  - {relative_file}"
        )

    lines.append(
        "sizes:"
    )

    for relative_file, size in inspection.file_sizes:
        lines.append(
            f"  - {relative_file}: {size} bytes"
        )

    lines.append(
        "sha256:"
    )

    for relative_file, digest in inspection.sha256:
        lines.append(
            f"  - {relative_file}: {digest}"
        )

    lines.append(
        "references:"
    )

    if inspection.references:
        lines.extend(
            f"  - {reference}"
            for reference in inspection.references
        )
    else:
        lines.append(
            "  - <no Chain/KipioAccountChain references found>"
        )

    lines.extend(
        [
            "contents:",
            inspection.contents or "<empty>",
        ]
    )

    return lines


# ============================================================================
# Extern laboratory report
# ============================================================================

def write_extern_lab_report(
    path: Path,
    *,
    formal_root: Path,
    dafny_version_value: str,
    results: list[ExternLabResult],
) -> None:
    translation_ok = sum(
        result.translate_status == "OK"
        for result in results
    )

    standard_compiled = sum(
        result.standard_rustc is not None
        and result.standard_rustc.status == "COMPILED"
        for result in results
    )

    include_runtime_compiled = sum(
        result.include_runtime_rustc is not None
        and result.include_runtime_rustc.status == "COMPILED"
        for result in results
    )

    lines = [
        "KIPIO DAFNY → RUST EXTERN COMPATIBILITY LAB REPORT",
        "===================================================",
        "",
        "PHASE: 1 — GENERIC RUST",
        "Stylus / Arbitrum integration: NOT EXECUTED",
        "",
        f"Formal root : {formal_root}",
        f"Dafny      : {dafny_version_value}",
        f"Source     : {EXTERN_LAB_SOURCE}",
        f"Type       : {EXTERN_LAB_TYPE}",
        f"Module     : {EXTERN_LAB_MODULE}",
        f"Consumer   : {EXTERN_LAB_CONSUMER_SOURCE}",
        "",
        f"Candidates tested              : {len(results)}",
        f"Standard translations OK       : {translation_ok}",
        f"Standard rustc compilations OK : {standard_compiled}",
        f"Include-runtime rustc OK       : {include_runtime_compiled}",
        "",
        "EXPERIMENT MATRIX — PHASE 1",
        "----------------------------",
        "",
        "For every extern candidate the laboratory runs:",
        "  1. isolated Dafny source transformation",
        "  2. Dafny verification",
        "  3. standard Rust translation",
        "  4. generated-file inspection",
        "  5. symbol/reference inspection",
        "  6. standalone rustc diagnostic",
        "  7. Cargo baseline diagnostic",
        "  8. temporary external-symbol Cargo harness",
        "  9. translation with --emit-uncompilable-code",
        " 10. rustc diagnostic for that output",
        " 11. translation with --include-runtime",
        " 12. rustc diagnostic for that output",
        "",
        "Cargo failure interpretation:",
        "  ENVIRONMENT_BLOCKED = dependency/cache/network problem",
        "  CARGO_COMPILE_ERROR = Cargo reached compilation and failed",
        "  RUSTC_COMPILE_ERROR  = standalone rustc failed",
        "",
        "Stylus / Arbitrum checkpoints are intentionally absent in Phase 1.",
        "",
    ]

    for result in results:
        lines.extend(
            [
                "=" * 80,
                f"CANDIDATE: {result.candidate_id}",
                "=" * 80,
                "",
                f"attribute: {result.attribute or '<control: no extern>'}",
                f"detail: {result.detail}",
                "",
                "ORIGINAL DECLARATION",
                "--------------------",
                result.original_declaration,
                "",
                "TRANSFORMED DECLARATION",
                "-----------------------",
                str(result.transformed_declaration),
                "",
                f"original_sha256: {result.original_sha256}",
                f"transformed_sha256: {result.transformed_sha256}",
                "",
                "CONSUMER SOURCE",
                "---------------",
                result.consumer_source,
                "",
                f"VERIFY STATUS: {result.verify_status}",
                "VERIFY STDOUT",
                "-------------",
                result.verify_stdout or "<empty>",
                "",
                "VERIFY STDERR",
                "-------------",
                result.verify_stderr or "<empty>",
                "",
                f"STANDARD TRANSLATION STATUS: {result.translate_status}",
                "STANDARD TRANSLATE STDOUT",
                "-------------------------",
                result.translate_stdout or "<empty>",
                "",
                "STANDARD TRANSLATE STDERR",
                "-------------------------",
                result.translate_stderr or "<empty>",
                "",
                "STANDARD GENERATED INSPECTION",
                "-------------------------------",
            ]
        )

        lines.extend(
            format_generated_inspection(
                result.generated_inspection
            )
        )

        lines.extend(
            [
                "",
                "STANDARD RUSTC",
                "--------------",
            ]
        )

        lines.extend(
            format_compile_result(
                result.standard_rustc
            )
        )

        lines.extend(
            [
                "",
                "STANDARD CARGO CHECK",
                "--------------------",
            ]
        )

        lines.extend(
            format_compile_result(
                result.standard_cargo
            )
        )

        lines.extend(
            [
                "",
                "INCLUDE-RUNTIME CARGO CHECK",
                "----------------------------",
            ]
        )

        lines.extend(
            format_compile_result(
                result.include_runtime_cargo
            )
        )

        lines.extend(
            [
                "",
                "EXTERN CARGO HARNESS",
                "--------------------",
                "fixture: tools/extern_lab/fixtures/ExternChain.rs",
                "source:",
                result.harness_source or "<not created>",
            ]
        )

        lines.extend(
            format_compile_result(
                result.harness_cargo
            )
        )

        lines.extend(
            [
                "",
                f"EMIT-UNCOMPILABLE TRANSLATION STATUS: "
                f"{result.uncompilable_translation_status}",
                "EMIT-UNCOMPILABLE STDOUT",
                "------------------------",
                result.uncompilable_stdout or "<empty>",
                "",
                "EMIT-UNCOMPILABLE STDERR",
                "------------------------",
                result.uncompilable_stderr or "<empty>",
                "",
                "EMIT-UNCOMPILABLE GENERATED INSPECTION",
                "---------------------------------------",
            ]
        )

        lines.extend(
            format_generated_inspection(
                result.uncompilable_inspection
            )
        )

        lines.extend(
            [
                "",
                "EMIT-UNCOMPILABLE RUSTC",
                "-----------------------",
            ]
        )

        lines.extend(
            format_compile_result(
                result.uncompilable_rustc
            )
        )

        lines.extend(
            [
                "",
                "INCLUDE-RUNTIME TRANSLATION STATUS: "
                f"{result.include_runtime_translation_status}",
                "INCLUDE-RUNTIME STDOUT",
                "--------------------",
                result.include_runtime_stdout or "<empty>",
                "",
                "INCLUDE-RUNTIME STDERR",
                "--------------------",
                result.include_runtime_stderr or "<empty>",
                "",
                "INCLUDE-RUNTIME GENERATED INSPECTION",
                "----------------------------------",
            ]
        )

        lines.extend(
            format_generated_inspection(
                result.include_runtime_inspection
            )
        )

        lines.extend(
            [
                "",
                "INCLUDE-RUNTIME RUSTC",
                "---------------------",
            ]
        )

        lines.extend(
            format_compile_result(
                result.include_runtime_rustc
            )
        )

        lines.append("")

    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    path.write_text(
        "\n".join(lines),
        encoding="utf-8",
    )


def print_extern_lab_summary(
    results: list[ExternLabResult],
) -> None:
    verification_ok = sum(
        result.verify_status == "OK"
        for result in results
    )

    translation_ok = sum(
        result.translate_status == "OK"
        for result in results
    )

    rustc_ok = sum(
        result.standard_rustc is not None
        and result.standard_rustc.status == "COMPILED"
        for result in results
    )

    cargo_ok = sum(
        result.standard_cargo is not None
        and result.standard_cargo.status == "COMPILED"
        for result in results
    )

    emit_translation_ok = sum(
        result.uncompilable_translation_status == "OK"
        for result in results
    )

    include_runtime_ok = sum(
        result.include_runtime_translation_status == "OK"
        for result in results
    )

    include_runtime_rustc_ok = sum(
        result.include_runtime_rustc is not None
        and result.include_runtime_rustc.status == "COMPILED"
        for result in results
    )

    include_runtime_cargo_ok = sum(
        result.include_runtime_cargo is not None
        and result.include_runtime_cargo.status == "COMPILED"
        for result in results
    )

    harness_cargo_ok = sum(
        result.harness_cargo is not None
        and result.harness_cargo.status == "COMPILED"
        for result in results
    )

    standard_cargo_environment_blocked = sum(
        result.standard_cargo is not None
        and result.standard_cargo.failure_class
        == "ENVIRONMENT_BLOCKED"
        for result in results
    )

    include_runtime_cargo_environment_blocked = sum(
        result.include_runtime_cargo is not None
        and result.include_runtime_cargo.failure_class
        == "ENVIRONMENT_BLOCKED"
        for result in results
    )

    harness_cargo_environment_blocked = sum(
        result.harness_cargo is not None
        and result.harness_cargo.failure_class
        == "ENVIRONMENT_BLOCKED"
        for result in results
    )

    print()
    print(
        "== Extern compatibility laboratory summary =="
    )
    print()

    print(
        f"Candidates tested                 : {len(results)}"
    )

    print(
        f"Dafny verify OK                   : {verification_ok}"
    )

    print(
        f"Standard translation OK            : {translation_ok}"
    )

    print(
        f"Standard rustc compilation OK      : {rustc_ok}"
    )

    print(
        f"Standard cargo check OK             : {cargo_ok}"
    )

    print(
        f"--emit-uncompilable-code translate : {emit_translation_ok}"
    )

    print(
        f"--include-runtime translate         : {include_runtime_ok}"
    )

    print(
        f"--include-runtime rustc OK          : {include_runtime_rustc_ok}"
    )

    print(
        f"--include-runtime cargo check OK    : {include_runtime_cargo_ok}"
    )

    print(
        f"Extern Cargo harness check OK        : {harness_cargo_ok}"
    )

    print(
        f"Standard Cargo environment-blocked   : "
        f"{standard_cargo_environment_blocked}"
    )

    print(
        f"Include-runtime Cargo environment-blocked: "
        f"{include_runtime_cargo_environment_blocked}"
    )

    print(
        f"Extern harness environment-blocked    : "
        f"{harness_cargo_environment_blocked}"
    )

    print()

    for result in results:
        print(
            f"[{result.candidate_id}]"
        )

        print(
            f"  verify               : {result.verify_status}"
        )

        print(
            f"  standard translate   : {result.translate_status}"
        )

        print(
            f"  standard rustc       : "
            f"{result.standard_rustc.status if result.standard_rustc else 'NOT_RUN'}"
        )

        print(
            f"  standard cargo      : "
            f"{result.standard_cargo.status if result.standard_cargo else 'NOT_RUN'}"
        )

        if result.standard_cargo is not None:
            print(
                f"  standard cargo class: "
                f"{result.standard_cargo.failure_class or 'NONE'}"
            )

        print(
            f"  emit-uncompilable   : "
            f"{result.uncompilable_translation_status}"
        )

        print(
            f"  include-runtime     : "
            f"{result.include_runtime_translation_status}"
        )

        print(
            f"  include-runtime rustc: "
            f"{result.include_runtime_rustc.status if result.include_runtime_rustc else 'NOT_RUN'}"
        )

        print(
            f"  include-runtime cargo: "
            f"{result.include_runtime_cargo.status if result.include_runtime_cargo else 'NOT_RUN'}"
        )

        print(
            f"  extern harness cargo: "
            f"{result.harness_cargo.status if result.harness_cargo else 'NOT_RUN'}"
        )

        if result.harness_cargo is not None:
            print(
                f"  extern harness class: "
                f"{result.harness_cargo.failure_class or 'NONE'}"
            )

    print()

    compiled_any = any(
        result.standard_rustc is not None
        and result.standard_rustc.status == "COMPILED"
        for result in results
    )

    if compiled_any:
        print(
            "At least one candidate produced Rust that passed rustc."
        )

    elif translation_ok:
        print(
            "Dafny translation succeeded, but the generated Rust "
            "has not yet passed rustc compilation."
        )


# ============================================================================
# Extern laboratory runner
# ============================================================================

def run_extern_lab(
    *,
    formal_root: Path,
    version: str,
    raw_candidates: list[str] | None,
    report_path: Path | None,
) -> int:
    candidates = parse_extern_candidates(
        raw_candidates
    )

    print()
    print(
        "== Extern compatibility laboratory =="
    )
    print()

    print(
        f"Source   : {EXTERN_LAB_SOURCE}"
    )

    print(
        f"Type     : {EXTERN_LAB_TYPE}"
    )

    print(
        f"Consumer : {EXTERN_LAB_CONSUMER_SOURCE}"
    )

    print(
        f"Candidates: {len(candidates)}"
    )

    print()
    print(
        "Real formal sources will NOT be modified."
    )

    print(
        "Each candidate runs inside an isolated temporary copy."
    )

    print()
    print(
        "Each candidate is exercised through verification, standard"
    )

    print(
        "translation, generated-code inspection, standalone rustc, cargo when"
    )

    print(
        "applicable, --emit-uncompilable-code, --include-runtime and the"
    )

    print(
        "temporary extern Cargo harness."
    )

    results: list[ExternLabResult] = []

    # The temporary generated root passed into each case is only a logical
    # namespace. Each actual case owns its own temporary workspace.
    temporary_namespace = Path(
        tempfile.mkdtemp(
            prefix="kipio-extern-lab-report-"
        )
    )

    try:
        for candidate_id, attribute in candidates:
            print()
            print(
                "=" * 72
            )
            print(
                f"Testing: {candidate_id}"
            )
            print(
                f"  attribute: "
                f"{attribute or '<control: no extern>'}"
            )

            result = run_extern_lab_case(
                formal_root=formal_root,
                candidate_id=candidate_id,
                attribute=attribute,
                output_root=(
                    temporary_namespace
                    / candidate_id
                ),
            )

            results.append(
                result
            )

            print(
                f"  verify            : {result.verify_status}"
            )

            print(
                f"  standard translate: {result.translate_status}"
            )

            print(
                f"  standard rustc    : "
                f"{result.standard_rustc.status if result.standard_rustc else 'NOT_RUN'}"
            )

            print(
                f"  standard cargo    : "
                f"{result.standard_cargo.status if result.standard_cargo else 'NOT_RUN'}"
            )

            if result.standard_cargo is not None:
                print(
                    f"  standard cargo class: "
                    f"{result.standard_cargo.failure_class or 'NONE'}"
                )

            print(
                f"  emit-uncompilable : "
                f"{result.uncompilable_translation_status}"
            )

            print(
                f"  include-runtime   : "
                f"{result.include_runtime_translation_status}"
            )

            print(
                f"  include-runtime rustc: "
                f"{result.include_runtime_rustc.status if result.include_runtime_rustc else 'NOT_RUN'}"
            )

        print_extern_lab_summary(
            results
        )

        if report_path is not None:
            write_extern_lab_report(
                report_path,
                formal_root=formal_root,
                dafny_version_value=version,
                results=results,
            )

            print(
                f"Extern lab report: {report_path}"
            )

    finally:
        shutil.rmtree(
            temporary_namespace,
            ignore_errors=True,
        )

    any_success = any(
        result.verify_status == "OK"
        and result.translate_status == "OK"
        for result in results
    )

    return 0 if any_success else 2


# ============================================================================
# Reports
# ============================================================================

def write_export_report(
    path: Path,
    *,
    formal_root: Path,
    output_root: Path,
    dafny_version_value: str,
    runtime_sources: list[Path],
    ordered_sources: list[Path],
    results: list[TranslationResult],
    structural_errors: list[str],
) -> None:
    generated = [
        result
        for result in results
        if result.status == "GENERATED"
    ]

    failed = [
        result
        for result in results
        if result.status == "FAILED"
    ]

    no_output = [
        result
        for result in results
        if result.status == "NO_OUTPUT"
    ]

    diagnostic_ok = [
        result
        for result in results
        if result.status == "DIAGNOSTIC_OK"
    ]

    diagnostic_failed = [
        result
        for result in results
        if result.status == "DIAGNOSTIC_FAILED"
    ]

    lines = [
        "KIPIO DAFNY → RUST EXPORT REPORT",
        "=================================",
        "",
        f"Formal root : {formal_root}",
        f"Output root : {output_root}",
        f"Dafny      : {dafny_version_value}",
        "",
        f"Runtime source files: {len(runtime_sources)}",
        f"Generated:            {len(generated)}",
        f"Failed:               {len(failed)}",
        f"No output:            {len(no_output)}",
        f"Diagnostic OK:        {len(diagnostic_ok)}",
        f"Diagnostic failed:    {len(diagnostic_failed)}",
        "",
        "RUNTIME LAYERS",
        "--------------",
        "",
    ]

    for layer in RUNTIME_LAYERS:
        count = sum(
            1
            for source in runtime_sources
            if source_layer(
                source,
                formal_root,
            ) == layer
        )

        lines.append(
            f"{layer}: {count}"
        )

    lines.extend(
        [
            "",
            "VERIFICATION-ONLY LAYERS",
            "------------------------",
            "",
        ]
    )

    for layer in VERIFICATION_ONLY_LAYERS:
        lines.append(
            f"{layer}: excluded from Rust materialization"
        )

    lines.extend(
        [
            "",
            "STRUCTURAL VALIDATION",
            "---------------------",
            "",
        ]
    )

    if structural_errors:
        lines.append(
            f"ERRORS: {len(structural_errors)}"
        )

        for error in structural_errors:
            lines.append(
                f"- {error}"
            )

    else:
        lines.append(
            "OK: dependency structure is export-compatible."
        )

    lines.extend(
        [
            "",
            "DEPENDENCY-FIRST PROCESSING ORDER",
            "---------------------------------",
            "",
        ]
    )

    for index, source in enumerate(
        ordered_sources,
        start=1,
    ):
        lines.append(
            f"{index:02d}. "
            f"{source.relative_to(formal_root)}"
        )

    lines.extend(
        [
            "",
            "TRANSLATION RESULTS",
            "-------------------",
            "",
        ]
    )

    for result in results:
        lines.append(
            f"[{result.status}] "
            f"{result.source}"
        )

        if result.output_root is not None:
            relative_output = (
                result.output_root.relative_to(
                    output_root
                )
            )

            lines.append(
                f"  output: {relative_output}"
            )

        if result.generated_files:
            lines.append(
                "  generated:"
            )

            for generated_file in result.generated_files:
                lines.append(
                    f"    - {generated_file}"
                )

        if result.detail:
            lines.append(
                f"  detail: {result.detail}"
            )

        if result.stdout.strip():
            lines.append(
                "  stdout:"
            )

            for line in result.stdout.strip().splitlines():
                lines.append(
                    f"    {line}"
                )

        if result.stderr.strip():
            lines.append(
                "  stderr:"
            )

            for line in result.stderr.strip().splitlines():
                lines.append(
                    f"    {line}"
                )

        lines.append("")

    lines.extend(
        [
            "SOURCE CHECKSUMS",
            "----------------",
            "",
        ]
    )

    for source in sorted(
        runtime_sources,
        key=lambda path: (
            path.relative_to(
                formal_root
            ).as_posix()
        ),
    ):
        digest = sha256_file(
            source
        )

        lines.append(
            f"{source.relative_to(formal_root)}"
        )

        lines.append(
            f"  sha256: {digest}"
        )

        lines.append("")

    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    path.write_text(
        "\n".join(lines),
        encoding="utf-8",
    )


# ============================================================================
# Console output
# ============================================================================

def print_plan(
    *,
    formal_root: Path,
    runtime_sources: list[Path],
    ordered_sources: list[Path],
) -> None:
    print()
    print(
        "== Runtime export plan =="
    )
    print()

    print(
        f"Runtime files: {len(runtime_sources)}"
    )

    print()

    for index, source in enumerate(
        ordered_sources,
        start=1,
    ):
        print(
            f"{index:02d}. "
            f"{source.relative_to(formal_root)}"
        )


def print_summary(
    *,
    runtime_sources: list[Path],
    results: list[TranslationResult],
    output_root: Path,
    report_path: Path,
) -> None:
    generated = sum(
        result.status == "GENERATED"
        for result in results
    )

    failed = sum(
        result.status == "FAILED"
        for result in results
    )

    no_output = sum(
        result.status == "NO_OUTPUT"
        for result in results
    )

    print()
    print(
        "== Export summary =="
    )
    print()

    print(
        f"Runtime sources : {len(runtime_sources)}"
    )

    print(
        f"Generated       : {generated}"
    )

    print(
        f"Failed          : {failed}"
    )

    print(
        f"No output       : {no_output}"
    )

    print(
        f"Output root     : {output_root}"
    )

    print(
        f"Report          : {report_path}"
    )


def print_diagnostic_summary(
    *,
    runtime_sources: list[Path],
    results: list[TranslationResult],
) -> None:
    passed = [
        result
        for result in results
        if result.status == "DIAGNOSTIC_OK"
    ]

    failed = [
        result
        for result in results
        if result.status == "DIAGNOSTIC_FAILED"
    ]

    no_output = [
        result
        for result in results
        if result.status == "NO_OUTPUT"
    ]

    print()
    print(
        "== Rust translation diagnostic =="
    )
    print()

    print(
        f"Runtime sources tested : {len(runtime_sources)}"
    )

    print(
        f"Translation OK         : {len(passed)}"
    )

    print(
        f"Translation failed     : {len(failed)}"
    )

    print(
        f"No output              : {len(no_output)}"
    )

    print()

    if passed:
        print(
            "== Translation-compatible =="
        )
        print()

        for result in passed:
            print(
                f"[OK]      {result.source}"
            )

    if failed:
        print()
        print(
            "== Translation failures =="
        )
        print()

        for result in failed:
            print(
                f"[FAILED]  {result.source}"
            )

            if result.detail:
                print(
                    f"          {result.detail}"
                )

    if no_output:
        print()
        print(
            "== Translation succeeded without output =="
        )
        print()

        for result in no_output:
            print(
                f"[NO OUTPUT] {result.source}"
            )

    print()

    if len(results) != len(
        runtime_sources
    ):
        print(
            "Diagnostic incomplete: not every runtime source "
            "was tested."
        )

        return

    if failed or no_output:
        print(
            "Diagnostic complete: review the failures before "
            "changing the Dafny model."
        )

    else:
        print(
            "Diagnostic complete: every runtime source "
            "translated successfully."
        )


# ============================================================================
# CLI
# ============================================================================

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Export the runtime layers of the Kipio "
            "Dafny domain to Rust."
        )
    )

    parser.add_argument(
        "--no-verify",
        action="store_true",
        help=(
            "skip repository-wide Dafny verification"
        ),
    )

    parser.add_argument(
        "--clean",
        action="store_true",
        help=(
            "remove the generated Dafny→Rust output before export"
        ),
    )

    parser.add_argument(
        "--plan",
        action="store_true",
        help=(
            "show the dependency-aware export plan and stop"
        ),
    )

    parser.add_argument(
        "--diagnose",
        action="store_true",
        help=(
            "translate every runtime source independently, "
            "continue after failures, and discard all generated output"
        ),
    )

    parser.add_argument(
        "--extern-lab",
        action="store_true",
        help=(
            "experiment with {:extern} representations for Chain "
            "inside isolated temporary Dafny project copies"
        ),
    )

    parser.add_argument(
        "--extern-candidate",
        action="append",
        help=(
            "custom extern-lab candidate. May be supplied multiple times. "
            "Format: id={:extern ...} or simply {:extern ...}"
        ),
    )

    parser.add_argument(
        "--extern-report",
        type=Path,
        help=(
            "write the extern-lab report to this path"
        ),
    )

    parser.add_argument(
        "--include-runtime",
        action="store_true",
        help=(
            "include the Dafny runtime in generated artifacts"
        ),
    )

    parser.add_argument(
        "--emit-uncompilable-code",
        action="store_true",
        help=(
            "allow Dafny to emit Rust identified as uncompilable"
        ),
    )

    return parser.parse_args()


# ============================================================================
# Main
# ============================================================================

def main() -> int:
    args = parse_args()

    selected_modes = sum(
        [
            args.plan,
            args.diagnose,
            args.extern_lab,
        ]
    )

    if selected_modes > 1:
        raise RuntimeError(
            "--plan, --diagnose and --extern-lab "
            "are mutually exclusive"
        )

    if args.extern_lab and (
        args.clean
        or args.include_runtime
        or args.emit_uncompilable_code
    ):
        raise RuntimeError(
            "--extern-lab cannot be combined with "
            "--clean, --include-runtime or "
            "--emit-uncompilable-code"
        )

    if args.diagnose and args.clean:
        raise RuntimeError(
            "--clean cannot be used with --diagnose because "
            "diagnostic mode never writes generated output"
        )

    formal_root = (
        Path(__file__)
        .resolve()
        .parent
        .parent
    )

    output_root = (
        formal_root
        / "generated"
        / "rust"
    ).resolve()

    report_path = (
        output_root
        / "export-report.txt"
    )

    require_tool(
        "dafny"
    )

    version = check_dafny_environment()

    # ------------------------------------------------------------------------
    # Extern laboratory
    # ------------------------------------------------------------------------

    if args.extern_lab:
        extern_report = (
            args.extern_report
            if args.extern_report is not None
            else (
                formal_root
                / "extern-lab-report.txt"
            )
        )

        if not extern_report.is_absolute():
            extern_report = (
                Path.cwd()
                / extern_report
            )

        return run_extern_lab(
            formal_root=formal_root,
            version=version,
            raw_candidates=args.extern_candidate,
            report_path=extern_report,
        )

    # ------------------------------------------------------------------------
    # Runtime source discovery
    # ------------------------------------------------------------------------

    runtime_sources = discover_runtime_sources(
        formal_root
    )

    if not runtime_sources:
        raise RuntimeError(
            "no runtime Dafny sources found"
        )

    classified = classify_sources(
        discover_all_sources(
            formal_root
        ),
        formal_root,
    )

    print()
    print(
        "KIPIO DAFNY → RUST EXPORT"
    )
    print(
        "========================="
    )
    print()
    print(
        f"Formal root  : {formal_root}"
    )
    print(
        f"Output root  : {output_root}"
    )
    print(
        f"Runtime files: {len(runtime_sources)}"
    )

    for layer in RUNTIME_LAYERS:
        print(
            f"  {layer:<15} "
            f"{len(classified[layer])}"
        )

    print()

    for layer in VERIFICATION_ONLY_LAYERS:
        print(
            f"  {layer:<15} "
            f"{len(classified[layer])} "
            f"(verification-only)"
        )

    (
        ordered_sources,
        structural_errors,
        _graph,
    ) = dependency_first_runtime_order(
        formal_root,
        runtime_sources,
    )

    print_plan(
        formal_root=formal_root,
        runtime_sources=runtime_sources,
        ordered_sources=ordered_sources,
    )

    if structural_errors:
        print()
        print(
            "== Structural export checks =="
        )
        print()

        for error in structural_errors:
            print(
                f"ERROR: {error}",
                file=sys.stderr,
            )

        return 2

    if args.plan:
        print()
        print(
            "Plan complete."
        )

        return 0

    if args.diagnose:
        print()
        print(
            "== Diagnostic translation of all runtime sources =="
        )
        print()
        print(
            "Generated artifacts will be discarded."
        )
        print(
            "Dafny verification is still controlled by --no-verify."
        )

        if not args.no_verify:
            verify_domain(
                formal_root
            )

        print()
        print(
            "Starting diagnostic translation..."
        )

        results: list[TranslationResult] = []

        for source in ordered_sources:
            print()
            print(
                f"Diagnosing: "
                f"{source.relative_to(formal_root)}"
            )

            result = translate_source(
                source,
                formal_root=formal_root,
                output_root=output_root,
                include_runtime=args.include_runtime,
                emit_uncompilable_code=(
                    args.emit_uncompilable_code
                ),
                commit_output=False,
            )

            results.append(
                result
            )

            if result.status == "DIAGNOSTIC_OK":
                print(
                    f"  OK — {result.detail}"
                )

            elif result.status == "NO_OUTPUT":
                print(
                    f"  NO OUTPUT — {result.detail}"
                )

            else:
                print(
                    "  FAILED"
                )

                if result.detail:
                    print(
                        f"  {result.detail}",
                        file=sys.stderr,
                    )

        print_diagnostic_summary(
            runtime_sources=runtime_sources,
            results=results,
        )

        return 0 if (
            len(results) == len(runtime_sources)
            and all(
                result.status == "DIAGNOSTIC_OK"
                for result in results
            )
        ) else 2

    # ------------------------------------------------------------------------
    # Normal export
    # ------------------------------------------------------------------------

    if args.clean:
        clean_output_root(
            output_root
        )

    output_root.mkdir(
        parents=True,
        exist_ok=True,
    )

    if not args.no_verify:
        verify_domain(
            formal_root
        )

    print()
    print(
        "== Dependency-aware Rust translation =="
    )
    print()

    results: list[TranslationResult] = []

    for source in ordered_sources:
        print()
        print(
            f"Translating: "
            f"{source.relative_to(formal_root)}"
        )

        result = translate_source(
            source,
            formal_root=formal_root,
            output_root=output_root,
            include_runtime=args.include_runtime,
            emit_uncompilable_code=(
                args.emit_uncompilable_code
            ),
            commit_output=True,
        )

        results.append(
            result
        )

        if result.status == "GENERATED":
            print(
                f"  OK — {result.detail}"
            )

        elif result.status == "NO_OUTPUT":
            print(
                f"  NO OUTPUT — {result.detail}"
            )

        else:
            print(
                "  FAILED"
            )

            if result.detail:
                print(
                    f"  {result.detail}",
                    file=sys.stderr,
                )

            print(
                "Stopping after first translation failure.",
                file=sys.stderr,
            )

            break

    write_export_report(
        report_path,
        formal_root=formal_root,
        output_root=output_root,
        dafny_version_value=version,
        runtime_sources=runtime_sources,
        ordered_sources=ordered_sources,
        results=results,
        structural_errors=structural_errors,
    )

    print_summary(
        runtime_sources=runtime_sources,
        results=results,
        output_root=output_root,
        report_path=report_path,
    )

    if any(
        result.status != "GENERATED"
        for result in results
    ):
        return 2

    if len(results) != len(
        runtime_sources
    ):
        print(
            "Export incomplete: not every runtime source "
            "was translated.",
            file=sys.stderr,
        )

        return 2

    print()
    print(
        "Rust export completed successfully."
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main()
    )
