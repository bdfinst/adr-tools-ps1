# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PowerShell port of [adr-tools](https://github.com/npryce/adr-tools) — a command-line tool for creating and managing Architecture Decision Records (ADRs).

The original `adr-tools` is a bash-based toolkit. This project replicates its functionality in PowerShell for cross-platform use or Windows-native environments.

## Architecture Intent

The original `adr-tools` provides these core commands:
- `adr init` — initialize an ADR directory
- `adr new` — create a new ADR
- `adr list` — list all ADRs
- `adr link` — link ADRs together
- `adr generate` — generate documentation from ADRs

ADRs follow a Markdown template with numbered filenames (e.g., `0001-record-architecture-decisions.md`). The port should preserve this file format and numbering convention so ADR directories remain compatible with tooling that reads the original format.
