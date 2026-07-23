# wfcharts — Open FlowCharts Index

## Where the shell command is saved

- Wrapper script: `/Users/sil/Documents/Work/00Utilities/scripts/00_workflow/shell_commands/wfcharts`
- Python entrypoint: `/Users/sil/Documents/Work/00Utilities/scripts/00_workflow/open_charts_html.py`
- Typical global command setup: symlink wrapper to `~/bin/wfcharts` (or another directory on `PATH`)

## What it does (current behavior)

`wfcharts` resolves the workflow script location, then runs:

```bash
python3 /Users/sil/Documents/Work/00Utilities/scripts/00_workflow/open_charts_html.py
```

The Python script builds this path from your current directory:

`Documentation/02_FlowCharts/index.html`

(On macOS, `wfcharts` also resolves `documentation/02_FlowCharts` case-insensitively.)

If found, it opens that file in your default browser using a `file://` URL.

Each chart page links to a **plain English guide** (`*.guide.html`) with explanations and copy-paste examples. Source text lives in `*.guide.md` next to each `*.mmd` file. Regenerate with:

```bash
python3 automation/backend/build_nav_and_charts.py
```

## Usage

```bash
wfcharts
```

## Notes

- `wfcharts` depends on where you run it (CWD-sensitive)
- If `Documentation/02_FlowCharts/index.html` is missing from the current project path, it exits with "File not found"
