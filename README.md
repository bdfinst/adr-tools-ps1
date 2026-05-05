# ADR Tools for PowerShell

A PowerShell port of [adr-tools](https://github.com/npryce/adr-tools) for creating and managing Architecture Decision Records (ADRs).

## Requirements

- PowerShell 5.1+

## Installation

### Option 1 — Run directly from a clone (no install required)

```powershell
git clone https://github.com/your-org/adr-tools-ps.git
# Add AdrTools/adr.ps1 to your PATH, or call it by full path:
pwsh /path/to/adr-tools-ps/AdrTools/adr.ps1 <command>
```

To use `adr` as a short alias in your shell session:

```powershell
Set-Alias adr "pwsh /path/to/adr-tools-ps/AdrTools/adr.ps1"
```

Add the alias to your `$PROFILE` to make it permanent.

### Option 2 — Import the module directly

```powershell
Import-Module /path/to/adr-tools-ps/AdrTools/AdrTools.psd1
```

The module exports: `Initialize-AdrDirectory`, `New-Adr`, `Get-AdrList`, `Set-AdrLink`, `Get-AdrToc`, `Get-AdrGraph`, `Update-AdrRepository`, `Get-AdrHelp`.

---

## Commands

All examples below assume you have the `adr` alias set up. Replace `adr` with the full script path if not.

---

### `adr init [DIRECTORY]`

Initialize an ADR directory. Creates the directory and writes the first record (`0001-record-architecture-decisions.md`).

```powershell
adr init            # uses default directory: doc/adr
adr init docs/adr   # use a custom directory
```

---

### `adr new TITLE [-s N]... [-l TARGET:LINK:REVERSE]...`

Create a new ADR with the given title. Returns the path of the created file.

```powershell
# Simple new ADR
adr new Use PostgreSQL as the primary database

# Supersede an existing ADR (by number or filename)
adr new Switch to SQLite -s 3

# Supersede multiple ADRs
adr new Switch to SQLite -s 3 -s 4

# Add an explicit directional link
adr new Add caching layer -l 5:"Extends":"Extended by"

# Combine supersede and link
adr new Replace Redis with Memcached -s 2 -l 3:"Amends":"Amended by"
```

**`-s N`** — Mark ADR number `N` (or filename) as superseded. Repeatable.

**`-l TARGET:LINK:REVERSE`** — Add a bidirectional link. `TARGET` is a number or filename. `LINK` is the label on the new ADR; `REVERSE` is the label written back on the target ADR. Repeatable.

The date defaults to today. Override it by setting `$env:ADR_DATE = 'yyyy-MM-dd'` before running.

---

### `adr list`

List all ADR files in the configured directory, one per line.

```powershell
adr list
# doc/adr/0001-record-architecture-decisions.md
# doc/adr/0002-use-postgresql.md
```

---

### `adr link SOURCE LINK TARGET REVERSE-LINK`

Add a bidirectional link between two existing ADRs. Arguments are positional.

```powershell
adr link 3 "Amends" 1 "Amended by"
# Writes "Amends [...]" into ADR 3
# Writes "Amended by [...]" into ADR 1
```

`SOURCE` and `TARGET` can be ADR numbers (`3`) or filenames (`0003-foo.md`).

---

### `adr generate toc [-p PREFIX] [-i INTRO] [-o OUTRO]`

Print a Markdown table of contents for all ADRs to stdout. Redirect to a file to save it.

```powershell
adr generate toc
adr generate toc -p "../adr/"          # prefix links with a path
adr generate toc -i intro.md -o outro.md  # wrap with intro/outro files
adr generate toc > doc/adr/README.md   # save to file
```

| Flag | Description |
|------|-------------|
| `-p PREFIX` | Prepend a path prefix to every file link |
| `-i FILE` | Insert the contents of FILE before the ADR list |
| `-o FILE` | Append the contents of FILE after the ADR list |

---

### `adr generate graph [-p PREFIX] [-e EXT]`

Print a [Graphviz](https://graphviz.org/) DOT graph of ADR relationships to stdout.

```powershell
adr generate graph
adr generate graph -p "../adr/" -e ".html"   # custom link prefix and extension
adr generate graph | dot -Tsvg > adr-graph.svg
```

| Flag | Description |
|------|-------------|
| `-p PREFIX` | Prepend a path prefix to every node URL |
| `-e EXT` | File extension for node URLs (default: `.html`) |

---

### `adr upgrade-repository`

Convert legacy `DD/MM/YYYY` dates in ADR files to ISO 8601 (`YYYY-MM-DD`). Only modifies files that contain the old format.

```powershell
adr upgrade-repository
```

---

### `adr help [COMMAND]`

Print help for all commands, or for a specific command.

```powershell
adr help
adr help new
adr help generate
```

---

## ADR File Format

ADR files are plain Markdown, numbered with zero-padded four-digit prefixes:

```
doc/adr/
  0001-record-architecture-decisions.md
  0002-use-postgresql.md
  0003-switch-to-sqlite.md
```

Each file follows this template:

```markdown
# N. Title

Date: YYYY-MM-DD

## Status

Accepted

## Context

...

## Decision

...

## Consequences

...
```

The format is compatible with the original `adr-tools` bash toolkit.

---

## Custom Templates

Place a `template.md` file inside your ADR directory to override the default template. The file must contain the tokens `NUMBER`, `TITLE`, `DATE`, and `STATUS` as literal strings — they are replaced when a new ADR is created.
