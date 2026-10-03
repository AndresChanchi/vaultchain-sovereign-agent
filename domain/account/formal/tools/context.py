#!/usr/bin/env python3

from pathlib import Path
import re
import subprocess
import sys


# ============================================================
# Configuration
# ============================================================

SCRIPT_DIR = Path(__file__).resolve().parent
FORMAL_ROOT = SCRIPT_DIR.parent.resolve()


# ============================================================
# Path normalization
# ============================================================

def normalize_path(value):
    """
    Normalize a path coming from arbitrary text.

    Examples:

        ./authority/Credential.dfy
        /authority/Credential.dfy
        authority\\Credential.dfy
        `authority/Credential.dfy`

    become:

        authority/Credential.dfy
    """

    value = value.strip()

    value = value.strip(
        "`'\".,:;()[]{}<>"
    )

    value = value.replace(
        "\\",
        "/",
    )

    # Remove leading ./ repeatedly.
    while value.startswith("./"):
        value = value[2:]

    # The input may contain /authority/...
    # even though the project-relative path is
    # authority/...
    value = value.lstrip("/")

    return value


# ============================================================
# File discovery
# ============================================================

def find_dfy_files():
    """
    Discover every real .dfy file below FORMAL_ROOT.

    The filesystem is the source of truth.

    No .dfy filename or directory is hardcoded.
    """

    files = sorted(
        (
            path
            for path in FORMAL_ROOT.rglob("*")
            if path.is_file()
            and path.suffix.lower() == ".dfy"
        ),
        key=lambda path: str(
            path.relative_to(FORMAL_ROOT)
        ).lower(),
    )

    by_name = {}

    for path in files:
        by_name.setdefault(
            path.name.lower(),
            [],
        ).append(path)

    by_relative_path = {}

    for path in files:
        relative = path.relative_to(
            FORMAL_ROOT
        )

        normalized = normalize_path(
            str(relative)
        )

        by_relative_path[
            normalized.lower()
        ] = path

    return (
        files,
        by_name,
        by_relative_path,
    )


# ============================================================
# Windows / WSL2 clipboard
# ============================================================

def read_clipboard():
    """Read the Windows clipboard from WSL2."""

    try:
        result = subprocess.run(
            [
                "win32yank.exe",
                "-o",
                "--lf",
            ],
            capture_output=True,
            text=True,
            check=True,
        )

        return result.stdout

    except FileNotFoundError:
        print()
        print(
            "❌ No encontré win32yank.exe."
        )
        print()
        print(
            "Verifica que win32yank.exe esté disponible "
            "desde WSL2."
        )
        print()

        sys.exit(1)

    except subprocess.CalledProcessError as exc:
        print()
        print(
            f"❌ No pude leer el clipboard: {exc}"
        )
        print()

        sys.exit(1)


def write_clipboard(text):
    """Write text to the Windows clipboard from WSL2."""

    try:
        subprocess.run(
            [
                "win32yank.exe",
                "-i",
                "--crlf",
            ],
            input=text,
            text=True,
            check=True,
        )

    except FileNotFoundError:
        print()
        print(
            "❌ No encontré win32yank.exe."
        )
        print()
        print(
            "Verifica que win32yank.exe esté disponible "
            "desde WSL2."
        )
        print()

        sys.exit(1)

    except subprocess.CalledProcessError as exc:
        print()
        print(
            f"❌ No pude escribir al clipboard: {exc}"
        )
        print()

        sys.exit(1)


# ============================================================
# Input
# ============================================================

def read_input():
    """
    Read a COMPLETE pasted block.

    Interactive mode is intentionally multiline.

    The user finishes the input with EOF:

        Ctrl+D

    This prevents the shell from receiving the remaining
    lines as commands.

    If stdin is piped, all stdin is consumed automatically.
    """

    if not sys.stdin.isatty():
        return sys.stdin.read()

    print()
    print(
        "Pega aquí el texto que contiene los archivos .dfy."
    )
    print(
        "Cuando termines, presiona Ctrl+D."
    )
    print()

    try:
        return sys.stdin.read()

    except KeyboardInterrupt:
        print()
        print()
        print(
            "❌ Input cancelado."
        )
        print()

        return ""


# ============================================================
# Candidate extraction
# ============================================================

def extract_path_candidates(text):
    """
    Extract path-like tokens from arbitrary text.

    This is intentionally generic.

    It does NOT contain knowledge of specific .dfy files.

    Examples detected:

        authority/Credential.dfy
        account/AccountTransitions.dfy
        authorization/Authorization.dfy
        ./authority/Credential.dfy
        authority\\Credential.dfy
        Account.dfy

    Tokens without .dfy are also allowed because we later
    validate them against the real filesystem.

    This allows:

        account/Account

    to resolve to:

        account/Account.dfy

    when that file actually exists.
    """

    pattern = re.compile(
        r"""
        (?<![\w])
        (?:
            \.?[/\\]
        )?
        [A-Za-z0-9_.-]+
        (?:
            [/\\][A-Za-z0-9_.-]+
        )*
        (?:\.dfy)?
        (?![\w])
        """,
        re.VERBOSE,
    )

    candidates = []
    seen = set()

    for match in pattern.finditer(text):

        candidate = normalize_path(
            match.group(0)
        )

        if not candidate:
            continue

        # Ignore obvious non-path words.
        if "/" not in candidate and "\\" not in match.group(0):
            if not candidate.lower().endswith(".dfy"):
                continue

        key = candidate.lower()

        if key not in seen:
            seen.add(key)
            candidates.append(candidate)

    return candidates


# ============================================================
# Resolve candidates against discovered files
# ============================================================

def resolve_candidate(
    candidate,
    by_name,
    by_relative_path,
):
    """
    Resolve a candidate using the dynamically discovered
    filesystem.

    Resolution order:

        1. Exact relative path.
        2. Exact relative path + .dfy
        3. Filename.
        4. Filename + .dfy

    Returns:

        ("found", Path)
        ("missing", None)
        ("ambiguous", list[Path])
    """

    normalized = normalize_path(
        candidate
    )

    if not normalized:
        return "missing", None

    lower = normalized.lower()

    # --------------------------------------------------------
    # Exact relative path
    # --------------------------------------------------------

    exact = by_relative_path.get(
        lower
    )

    if exact is not None:
        return "found", exact

    # --------------------------------------------------------
    # Relative path without .dfy
    # --------------------------------------------------------

    if not lower.endswith(".dfy"):

        exact_with_extension = (
            lower + ".dfy"
        )

        exact = by_relative_path.get(
            exact_with_extension
        )

        if exact is not None:
            return "found", exact

    # --------------------------------------------------------
    # Filename lookup
    # --------------------------------------------------------

    filename = Path(
        normalized
    ).name.lower()

    matches = by_name.get(
        filename,
        [],
    )

    if matches:

        if len(matches) == 1:
            return "found", matches[0]

        return "ambiguous", matches

    # --------------------------------------------------------
    # Filename lookup without .dfy
    # --------------------------------------------------------

    if not filename.endswith(".dfy"):

        filename_with_extension = (
            filename + ".dfy"
        )

        matches = by_name.get(
            filename_with_extension,
            [],
        )

        if matches:

            if len(matches) == 1:
                return "found", matches[0]

            return "ambiguous", matches

    return "missing", None


# ============================================================
# Resolve input
# ============================================================

def resolve_input(
    text,
    by_name,
    by_relative_path,
):
    """
    Resolve all real .dfy files referenced by the input.

    Important:

    The input is NOT interpreted as shell commands.

    It is only treated as text containing file references.
    """

    candidates = extract_path_candidates(
        text
    )

    selected = []
    selected_keys = set()

    missing = []
    ambiguous = []

    for candidate in candidates:

        status, result = resolve_candidate(
            candidate,
            by_name,
            by_relative_path,
        )

        if status == "found":

            key = str(
                result.resolve()
            ).lower()

            if key not in selected_keys:

                selected_keys.add(key)
                selected.append(result)

        elif status == "ambiguous":

            ambiguous.append(
                (
                    candidate,
                    result,
                )
            )

        else:

            # Only report candidates that actually look
            # like file references.
            normalized = normalize_path(
                candidate
            )

            if (
                "/" in normalized
                or normalized.lower().endswith(".dfy")
            ):
                missing.append(
                    candidate
                )

    return (
        selected,
        missing,
        ambiguous,
    )


# ============================================================
# Build context
# ============================================================

def build_context(files):
    """
    Build the final context.

    Files are kept in the order in which they appeared
    in the user's input.
    """

    output = [
        "Aqui contexto:",
        "",
    ]

    for index, path in enumerate(
        files,
        start=1,
    ):

        relative = path.relative_to(
            FORMAL_ROOT
        )

        try:
            content = path.read_text(
                encoding="utf-8"
            )

        except UnicodeDecodeError:

            print()
            print(
                f"❌ No pude leer como UTF-8: "
                f"{relative}"
            )
            print()

            sys.exit(1)

        output.append(
            f"{index}. {relative}:"
        )

        output.append(
            content.rstrip()
        )

        output.append("")

    return (
        "\n".join(output).rstrip()
        + "\n"
    )


# ============================================================
# Reports
# ============================================================

def print_ambiguous(
    identifier,
    matches,
):
    """Report an ambiguous file reference."""

    print()
    print(
        f"⚠️ Referencia ambigua: {identifier}"
    )
    print()
    print(
        "Encontré varias coincidencias:"
    )
    print()

    for match in matches:

        print(
            "   - "
            f"{match.relative_to(FORMAL_ROOT)}"
        )

    print()


# ============================================================
# Main
# ============================================================

def main():

    print()
    print(
        "╭────────────────────────────────────────────╮"
    )
    print(
        "│       Formal Context Clipboard             │"
    )
    print(
        "╰────────────────────────────────────────────╯"
    )
    print()

    # --------------------------------------------------------
    # Discover EVERYTHING dynamically
    # --------------------------------------------------------

    (
        all_files,
        by_name,
        by_relative_path,
    ) = find_dfy_files()

    print(
        f"Encontrados {len(all_files)} archivos .dfy"
    )

    if not all_files:

        print()
        print(
            "❌ No encontré archivos .dfy."
        )
        print(
            "Busqué dentro de:"
        )
        print(
            f"   {FORMAL_ROOT}"
        )
        print()

        return

    # --------------------------------------------------------
    # Read multiline input
    # --------------------------------------------------------

    print()
    print(
        "Leyendo input..."
    )

    source_text = read_input()

    if not source_text.strip():

        print()
        print(
            "❌ No recibí ningún input."
        )
        print()

        return

    # --------------------------------------------------------
    # Resolve references
    # --------------------------------------------------------

    (
        selected,
        missing,
        ambiguous,
    ) = resolve_input(
        source_text,
        by_name,
        by_relative_path,
    )

    # --------------------------------------------------------
    # Nothing found
    # --------------------------------------------------------

    if not selected:

        print()
        print(
            "❌ No pude resolver ningún archivo."
        )

        if missing:

            print()
            print(
                "Referencias no encontradas:"
            )

            for identifier in missing:

                print(
                    f"   - {identifier}"
                )

        if ambiguous:

            print()
            print(
                "Referencias ambiguas:"
            )

            for identifier, matches in ambiguous:

                print(
                    f"   - {identifier}"
                )

                for match in matches:

                    print(
                        "       "
                        f"{match.relative_to(FORMAL_ROOT)}"
                    )

        print()

        return

    # --------------------------------------------------------
    # Report selected
    # --------------------------------------------------------

    print()
    print(
        f"✓ Resueltos {len(selected)} "
        f"archivos .dfy:"
    )

    print()

    for index, path in enumerate(
        selected,
        start=1,
    ):

        print(
            f"  {index}. "
            f"{path.relative_to(FORMAL_ROOT)}"
        )

    # --------------------------------------------------------
    # Report missing
    # --------------------------------------------------------

    if missing:

        print()
        print(
            f"⚠️ No encontré {len(missing)} "
            f"referencia(s):"
        )

        for identifier in missing:

            print(
                f"   - {identifier}"
            )

    # --------------------------------------------------------
    # Report ambiguous
    # --------------------------------------------------------

    if ambiguous:

        for identifier, matches in ambiguous:

            print_ambiguous(
                identifier,
                matches,
            )

    # --------------------------------------------------------
    # Build context
    # --------------------------------------------------------

    context = build_context(
        selected
    )

    # --------------------------------------------------------
    # Copy result
    # --------------------------------------------------------

    write_clipboard(
        context
    )

    # --------------------------------------------------------
    # Success
    # --------------------------------------------------------

    print()
    print(
        "✓ Contexto generado y copiado "
        "al clipboard."
    )

    print(
        f"  Archivos incluidos: {len(selected)}"
    )

    print()

    if missing or ambiguous:

        print(
            "⚠️ El contexto se generó con "
            "las referencias que sí pudieron resolverse."
        )
        print()

    print()


# ============================================================
# Entry point
# ============================================================

if __name__ == "__main__":
    main()
