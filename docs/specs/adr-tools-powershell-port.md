# Spec: adr-tools PowerShell Port

## Intent Description

Port the `adr-tools` bash CLI to a PowerShell module that runs on both PowerShell 5.1 and PowerShell 7.x without external dependencies. The port must reproduce all original commands — `init`, `new`, `list`, `link`, `generate` (toc and graph subcommands), `help`, and `upgrade-repository` — while preserving the ADR Markdown file format and 4-digit zero-padded filename convention (`NNNN-slug.md`) so that ADR directories created by this tool remain compatible with the original bash tooling and any tooling that reads the format.

The motivation is to give Windows-native and PowerShell-centric CI environments first-class ADR tooling without requiring bash, WSL, or any Unix toolchain.

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

  Scenario: No ADR directory configured
    Given no ".adr-dir" file exists and no "doc/adr" directory exists
    When I run "adr list"
    Then an error is written to stderr
    And the exit code is non-zero

Feature: adr link - Add directional links between two existing ADRs

  Scenario: Link two ADRs bidirectionally
    Given "0002-logging.md" and "0005-tracing.md" both exist
    When I run "adr link 2 'Amends' 5 'Amended by'"
    Then "0002-logging.md" Status contains "Amends [<title of 0005>](0005-tracing.md)"
    And "0005-tracing.md" Status contains "Amended by [<title of 0002>](0002-logging.md)"

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

## Architecture Specification

**Module structure**

```
AdrTools/
  AdrTools.psd1          # Module manifest (CompatiblePSEditions: Desktop, Core)
  AdrTools.psm1          # Exports public functions; dot-sources private helpers
  Private/
    Get-AdrDirectory.ps1   # walks up tree for .adr-dir / doc/adr fallback
    Resolve-AdrFile.ps1    # resolves number/partial-name to full path
    Get-AdrTitle.ps1       # reads first line, strips "# N. " prefix
    Get-AdrStatus.ps1      # extracts Status section lines
    Get-AdrLinks.ps1       # parses Status links for graph generation
    Add-AdrLink.ps1        # inserts a link line into Status section
    Remove-AdrStatusText.ps1  # removes a specific status text (e.g. "Accepted")
    New-AdrSlug.ps1        # title -> lowercase-hyphenated slug
    Get-NextAdrNumber.ps1  # scans existing files, returns next integer
  Public/
    Initialize-AdrDirectory.ps1  # adr init
    New-Adr.ps1                  # adr new
    Get-AdrList.ps1              # adr list
    Set-AdrLink.ps1              # adr link
    Get-AdrToc.ps1               # adr generate toc
    Get-AdrGraph.ps1             # adr generate graph
    Update-AdrRepository.ps1     # adr upgrade-repository
    Get-AdrHelp.ps1              # adr help
  adr.ps1                # thin CLI wrapper: dispatches to module functions
  templates/
    template.md          # built-in default ADR template
    init.md              # template for ADR #1 (record-architecture-decisions)
```

**PS5.1 / PS7 compatibility constraints**
- No ternary operators (`a ? b : c` — PS7 only); use `if/else`
- No null-coalescing assignment (`??=` — PS7 only)
- No `ForEach-Object -Parallel`
- Use `Set-Content -Encoding UTF8` explicitly (PS5 `Out-File` defaults to UTF-16)
- Use `Join-Path` for all path construction
- `$PSScriptRoot` works in both editions for locating module files

**Status section editing**
All in-place file edits read the full file into a string array, locate the `## Status` heading by index, find the next `##` heading (or EOF) as the section boundary, insert/remove lines within that range, then write back with `Set-Content -Encoding UTF8`. No awk or sed — pure PowerShell string processing.

**CLI dispatch (`adr.ps1`)**
Maps `adr <command> [args]` to the corresponding exported function via a `switch` statement. The `generate` command dispatches on its first argument (`toc` or `graph`).

**No external dependencies** — nothing outside the PowerShell standard library and BCL types. Test suite uses Pester (ships with PS5.1+; available for PS7 via `Install-Module Pester`).

## Acceptance Criteria

| # | Criterion | Pass condition |
|---|-----------|----------------|
| AC-1 | PS5.1 compatibility | All commands run without error in Windows PowerShell 5.1 |
| AC-2 | PS7 compatibility | All commands run without error in PowerShell 7.x on Windows, macOS, Linux |
| AC-3 | File format parity | ADR files match the bash tool's format: 4-digit padding, ISO date, `# N. Title` heading, Accepted status |
| AC-4 | No external dependencies | `adr` commands succeed with only PowerShell installed (no bash, WSL, or third-party modules) |
| AC-5 | Bidirectional linking correctness | `adr new -s N` and `adr link` update both files; partial failure leaves no file half-edited |
| AC-6 | DOT output validity | `adr generate graph` output passes `dot -Tsvg` without errors |
| AC-7 | Test coverage | Pester test suite passes on both PS5.1 and PS7; all Gherkin scenarios have corresponding tests |
| AC-8 | Custom template respected | `ADR_TEMPLATE` env var and `templates/template.md` in the ADR directory both override the built-in template |
| AC-9 | Directory walk | Running `adr list` from a subdirectory finds `.adr-dir` in a parent directory |
| AC-10 | Installable as module | `Import-Module AdrTools` succeeds after copying the module folder to any directory in `$env:PSModulePath` |

## Consistency Gate

- [x] Intent is unambiguous — two developers would interpret it the same way
- [x] Every behavior in the intent has at least one corresponding BDD scenario
- [x] Architecture constrains implementation to what the intent requires, without over-engineering
- [x] Terminology is consistent across all four artifacts (`ADR directory`, `Status section`, `slug`, `supersede`)
- [x] No contradictions between artifacts

**Verdict: PASS**
