# Plan: adr-tools PowerShell Port

**Created**: 2026-05-05
**Branch**: main
**Status**: implemented

## Goal

Port the complete `adr-tools` bash CLI to a PowerShell module (`AdrTools`) that runs identically on PowerShell 5.1 and PowerShell 7.x with no external dependencies. All seven commands (`init`, `new`, `list`, `link`, `generate toc`, `generate graph`, `help`, `upgrade-repository`) will be implemented with full file-format parity so ADR directories remain compatible with the original bash tooling. The module is structured for installation via `$env:PSModulePath` and driven by a thin `adr.ps1` CLI dispatcher.

## Architecture Decisions (pre-implementation)

### Pester version
PS5.1 ships Pester 3.4.0, which has an incompatible DSL (no `BeforeAll`/`AfterAll`, no `-ForEach`, different `Should` semantics). All tests are written against **Pester 5.x**. Step 1 creates `tools/pester-bootstrap.ps1` that installs Pester 5.x into `tools/Pester/` from the PowerShell Gallery and sets `$env:PSModulePath` to include it. CI and local test runs both source this script before invoking Pester.

### Encoding and line endings
A single private function `Write-AdrFile` wraps all file writes. It uses `[System.IO.File]::WriteAllText(path, content, New-Object System.Text.UTF8Encoding($false))` to produce UTF-8 with no BOM. Line endings are normalized to LF (`\n`) before writing regardless of platform. No `Set-Content` or `Out-File` is used in the module — all writes go through `Write-AdrFile`.

### Path separators
Internal path construction uses `Join-Path`. Markdown links written into ADR files always use forward slashes (`/`) regardless of platform, matching the bash tool's output. The `adr list` command outputs full paths using the OS separator (as `Join-Path` produces) — this is correct CLI behavior.

### `New-Adr` parameter sets
```powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position=0, ValueFromRemainingArguments)]
    [string[]]$Title,

    [Alias('s')]
    [string[]]$Supersedes = @(),

    [Alias('l')]
    [string[]]$Link = @()
)
```
`-Supersedes` and `-Link` can both appear together freely. No `ParameterSetName` separation needed since they are independently repeatable.

### Atomicity / fail-fast for multi-file operations
`New-Adr -Supersedes` and `adr link` both update multiple files. The strategy is **fail-fast before any write**: resolve all target ADR files and validate they exist *before* creating the new ADR or modifying anything. If any resolution fails, the command errors with a clear message and exits non-zero — no files are touched. This eliminates partial-write corruption for the most common failure mode (bad target number). Disk errors mid-write are not rolled back (no temp-file-rename pattern) but are documented as a known limitation.

### Error message conventions
All user-facing errors are written via `Write-Error -Category <category> -Message "<Actionable message>"` in functions, or `[Console]::Error.WriteLine(...)` in `adr.ps1`. All error paths exit with a non-zero exit code. `adr.ps1` wraps calls in a `try/catch` and sets `exit 1` on any terminating error. The standard error message format is: `"<What went wrong>. <What to do next>."` — e.g., `"No ADR directory found. Run 'adr init' to create one."`.

### `Get-AdrStatusBounds` return value contract
`Get-AdrStatusBounds` returns `@{StartIndex = <int>; EndIndex = <int>}` where both are **zero-based indices into the `$Lines` array**:
- `StartIndex`: index of the first line after the `## Status` heading
- `EndIndex`: index of the last line **included** in the section (inclusive upper bound)
- For an EOF-terminated Status section (no subsequent `##` heading): `EndIndex = $Lines.Count - 1`
- For an empty section (next `##` immediately follows `## Status`): `StartIndex > EndIndex` — callers detect this as "empty"

Splice operations use `$Lines[0..($StartIndex-1)] + $insertedLines + $Lines[$StartIndex..$EndIndex] + $Lines[($EndIndex+1)..($Lines.Count-1)]`.

### Reading files with potential BOM (PS5.1 compatibility)
`Get-Content` on PS5.1 returns a leading `U+FEFF` (BOM) character in the first string when reading a UTF-8-with-BOM file written by external editors (VS Code, Notepad). All functions that read line 0 of a file (`Get-AdrTitle`, `Get-AdrStatusBounds`) must strip a leading `[char]0xFEFF` before processing. Use: `$line.TrimStart([char]0xFEFF)`.

### PS5.1 / PS7 compatibility constraints
- No ternary operators (`a ? b : c` — PS7 only); use `if/else`
- No null-coalescing assignment (`??=` — PS7 only)
- No `ForEach-Object -Parallel`
- No `Set-Content -Encoding utf8NoBOM` (PS7 only) — use `Write-AdrFile` exclusively
- No `[IO.File]::WriteAllLines`, `Add-Content`, `>` or `>>` redirection in module code — all writes via `Write-AdrFile`
- Use `Join-Path` for all path construction
- `$PSScriptRoot` works in both editions

### `adr.ps1` early dispatcher stub
The dispatcher is created in Step 1 as a stub that imports the module and prints "Not yet implemented" for all commands. Each subsequent public-function step wires its command into the dispatcher. This makes every step shippable and validates dispatch integration continuously.

---

## Acceptance Criteria

- [ ] AC-1: All commands run without error in Windows PowerShell 5.1
- [ ] AC-2: All commands run without error in PowerShell 7.x (Windows, macOS, Linux)
- [ ] AC-3: ADR files match bash tool format: 4-digit zero-padded filename, no BOM, LF line endings, ISO date, `# N. Title` heading, `Accepted` status. Validated by byte-level comparison against a golden fixture.
- [ ] AC-4: No runtime external dependencies — only PowerShell standard library and BCL types (Pester is a test-only dependency)
- [ ] AC-5: All target ADRs validated before any file is created; if validation fails, no files are written. Disk errors during write are a documented known limitation.
- [ ] AC-6: `adr generate graph` output validated by `dot -Tsvg` when Graphviz is available; otherwise validated by structural regex checks against expected nodes and edges
- [ ] AC-7: Pester 5.x test suite passes on both PS5.1 and PS7; all Gherkin scenarios have corresponding named tests
- [ ] AC-8: `ADR_TEMPLATE` env var and `templates/template.md` in the ADR directory both override the built-in template
- [ ] AC-9: `adr list` from a subdirectory finds `.adr-dir` in a parent directory
- [ ] AC-10: `Import-Module AdrTools` succeeds after copying the module folder to any `$env:PSModulePath` directory

## User-Facing Behavior

```gherkin
Feature: adr init - Initialize ADR directory

  Scenario: Initialize with default directory
    Given no ADR directory exists in the current project
    When I run "adr init"
    Then the directory "doc/adr" is created
    And ".adr-dir" is written containing the path "doc/adr"
    And "doc/adr/0001-record-architecture-decisions.md" is created
    And the first ADR's Status section contains "Accepted"
    And no editor is opened

  Scenario: Initialize with a custom directory path
    Given no ADR directory exists
    When I run "adr init decisions"
    Then the directory "decisions" is created
    And ".adr-dir" is written containing "decisions"
    And "decisions/0001-record-architecture-decisions.md" is created

  Scenario: Re-initialize without clobbering existing ADRs
    Given ".adr-dir" already exists pointing to "doc/adr"
    And "doc/adr" contains existing ADR files
    When I run "adr init"
    Then the existing ADR files are unchanged
    And ".adr-dir" still points to "doc/adr"
    And the command exits with code 0

Feature: adr new - Create a new ADR

  Scenario: Create a new ADR with a plain title
    Given an ADR directory containing 3 existing ADRs
    When I run "adr new Use PostgreSQL for the database"
    Then "0004-use-postgresql-for-the-database.md" is created in the ADR directory
    And the file begins with "# 4. Use PostgreSQL for the database"
    And the file contains today's date in YYYY-MM-DD format
    And the file's Status section contains "Accepted"
    And the file contains sections "## Context", "## Decision", "## Consequences"
    And the new file path is printed to stdout

  Scenario: Title is slugified - special characters replaced with hyphens
    When I run "adr new Use React.js & TypeScript"
    Then the filename slug is "use-react-js-typescript"
    And the filename contains no leading or trailing hyphens

  Scenario: adr new without prior adr init
    Given no ADR directory exists and no ".adr-dir" file exists
    When I run "adr new My Decision"
    Then the error "No ADR directory found. Run 'adr init' to create one." is written to stderr
    And the exit code is non-zero
    And no file is created

  Scenario: Supersede a single existing ADR by number
    Given "0002-use-mysql.md" exists with Status "Accepted"
    When I run "adr new Replace MySQL with SQLite -s 2"
    Then a new ADR is created
    And the new ADR's Status contains "Supercedes [Use MySQL](0002-use-mysql.md)"
    And "0002-use-mysql.md" Status no longer contains "Accepted"
    And "0002-use-mysql.md" Status contains "Superceded by [Replace MySQL with SQLite](<new-filename>.md)"

  Scenario: Supersede multiple ADRs in one command
    Given ADRs 0002 and 0003 both exist with Status "Accepted"
    When I run "adr new Consolidated approach -s 2 -s 3"
    Then the new ADR's Status links supercede both ADR 2 and ADR 3
    And both 0002 and 0003 have their Status updated with "Superceded by" links

  Scenario: Supersede a non-existent ADR number
    Given no ADR with number 99 exists
    When I run "adr new My Decision -s 99"
    Then the error "ADR 99 not found." is written to stderr
    And the exit code is non-zero
    And no new ADR file is created

  Scenario: Create ADR with an explicit directional link
    Given "0003-use-rest.md" exists
    When I run "adr new Add GraphQL Layer -l '3:Amends:Amended by'"
    Then the new ADR's Status contains "Amends [Use REST](0003-use-rest.md)"
    And "0003-use-rest.md" Status contains "Amended by [Add GraphQL Layer](<new-filename>.md)"

  Scenario: Resolve superseded ADR by partial filename match
    Given "0005-use-postgres.md" exists
    When I run "adr new Switch to SQLite -s postgres"
    Then the new ADR supercedes "0005-use-postgres.md"

  Scenario: Override creation date via environment variable
    Given ADR_DATE is set to "2020-01-15"
    When I run "adr new My Decision"
    Then the new ADR contains "Date: 2020-01-15"

Feature: adr list - List all ADRs

  Scenario: List all ADR files
    Given the ADR directory contains "0001-...", "0002-...", "0003-..." files
    When I run "adr list"
    Then the full paths to all three files are printed, one per line, in ascending order
    And the exit code is 0

  Scenario: No ADR directory configured
    Given no ".adr-dir" file exists and no "doc/adr" directory exists
    When I run "adr list"
    Then the error "No ADR directory found. Run 'adr init' to create one." is written to stderr
    And the exit code is non-zero

Feature: adr link - Add directional links between two existing ADRs

  Scenario: Link two ADRs bidirectionally
    Given "0002-logging.md" and "0005-tracing.md" both exist
    When I run "adr link 2 'Amends' 5 'Amended by'"
    Then "0002-logging.md" Status contains "Amends [<title of 0005>](0005-tracing.md)"
    And "0005-tracing.md" Status contains "Amended by [<title of 0002>](0002-logging.md)"

  Scenario: Link target does not exist
    Given only "0002-logging.md" exists
    When I run "adr link 2 'Amends' 99 'Amended by'"
    Then the error "ADR 99 not found." is written to stderr
    And the exit code is non-zero
    And "0002-logging.md" is unchanged

Feature: adr generate toc - Generate a Markdown table of contents

  Scenario: Basic table of contents
    Given an ADR directory with 3 ADRs
    When I run "adr generate toc"
    Then stdout begins with "# Architecture Decision Records"
    And each ADR appears as "* [<Title>](<filename.md>)"

  Scenario: TOC with a link prefix
    When I run "adr generate toc -p /docs/decisions/"
    Then each link href is prefixed with "/docs/decisions/"

  Scenario: TOC with intro and outro files
    Given "intro.md" and "outro.md" exist with known content
    When I run "adr generate toc -i intro.md -o outro.md"
    Then intro.md content appears after the heading
    And outro.md content appears at the end of the output

  Scenario: Intro file does not exist
    When I run "adr generate toc -i missing.md"
    Then the error "Intro file 'missing.md' not found." is written to stderr
    And the exit code is non-zero

  Scenario: Outro file does not exist
    When I run "adr generate toc -o missing.md"
    Then the error "Outro file 'missing.md' not found." is written to stderr
    And the exit code is non-zero

Feature: adr generate graph - Generate a Graphviz DOT graph

  Scenario: Generate DOT format output
    Given an ADR directory where ADR 2 has a link to ADR 3 in its Status section
    When I run "adr generate graph"
    Then stdout is valid DOT format beginning with "digraph {"
    And each ADR is represented as a node with shape "plaintext"
    And ADR 2 and ADR 3 have a directed edge labeled with the link type
    And sequential ADRs are connected with dotted weight-1 edges
    And reverse-link lines (containing " by") are not emitted as separate edges

  Scenario: Graph with URL prefix and extension
    When I run "adr generate graph -p /adr/ -e .html"
    Then each node URL uses the prefix and extension

Feature: adr upgrade-repository - Normalize date format

  Scenario: Convert DD/MM/YYYY dates to ISO 8601
    Given an ADR file contains "Date: 15/01/2020"
    When I run "adr upgrade-repository"
    Then the file is rewritten with "Date: 2020-01-15"

  Scenario: Leave ISO 8601 dates unchanged
    Given an ADR file contains "Date: 2020-01-15"
    When I run "adr upgrade-repository"
    Then the file is unchanged

Feature: adr help - Display usage information

  Scenario: List available commands
    When I run "adr help"
    Then all available command names are printed

  Scenario: Show help for a specific command
    When I run "adr help new"
    Then usage information specific to the "new" command is shown
    And the output includes "-s" and "-l" flag descriptions with format examples

Feature: ADR directory resolution

  Scenario: Walk up directory tree to find .adr-dir
    Given ".adr-dir" exists two levels above the current directory
    When I run any adr command from a subdirectory
    Then the ADR directory named in the ancestor ".adr-dir" is used

  Scenario: Fall back to doc/adr when no .adr-dir is found
    Given no ".adr-dir" exists but "doc/adr" exists
    When I run "adr list"
    Then "doc/adr" is used as the ADR directory

Feature: Custom ADR templates

  Scenario: Use a custom template from the ADR directory
    Given "templates/template.md" exists inside the ADR directory
    When I run "adr new My Decision"
    Then the new ADR is generated from the custom template

  Scenario: Override template via ADR_TEMPLATE environment variable
    Given ADR_TEMPLATE is set to the path of a custom template file
    When I run "adr new My Decision"
    Then the new ADR is generated from the file at ADR_TEMPLATE
```

## Steps

### Step 1: Module scaffold, Pester 5.x bootstrap, and `adr.ps1` stub dispatcher

**Complexity**: standard
**RED**: Write a Pester 5.x test asserting:
- `Import-Module ./AdrTools/AdrTools.psd1 -Force` succeeds without error
- The loaded Pester version is `>= 5.0.0`
- `& pwsh ./AdrTools/adr.ps1 help` exits 0 (stub produces some output)
- `& pwsh ./AdrTools/adr.ps1 unknowncommand` exits non-zero
**GREEN**:
- Create `tools/pester-bootstrap.ps1`: saves Pester 5.x to `tools/Pester/` via `Save-Module -Name Pester -MinimumVersion 5.0.0 -Path tools/Pester` if not already present; adds to `$env:PSModulePath`
- Create `AdrTools/AdrTools.psd1` (CompatiblePSEditions: Desktop,Core; PowerShellVersion: 5.1; RootModule: AdrTools.psm1; FunctionsToExport: @())
- Create `AdrTools/AdrTools.psm1` that dot-sources all `.ps1` files in `Private/` then `Public/`
- Create stub `AdrTools/adr.ps1` dispatcher: imports module, `switch ($args[0])` with `'help' { "adr help" }`, `default { Write-Error "Unknown command: $($args[0])"; exit 1 }`
- Create directory skeleton: `AdrTools/Private/`, `AdrTools/Public/`, `AdrTools/templates/`
- Create `Tests/` directory and `Tests/Module.Tests.ps1`
**REFACTOR**: None needed
**Files**: `tools/pester-bootstrap.ps1`, `AdrTools/AdrTools.psd1`, `AdrTools/AdrTools.psm1`, `AdrTools/adr.ps1`, `Tests/Module.Tests.ps1`
**Commit**: `feat: scaffold AdrTools module, Pester 5.x bootstrap, and adr.ps1 stub`

---

### Step 2: `Write-AdrFile` — UTF-8 no-BOM, LF-normalized file writer

**Complexity**: standard
**RED**: Pester tests asserting:
- `Write-AdrFile -Path $path -Content "hello`nworld"` creates the file
- Reading back `[System.IO.File]::ReadAllBytes($path)[0..2]` does NOT equal `0xEF, 0xBB, 0xBF` (no BOM)
- All line endings in the written file are `0x0A` only (no `0x0D`)
- Overwriting an existing file replaces content correctly
- Called with CRLF input (`"a`r`nb"`), output contains only LF
- Called with bare-CR input (`"a`rb"`), output contains only LF (both CR and CRLF normalized)
**GREEN**: Implement `Private/Write-AdrFile.ps1` — normalize both CRLF and bare-CR to LF before writing:
  ```powershell
  function Write-AdrFile {
      param([string]$Path, [string]$Content)
      $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
      $normalized = $Content -replace "`r`n", "`n" -replace "`r", "`n"
      [System.IO.File]::WriteAllText($Path, $normalized, $utf8NoBom)
  }
  ```
**REFACTOR**: None needed
**Files**: `AdrTools/Private/Write-AdrFile.ps1`, `Tests/Private/Write-AdrFile.Tests.ps1`
**Commit**: `feat: implement Write-AdrFile with UTF-8 no-BOM and LF normalization`

---

### Step 3: Slug generation (`New-AdrSlug`)

**Complexity**: standard
**RED**: Pester tests:
- `"Use PostgreSQL for the database"` → `"use-postgresql-for-the-database"`
- `"Use React.js & TypeScript"` → `"use-react-js-typescript"` (non-alphanumeric → `-`, collapsed)
- `"  Leading spaces  "` → no leading or trailing hyphens in result
- `"Already-Slugged"` → `"already-slugged"` (lowercased)
- `"---Multiple---Hyphens---"` → `"multiple-hyphens"` (consecutive hyphens collapsed, then trimmed)
- Non-ASCII characters: `"Ångström"` → slug contains only ASCII a-z 0-9 and hyphens (anything non-ASCII is treated like a non-alphanumeric and replaced with `-`)
**GREEN**: Implement `Private/New-AdrSlug.ps1`:
  - lowercase the input
  - `-replace '[^a-z0-9]+', '-'`
  - `.Trim('-')`
**REFACTOR**: Verify `-replace` operator uses the same semantics in PS5.1 and PS7 (it does — both use .NET regex)
**Files**: `AdrTools/Private/New-AdrSlug.ps1`, `Tests/Private/New-AdrSlug.Tests.ps1`
**Commit**: `feat: implement New-AdrSlug for title-to-filename conversion`

---

### Step 4: Next ADR number sequencing (`Get-NextAdrNumber`)

**Complexity**: standard
**RED**: Pester tests using `TestDrive:`:
- Empty directory → returns `[int]1`, no exception
- Directory containing `0001-`, `0002-`, `0003-*.md` → returns `[int]4`
- Sparse directory (only `0001-*.md` and `0005-*.md`) → returns `[int]6`
- Directory with non-ADR files (e.g., `README.md`, `templates/`) → only counts `NNNN-*.md` files, returns `[int]1`
- Path does not exist → throws a terminating error with message containing "does not exist"
- Path is a file not a directory → throws a terminating error
- Directory containing `0000-*.md` → treated as max=0, returns `[int]1` (1-based numbering preserved)
**GREEN**: Implement `Private/Get-NextAdrNumber.ps1`: validate path exists and is a directory; use `Get-ChildItem -Path $AdrDir -Filter '[0-9][0-9][0-9][0-9]-*.md'`; parse leading 4-digit prefix as int; sort descending; return max+1 or 1
**REFACTOR**: None needed
**Files**: `AdrTools/Private/Get-NextAdrNumber.ps1`, `Tests/Private/Get-NextAdrNumber.Tests.ps1`
**Commit**: `feat: implement Get-NextAdrNumber for ADR sequence tracking`

---

### Step 5: ADR directory resolution (`Get-AdrDirectory`)

**Complexity**: standard
**RED**: Pester tests using `TestDrive:` and `Push-Location`/`Pop-Location`:
- `.adr-dir` in current directory containing `"doc/adr"` → returns `"doc/adr"`
- `.adr-dir` two levels above current working directory → returns the path inside it (walk-up works)
- No `.adr-dir` anywhere, but `doc/adr` subdirectory exists → returns `(Join-Path $PWD 'doc/adr')`
- No `.adr-dir` and no `doc/adr` → throws terminating error with message `"No ADR directory found. Run 'adr init' to create one."`
- `.adr-dir` is present but unreadable (simulated by writing a file then removing read permission via `[System.IO.File]::SetAttributes`) → error is re-thrown with a message containing the path; test skipped on Windows where ACL simulation is complex (use `[System.PlatformID]::Unix` guard)
**GREEN**: Implement `Private/Get-AdrDirectory.ps1`: walk from `$PWD` up to root using `Split-Path -Parent`, check for `.adr-dir` at each level; if found, `Get-Content` its first line (wrapped in try/catch for access errors); if walk exhausted, check for `doc/adr`; else throw
**REFACTOR**: None needed
**Files**: `AdrTools/Private/Get-AdrDirectory.ps1`, `Tests/Private/Get-AdrDirectory.Tests.ps1`
**Commit**: `feat: implement Get-AdrDirectory with .adr-dir walk-up and doc/adr fallback`

---

### Step 6: Status section boundary finder (`Get-AdrStatusBounds`)

**Complexity**: complex
**RED**: Pester tests using in-memory string arrays (no disk I/O needed). All return values follow the contract in Architecture Decisions (`EndIndex` is the zero-based index of the last included line; `StartIndex > EndIndex` signals empty section):
- Standard file: `## Status` at line 6, next `##` at line 10 → returns `@{StartIndex=7; EndIndex=9}`
- Status section is the last section (no trailing `##`): 20-line file, `## Status` at line 15, no subsequent `##` → `@{StartIndex=16; EndIndex=19}` (i.e., `$Lines.Count - 1 = 19`)
- Status section has no content (next `##` immediately after `## Status`) → `@{StartIndex=7; EndIndex=6}` (empty range: `StartIndex > EndIndex`)
- File with no `## Status` heading → throws terminating error: `"No '## Status' section found in file: <path>"`
- `## Status` heading has trailing whitespace (`## Status  `) → still matched (`.TrimEnd()` comparison)
- File uses CRLF (`## Status\r\n`) → matched after BOM/CRLF stripping of the input lines
- Blank lines within Status section are included in the range
**GREEN**: Implement `Private/Get-AdrStatusBounds.ps1`: accept `[string[]]$Lines` and `[string]$Path` (for error messages); scan for index where `$line.TrimEnd() -eq '## Status'`; then scan forward for next line starting with `## `; return hashtable `@{StartIndex=<first line after heading>; EndIndex=<last line before next heading or EOF>}`
**REFACTOR**: None needed — this is the load-bearing parser; keep it simple
**Files**: `AdrTools/Private/Get-AdrStatusBounds.ps1`, `Tests/Private/Get-AdrStatusBounds.Tests.ps1`
**Commit**: `feat: implement Get-AdrStatusBounds for Status section boundary detection`

---

### Step 7: Read-only file metadata helpers (`Resolve-AdrFile`, `Get-AdrTitle`, `Get-AdrStatus`, `Get-AdrLinks`)

**Complexity**: standard
**RED**: Pester tests:
- `Resolve-AdrFile -Ref "2" -AdrDir $dir` → returns full path to `0002-*.md`
- `Resolve-AdrFile -Ref "0002" -AdrDir $dir` → same (zero-padded input)
- `Resolve-AdrFile -Ref "postgres" -AdrDir $dir` where `0005-use-postgres.md` exists → returns that path
- `Resolve-AdrFile -Ref "99" -AdrDir $dir` where no ADR 99 exists → throws `"ADR 99 not found."`
- `Resolve-AdrFile` with a reference matching multiple files → returns first match (lowest number)
- `Get-AdrTitle -Path $file` where first line is `"# 4. Use PostgreSQL"` → returns `"Use PostgreSQL"`
- **BOM fixture**: `Get-AdrTitle` on a file whose bytes start with `0xEF 0xBB 0xBF # 4. Use PostgreSQL` → returns `"Use PostgreSQL"` (not `"﻿# 4. Use PostgreSQL"` with embedded BOM)
- `Get-AdrTitle` on a file with CRLF first line → returns title with no trailing `\r`
- `Get-AdrStatus -Path $file` → returns the string lines between `## Status` and next `##`, not including blank lines at boundaries
- `Get-AdrLinks -Path $file` with `Status` containing `"Amends [Use REST](0003-use-rest.md)"` → returns `@{Number=3; LinkType='Amends'}`
- `Get-AdrLinks` skips lines where `LinkType` ends in `" by"` (reverse links: "Superceded by", "Amended by")
- `Get-AdrLinks` on a file with no links in Status → returns empty array, no error
**GREEN**: Implement all four functions using `Get-Content` and `Get-AdrStatusBounds`. In `Get-AdrTitle` and wherever line 0 is inspected, strip leading BOM: `$line = $line.TrimStart([char]0xFEFF)`. `Get-AdrLinks` regex: `'^(\S+.*?)\s+\[.*?\]\((\d{4})-.*?\.md\)'`; filter out matches where captured group 1 ends with `' by'` (case-insensitive)
**REFACTOR**: None needed
**Files**: `AdrTools/Private/Resolve-AdrFile.ps1`, `AdrTools/Private/Get-AdrTitle.ps1`, `AdrTools/Private/Get-AdrStatus.ps1`, `AdrTools/Private/Get-AdrLinks.ps1`, `Tests/Private/AdrFileHelpers.Tests.ps1`
**Commit**: `feat: implement file resolution, title/status extraction, and link parsing helpers`

---

### Step 8: Status section in-place editors (`Add-AdrLink`, `Remove-AdrStatusText`)

**Complexity**: standard
**RED**: Pester tests using `TestDrive:`:
- `Add-AdrLink -Path $file -LinkText "Amends [Title](0003-file.md)"` inserts that line at the end of the `## Status` section, before the next `##` heading
- `Add-AdrLink` when Status section already has content: new line appended after existing Status lines
- `Add-AdrLink` when `## Status` is the last section (no following `##`): line appended; file does not grow a trailing `##`
- Written file has no BOM (first 3 bytes ≠ `0xEF 0xBB 0xBF`)
- Written file has LF line endings only
- `Remove-AdrStatusText -Path $file -Text "Accepted"` removes exactly that line from Status section
- `Remove-AdrStatusText` when text is not present → file unchanged (no error)
- Link text in markdown links uses forward slashes regardless of input
**GREEN**: Both functions: `Get-Content $Path`; call `Get-AdrStatusBounds`; splice the line array; call `Write-AdrFile`
**REFACTOR**: None needed
**Files**: `AdrTools/Private/Add-AdrLink.ps1`, `AdrTools/Private/Remove-AdrStatusText.ps1`, `Tests/Private/StatusEditing.Tests.ps1`
**Commit**: `feat: implement Status section in-place editors (Add-AdrLink, Remove-AdrStatusText)`

---

### Step 9: Built-in ADR templates and golden-file fixture

**Complexity**: trivial
**RED**:
- Test that `AdrTools/templates/template.md` exists relative to `$PSScriptRoot`
- Test that it contains tokens `NUMBER`, `TITLE`, `DATE`, `STATUS`
- Test that `AdrTools/templates/init.md` exists and contains `DATE`
- **Golden-file test**: test that token substitution of `template.md` with known values produces a byte-identical result to `Tests/Fixtures/golden-adr.md` (committed reference output)
**GREEN**:
- Create `AdrTools/templates/template.md` matching the original bash tool format exactly
- Create `AdrTools/templates/init.md` for ADR #1
- Create `Tests/Fixtures/golden-adr.md` as the reference output (LF line endings, no BOM)
- Add a `.gitattributes` entry: `Tests/Fixtures/golden-adr.md -text` to prevent git from normalizing line endings on Windows checkout, preserving the byte-level reference
- Add a comment in `Tests/Templates.Tests.ps1`: `# To regenerate golden-adr.md: delete it, run New-Adr with fixed ADR_DATE, copy the output here.`
**REFACTOR**: None needed
**Files**: `AdrTools/templates/template.md`, `AdrTools/templates/init.md`, `Tests/Fixtures/golden-adr.md`, `.gitattributes`, `Tests/Templates.Tests.ps1`
**Commit**: `feat: add built-in ADR templates and golden-file fixture`

---

### Step 10: Template resolution (`Resolve-AdrTemplate`) and `adr init` (`Initialize-AdrDirectory`)

**Complexity**: standard
**RED**: Pester tests:
- `Resolve-AdrTemplate -AdrDir $dir` returns built-in `template.md` path when no override exists
- `Resolve-AdrTemplate` with `$env:ADR_TEMPLATE` set to a valid path → returns that path
- `Resolve-AdrTemplate` with `<adr-dir>/templates/template.md` present → returns that path (takes priority over built-in)
- `Resolve-AdrTemplate` with `$env:ADR_TEMPLATE` pointing to a missing file → throws `"Template file not found: <path>"`
- `Initialize-AdrDirectory` with no argument: creates `doc/adr/`, writes `.adr-dir` containing `"doc/adr"`, creates `0001-record-architecture-decisions.md` with `Accepted` in Status
- `Initialize-AdrDirectory -Directory "decisions"`: creates `decisions/`, writes `.adr-dir` containing `"decisions"`
- Re-init (`.adr-dir` exists, ADR files exist): existing files unchanged, exit 0
- Created ADR file has no BOM, LF endings (via `Write-AdrFile`)
- No editor process is spawned (assert no `Start-Process` calls via mock)
- `adr init` wired in `adr.ps1`: `& pwsh adr.ps1 init` exits 0 and creates `doc/adr/`
**GREEN**:
- Implement `Private/Resolve-AdrTemplate.ps1`
- Implement `Public/Initialize-AdrDirectory.ps1` — create dir, write `.adr-dir`, resolve init template, substitute `DATE` token, call `Write-AdrFile`
- Wire `'init'` case in `adr.ps1`
- Add `Initialize-AdrDirectory` to `FunctionsToExport` in `AdrTools.psd1`
**REFACTOR**: None needed
**Files**: `AdrTools/Private/Resolve-AdrTemplate.ps1`, `AdrTools/Public/Initialize-AdrDirectory.ps1`, `AdrTools/adr.ps1`, `AdrTools/AdrTools.psd1`, `Tests/Public/Initialize-AdrDirectory.Tests.ps1`
**Commit**: `feat: implement adr init command`

---

### Step 11: `adr new` — basic creation (`New-Adr`, no linking)

**Complexity**: complex
**RED**: Pester tests:
- `New-Adr -Title "Use PostgreSQL"` in a dir with 3 ADRs → creates `0004-use-postgresql.md` with `# 4. Use PostgreSQL` heading
- Filename uses 4-digit zero-padded number; heading uses bare integer
- File contains today's ISO date; `$env:ADR_DATE = "2020-01-15"` overrides it
- Status section contains `Accepted` only
- File has sections `## Context`, `## Decision`, `## Consequences`
- `New-Adr` returns/outputs the created file path
- Custom template via `$env:ADR_TEMPLATE`: all 4 tokens substituted; no token literals remain in output
- Custom template via `<adr-dir>/templates/template.md`: used in preference to built-in
- `New-Adr` in a dir with no ADR directory configured → error `"No ADR directory found. Run 'adr init' to create one."`, exit non-zero, no file created
- File has no BOM, LF line endings
- `adr new` wired in `adr.ps1`
**GREEN**: Implement `Public/New-Adr.ps1` with params `[string[]]$Title, [string[]]$Supersedes=@(), [string[]]$Link=@()` (parameters declared now, linking implemented in later steps); call `Get-AdrDirectory`, `Get-NextAdrNumber`, `New-AdrSlug`, `Resolve-AdrTemplate`; substitute tokens; call `Write-AdrFile`; output path
**REFACTOR**: None needed — linking params are declared but ignored at this step; no dead-code risk
**Files**: `AdrTools/Public/New-Adr.ps1`, `AdrTools/adr.ps1`, `AdrTools/AdrTools.psd1`, `Tests/Public/New-Adr.Basic.Tests.ps1`
**Commit**: `feat: implement adr new command (basic creation, no linking)`

---

### Step 12: `adr new` — supersedes (`-s` / `-Supersedes`)

**Complexity**: complex
**RED**: Pester tests:
- `New-Adr -Title "Replace" -Supersedes @("2")` when `0002-use-mysql.md` exists with Status `Accepted`:
  - New ADR Status contains `"Supercedes [Use MySQL](0002-use-mysql.md)"` (forward slash in link)
  - `0002-use-mysql.md` Status no longer contains `"Accepted"`
  - `0002-use-mysql.md` Status contains `"Superceded by [Replace](NNNN-replace.md)"` (*note*: intentional misspelling matches bash tool for format parity)
- Multiple `-Supersedes @("2","3")`: both old ADRs updated
- Supersede by partial name match (`"postgres"` resolves to `0005-use-postgres.md`)
- Supersede by zero-padded reference (`"0002"` resolves to ADR 2)
- **Fail-fast**: `-Supersedes @("99")` when ADR 99 doesn't exist → error `"ADR 99 not found."`, exit non-zero, **no new ADR file created** (resolution happens before any write)
**GREEN**: In `New-Adr.ps1`, before creating the new file: resolve all `-Supersedes` refs via `Resolve-AdrFile` (fail-fast if any missing); after creating the new file, call `Remove-AdrStatusText` then `Add-AdrLink` on each superseded ADR, and `Add-AdrLink` on the new ADR
**REFACTOR**: None needed
**Files**: `AdrTools/Public/New-Adr.ps1`, `Tests/Public/New-Adr.Supersedes.Tests.ps1`
**Commit**: `feat: implement adr new -s supersedes flag with fail-fast validation`

---

### Step 13: `adr new` — explicit links (`-l` / `-Link`)

**Complexity**: standard
**RED**: Pester tests:
- `-Link @("3:Amends:Amended by")` when `0003-use-rest.md` exists:
  - New ADR Status contains `"Amends [Use REST](0003-use-rest.md)"`
  - `0003-use-rest.md` Status contains `"Amended by [<new title>](<new-file>.md)"`
- Multiple `-Link` entries all applied
- Combined `-Supersedes` and `-Link` in one call: both applied correctly
- **Fail-fast**: `-Link @("99:Amends:Amended by")` when ADR 99 doesn't exist → error, exit non-zero, no file created
- Invalid triple format (missing `:` separators) → error `"Invalid -Link format. Expected 'TARGET:LINK:REVERSE-LINK'."`, exit non-zero
**GREEN**: In `New-Adr.ps1`: resolve all `-Link` targets before any write (fail-fast); after creating new file, call `Add-AdrLink` on both sides for each triple
**REFACTOR**: None needed
**Files**: `AdrTools/Public/New-Adr.ps1`, `Tests/Public/New-Adr.Link.Tests.ps1`
**Commit**: `feat: implement adr new -l explicit link flag`

---

### Step 14: `adr list` (`Get-AdrList`)

**Complexity**: standard
**RED**: Pester tests:
- Directory with `0001-*.md`, `0002-*.md`, `0003-*.md` → returns array of 3 full paths in ascending order
- Non-ADR files in directory (e.g., `README.md`, `templates/`) excluded from output
- No ADR directory configured → `Write-Error` with `"No ADR directory found. Run 'adr init' to create one."`, function throws
- `adr list` wired in `adr.ps1`: exit code 0 on success, exit code 1 on error (error text on stderr, nothing on stdout)
**GREEN**: Implement `Public/Get-AdrList.ps1`; call `Get-AdrDirectory`, then `Get-ChildItem -Path $dir -Filter '???[0-9]-*.md' | Where-Object { $_.Name -match '^\d{4}-' } | Sort-Object Name | Select-Object -Expand FullName`; wire in `adr.ps1`; add to `FunctionsToExport`
**REFACTOR**: None needed
**Files**: `AdrTools/Public/Get-AdrList.ps1`, `AdrTools/adr.ps1`, `AdrTools/AdrTools.psd1`, `Tests/Public/Get-AdrList.Tests.ps1`
**Commit**: `feat: implement adr list command`

---

### Step 15: `adr link` (`Set-AdrLink`)

**Complexity**: standard
**RED**: Pester tests:
- `Set-AdrLink -Source "2" -LinkText "Amends" -Target "5" -ReverseLinkText "Amended by"` with both files existing:
  - Source Status contains `"Amends [<title of 0005>](0005-tracing.md)"`
  - Target Status contains `"Amended by [<title of 0002>](0002-logging.md)"`
- Resolve source and target by partial name
- **Fail-fast**: target doesn't exist → error `"ADR 99 not found."`, exit non-zero, source file unchanged
- `adr link` wired in `adr.ps1`
**GREEN**: Implement `Public/Set-AdrLink.ps1`: resolve both files first (fail-fast); get both titles; call `Add-AdrLink` forward and reverse; add to `FunctionsToExport`; wire in `adr.ps1`
**REFACTOR**: None needed
**Files**: `AdrTools/Public/Set-AdrLink.ps1`, `AdrTools/adr.ps1`, `AdrTools/AdrTools.psd1`, `Tests/Public/Set-AdrLink.Tests.ps1`
**Commit**: `feat: implement adr link command`

---

### Step 16: `adr generate toc` (`Get-AdrToc`)

**Complexity**: standard
**RED**: Pester tests:
- Output starts with `"# Architecture Decision Records"`
- Each ADR listed as `"* [<Title>](<filename.md>)"` (filename only, no path, forward slash implicit)
- `-Prefix "/docs/"`: each href becomes `"/docs/<filename.md>"`
- `-Intro "intro.md"`: content of `intro.md` appears after heading
- `-Outro "outro.md"`: content of `outro.md` appears at end
- `-Intro "missing.md"` → error `"Intro file 'missing.md' not found."`, exit non-zero
- `-Outro "missing.md"` → same error pattern
- `adr generate toc` wired in `adr.ps1` (`generate` → first arg `toc`)
**GREEN**: Implement `Public/Get-AdrToc.ps1` with `-Prefix`, `-Intro`, `-Outro` params; call `Get-AdrList`, extract title per file via `Get-AdrTitle`, build Markdown output string; write to stdout; add to manifest; wire in `adr.ps1`
**REFACTOR**: None needed
**Files**: `AdrTools/Public/Get-AdrToc.ps1`, `AdrTools/adr.ps1`, `AdrTools/AdrTools.psd1`, `Tests/Public/Get-AdrToc.Tests.ps1`
**Commit**: `feat: implement adr generate toc command`

---

### Step 17: `adr generate graph` (`Get-AdrGraph`)

**Complexity**: complex
**RED**: Pester tests:
- Output starts with `"digraph {"`
- Each ADR has a node line matching `'n\d+ \[label="<title>" shape=plaintext URL="<filename>.html"\]'`
- Sequential ADRs (N and N+1) have a dotted edge: `'n\d+ -> n\d+ \[style="dotted" weight=1\]'`
- ADR 2 with `"Amends [Use REST](0003-use-rest.md)"` in Status → directed edge `n2 -> n3 [label="Amends"]`
- Reverse link lines (`"Amended by"`, `"Superceded by"`) do not produce additional edges
- Output ends with `"}"`
- `-Prefix "/adr/" -Extension ".html"` → node URLs use prefix and extension
- **DOT validation** (when `dot` is available): `Get-Command dot -ErrorAction SilentlyContinue` guard; if present, pipe output through `dot -Tsvg`; assert exit code 0. Test is `Skip`-tagged with `Skip = -not (Get-Command dot -ErrorAction SilentlyContinue)` so CI without Graphviz still passes.
**GREEN**: Implement `Public/Get-AdrGraph.ps1`: call `Get-AdrList`; assign node IDs (`n1`, `n2`, …); for each ADR, emit node line using `Get-AdrTitle`; emit sequential dotted edges; call `Get-AdrLinks` for each ADR, emit forward-link directed edges; add to manifest; wire in `adr.ps1`
**REFACTOR**: None needed
**Files**: `AdrTools/Public/Get-AdrGraph.ps1`, `AdrTools/adr.ps1`, `AdrTools/AdrTools.psd1`, `Tests/Public/Get-AdrGraph.Tests.ps1`
**Commit**: `feat: implement adr generate graph command`

---

### Step 18: `adr upgrade-repository` (`Update-AdrRepository`)

**Complexity**: standard
**RED**: Pester tests:
- File containing `"Date: 15/01/2020"` → rewritten to `"Date: 2020-01-15"` (regex: `(\d{2})/(\d{2})/(\d{4})` → `$3-$2-$1` on Date lines only)
- File containing `"Date: 2020-01-15"` → unchanged (idempotent)
- File containing both patterns (partially upgraded) → only the DD/MM/YYYY occurrence is converted, ISO date unchanged
- Multiple ADR files all processed
- Written files have no BOM, LF line endings
- `adr upgrade-repository` wired in `adr.ps1`
**GREEN**: Implement `Public/Update-AdrRepository.ps1`: iterate `Get-AdrList`; for each file, `Get-Content` all lines; apply regex replacement on lines matching `^Date: \d{2}/\d{2}/\d{4}`; if any line changed, call `Write-AdrFile`; add to manifest; wire in `adr.ps1`
**REFACTOR**: None needed
**Files**: `AdrTools/Public/Update-AdrRepository.ps1`, `AdrTools/adr.ps1`, `AdrTools/AdrTools.psd1`, `Tests/Public/Update-AdrRepository.Tests.ps1`
**Commit**: `feat: implement adr upgrade-repository command`

---

### Step 19: `adr help` (`Get-AdrHelp`)

**Complexity**: trivial
**RED**: Pester tests:
- `Get-AdrHelp` with no args → output contains `"init"`, `"new"`, `"list"`, `"link"`, `"generate"`, `"upgrade-repository"`
- `Get-AdrHelp -Command "new"` → output contains `"-s"` and `"-l"` with format descriptions including `"TARGET:LINK:REVERSE-LINK"` example
- `Get-AdrHelp -Command "unknown"` → error `"Unknown command: unknown"`, exit non-zero
- `adr help` wired in `adr.ps1` (already stubbed in Step 1; now fully wired)
**GREEN**: Implement `Public/Get-AdrHelp.ps1` with hardcoded `$HelpText` hashtable; add note in implementation comments that this must be kept in sync with actual parameter changes; add to manifest; wire `help` fully in `adr.ps1`
**REFACTOR**: None needed
**Files**: `AdrTools/Public/Get-AdrHelp.ps1`, `AdrTools/adr.ps1`, `AdrTools/AdrTools.psd1`, `Tests/Public/Get-AdrHelp.Tests.ps1`
**Commit**: `feat: implement adr help command`

---

### Step 20: End-to-end integration tests and module manifest finalisation

**Complexity**: standard
**RED**: End-to-end Pester tests invoking `adr.ps1` as an external process via `& pwsh AdrTools/adr.ps1 <cmd>` (or `& powershell.exe` on PS5.1). Named scenarios:
- **init**: `& pwsh adr.ps1 init` exits 0; `doc/adr/0001-record-architecture-decisions.md` created; first 3 bytes ≠ BOM
- **new (success)**: `adr new "Test Decision"` after init exits 0; `0002-test-decision.md` created; path printed to stdout
- **new (no init directory)**: run `adr new "X"` in a temp dir with no `.adr-dir` and no `doc/adr` → exits 1; stderr contains `"No ADR directory found. Run 'adr init' to create one."`; no file created
- **new -s bad target**: `adr new "Bad" -s 99` exits 1; stderr contains `"ADR 99 not found"`; no file created
- **list**: exits 0; stdout contains full paths of both ADRs, one per line; stderr empty
- **link**: `adr link 1 "References" 2 "Referenced by"` exits 0; both files updated
- **generate toc**: exits 0; stdout starts with `"# Architecture Decision Records"`, contains `"* ["` entries
- **generate graph**: exits 0; stdout starts with `"digraph {"`, ends with `"}"`
- **upgrade-repository**: exits 0
- **help**: exits 0; stdout contains `"init"`, `"new"`, `"list"`, `"generate"`, `"upgrade-repository"`
- **help new**: exits 0; stdout contains `"-s"` and `"-l"` and `"TARGET:LINK:REVERSE-LINK"`
- **unknown command**: `adr unknowncommand` exits 1; stderr contains `"Unknown command: unknowncommand"` ; stdout empty
- **FunctionsToExport completeness**: `Import-Module ./AdrTools/AdrTools.psd1 -Force`; assert `(Get-Module AdrTools).ExportedFunctions.Keys` equals exactly `@('Initialize-AdrDirectory','New-Adr','Get-AdrList','Set-AdrLink','Get-AdrToc','Get-AdrGraph','Update-AdrRepository','Get-AdrHelp')` (sorted); assert no public `.ps1` file under `AdrTools/Public/` is absent from this set (drift protection)
- **Forward-slash in markdown links**: after `adr new "X"` and `adr link 1 "Amends" 2 "Amended by"`, open ADR 1 and assert the link line uses `/` not `\` regardless of OS
**GREEN**: Finalize `AdrTools/AdrTools.psd1`:
  - `FunctionsToExport`: all 8 public function names
  - `CompatiblePSEditions = @('Desktop','Core')`
  - `PowerShellVersion = '5.1'`
  - `ModuleVersion = '1.0.0'`
  - `Author`, `Description` populated
- Add `#!/usr/bin/env pwsh` shebang as first line of `adr.ps1` for macOS/Linux
- Update `README.md` with install instructions and command reference
**REFACTOR**: Review all `adr.ps1` dispatch cases for consistency; ensure all error paths call `exit 1` and write to stderr
**Files**: `AdrTools/AdrTools.psd1`, `AdrTools/adr.ps1`, `Tests/Integration/AdrCli.Tests.ps1`, `README.md`
**Commit**: `feat: end-to-end integration tests and finalize module manifest`

---

## Complexity Classification

| Rating | Criteria | Review depth |
|--------|----------|--------------|
| `trivial` | Single-file change, config, doc-only | Skip inline review; covered by final `/code-review` |
| `standard` | New function, test, or behavioral change within established patterns | Spec-compliance + relevant quality agents |
| `complex` | New abstraction, cross-cutting concern, multi-file mutation logic | Full agent suite |

## Pre-PR Quality Gate

- [ ] All 20 Pester test steps pass under `pwsh` (PS7)
- [ ] All 20 Pester test steps pass under `powershell.exe` (PS5.1) — via CI or local Windows
- [ ] No PS7-only syntax present: `grep -rn '??' AdrTools/` and `grep -rn ' ? ' AdrTools/` return no matches
- [ ] `Write-AdrFile` is the only file-write path — `grep -rn 'Set-Content\|Out-File\|Add-Content\|WriteAllLines\|WriteAllBytes' AdrTools/Private AdrTools/Public` returns no matches (excludes `Write-AdrFile.ps1` itself)
- [ ] `adr generate graph` output passes `dot -Tsvg` in CI — GitHub Actions ubuntu job installs `graphviz` (`apt-get install -y graphviz`) so the conditional test runs; Windows job installs via `choco install graphviz -y`
- [ ] `/code-review` passes
- [ ] `README.md` updated with install and usage instructions

## Risks & Open Questions

- **PS5.1 test execution environment**: macOS dev machine likely runs PS7 only. PS5.1 testing requires a Windows machine or GitHub Actions `windows-latest` runner (which has PS5.1 pre-installed). Add a `.github/workflows/test.yml` that runs Pester on both `ubuntu-latest` (PS7) and `windows-latest` (PS5.1 + PS7).
- **Pester 5.x availability on PS5.1**: The bootstrap script (`tools/pester-bootstrap.ps1`) installs Pester 5.x from the Gallery. First run requires internet access. Offline environments must pre-bundle `tools/Pester/` and commit it. Decide before Step 1 whether to commit the vendor copy.
- **`Set-Content` BOM hazard**: Mitigated by `Write-AdrFile`. However, `Get-Content` on PS5.1 returns strings with BOM embedded in the first string if the source file has a BOM (from another tool). `Get-Content` should be wrapped in a helper that strips a leading BOM character if present. Add this to Step 7 (Get-AdrTitle reads first line; BOM would corrupt title extraction).
- **Line ending preservation**: `Write-AdrFile` normalizes to LF. This means editing a CRLF ADR file (common on Windows) will silently change its line endings, creating noisy `git diff` output. This is an intentional design choice for cross-platform consistency — document it in the README.
- **"Supercedes" spelling**: The bash tool uses this misspelling. The port must replicate it exactly for format parity (AC-3). This is intentional — document it with a comment in the relevant test.
- **Concurrent `adr new` calls**: Two simultaneous invocations will both call `Get-NextAdrNumber` and may produce the same sequence number. Same limitation as the bash tool. Documented in README under "Known Limitations".
- **`adr help` drift**: The hardcoded help text in `Get-AdrHelp.ps1` will drift from actual behavior as the module evolves. Add a `# MAINTENANCE: update help text when params change` comment to the function.
- **Graphviz in CI**: CI matrix must install Graphviz so the conditional DOT validation test is not permanently skipped. Ubuntu: `apt-get install -y graphviz`. Windows: `choco install graphviz -y`. Without this the Pre-PR gate item for AC-6 is never exercised automatically.
- **PS5.1 support window**: PS5.1 reached end-of-support in October 2025. As of this plan (May 2026) it is past EOL. PS5.1 support is retained as a hard requirement because the installed base on corporate Windows systems remains large. The decision should be captured in an ADR and reviewed at v1.0 release. Dropping PS5.1 would remove the Pester BOM/encoding constraints and the `UTF8Encoding($false)` workaround.
- **`Set-Content` BOM hazard**: Mitigated by `Write-AdrFile`. `Get-Content` BOM contamination mitigated by `.TrimStart([char]0xFEFF)` in `Get-AdrTitle` and `Get-AdrStatusBounds` (per Step 7 GREEN). Risk is now tracked and handled.

---

## Plan Review Summary

Two review iterations were run across four reviewer personas.

**Iteration 1**: All four reviewers returned `needs-revision`. Key blockers addressed in revision:
- Added dedicated `Write-AdrFile` step (UTF-8 no-BOM, LF normalization, byte-level tests)
- Promoted `Get-AdrStatusBounds` from a REFACTOR side-effect to its own Step 6 with a full fixture suite
- Added fail-fast atomicity architecture (resolve all targets before any write)
- Specified `New-Adr` parameter design before implementation
- Added error message text for every error path with `"<What went wrong>. <What to do next>."` convention
- Added Gherkin scenarios for "new without init", "supersede non-existent target", "link target not found", "intro file missing"
- Moved `Get-AdrLinks` to Step 7 with the other read-only parsers
- Stubbed `adr.ps1` dispatcher in Step 1 for early shippability
- Specified exit codes on all error and success paths

**Iteration 2**: Architecture, UX, and Strategic critics approved. Acceptance Test Critic flagged four remaining blockers, resolved without a third cycle:
- Specified `EndIndex` arithmetic precisely for EOF-terminated Status sections (`= $Lines.Count - 1`)
- Upgraded Graphviz CI from "manual step" to a mandatory CI install (apt/choco) in the Pre-PR gate
- Added "adr new without init directory" to Step 20 e2e named scenarios
- Assigned BOM-stripping on `Get-Content` to Step 7 RED/GREEN with an explicit fixture test

**Remaining warnings (non-blocking, address during implementation)**:
- `Get-AdrList` `-Filter` glob vs regex: use `'????-*.md'` not `'???[0-9]-*.md'` (Windows provider glob semantics)
- `New-Adr` parameter binding with `ValueFromRemainingArguments`: add explicit binding test in Step 11/12
- FunctionsToExport drift: Step 20 e2e now includes a drift-protection assertion
- `outro file missing` scenario added to Gherkin (symmetric with intro)
- Forward-slash in markdown links: Step 20 e2e now includes a cross-platform link assertion
- PS5.1 sunset: captured in Risks section; decision deferred to v1.0 ADR
- Golden-file fixture: `.gitattributes -text` entry added in Step 9; regeneration comment in test file
