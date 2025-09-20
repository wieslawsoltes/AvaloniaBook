#!/usr/bin/env bash
set -euo pipefail

# Publish AvaloniaBook as a single PDF using Pandoc
# Usage: bash scripts/publish-pdf.sh

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="${SCRIPT_DIR%/scripts}"
INDEX_FILE="$ROOT_DIR/Index.md"
OUT_DIR="$ROOT_DIR/dist"
TMP_MD="$OUT_DIR/AvaloniaBook.md"
OUT_PDF="$OUT_DIR/AvaloniaBook.pdf"
OUT_TEX="$OUT_DIR/AvaloniaBook.tex"

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/_book_combined.md"

# Ensure pandoc is installed (attempt auto-install on common platforms)
ensure_pandoc() {
  if command -v pandoc >/dev/null 2>&1; then return 0; fi
  echo "Pandoc not found. Attempting to install..." >&2

  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        echo "Installing pandoc via Homebrew..." >&2
        brew install pandoc || { echo "Homebrew install failed. Please install manually: https://pandoc.org/installing.html" >&2; return 1; }
      elif command -v port >/dev/null 2>&1; then
        echo "Installing pandoc via MacPorts (requires sudo)..." >&2
        sudo port install pandoc || { echo "MacPorts install failed. Please install manually: https://pandoc.org/installing.html" >&2; return 1; }
      else
        echo "Neither Homebrew nor MacPorts found. Please install pandoc: https://pandoc.org/installing.html" >&2
        return 1
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        echo "Installing pandoc via apt-get (requires sudo)..." >&2
        sudo apt-get update && sudo apt-get install -y pandoc || { echo "apt-get install failed. Please install manually: https://pandoc.org/installing.html" >&2; return 1; }
      elif command -v dnf >/dev/null 2>&1; then
        echo "Installing pandoc via dnf (requires sudo)..." >&2
        sudo dnf install -y pandoc || { echo "dnf install failed. Please install manually: https://pandoc.org/installing.html" >&2; return 1; }
      elif command -v pacman >/dev/null 2>&1; then
        echo "Installing pandoc via pacman (requires sudo)..." >&2
        sudo pacman -S --noconfirm pandoc || { echo "pacman install failed. Please install manually: https://pandoc.org/installing.html" >&2; return 1; }
      else
        echo "Unsupported Linux package manager. Please install pandoc: https://pandoc.org/installing.html" >&2
        return 1
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      echo "Windows detected. Please install pandoc using the official installer: https://pandoc.org/installing.html" >&2
      return 1
      ;;
    *)
      echo "Unsupported OS. Please install pandoc: https://pandoc.org/installing.html" >&2
      return 1
      ;;
  esac

  command -v pandoc >/dev/null 2>&1
}

ensure_pandoc || { echo "Pandoc is required. Exiting." >&2; exit 1; }

# Ensure a PDF engine is installed (tectonic preferred; fall back to wkhtmltopdf)
ensure_pdf_engine() {
  # If any engine already exists, nothing to do
  if command -v tectonic >/dev/null 2>&1 || command -v xelatex >/dev/null 2>&1 || command -v lualatex >/dev/null 2>&1 || command -v pdflatex >/dev/null 2>&1 || command -v wkhtmltopdf >/dev/null 2>&1 || command -v weasyprint >/dev/null 2>&1; then
    return 0
  fi
  echo "Attempting to install a PDF engine (tectonic preferred)..." >&2
  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install tectonic || brew install wkhtmltopdf || return 1
      elif command -v port >/dev/null 2>&1; then
        sudo port install tectonic || sudo port install wkhtmltopdf || return 1
      else
        return 1
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && (sudo apt-get install -y tectonic || sudo apt-get install -y wkhtmltopdf) || return 1
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y tectonic || sudo dnf install -y wkhtmltopdf || return 1
      elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm tectonic || sudo pacman -S --noconfirm wkhtmltopdf || return 1
      else
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
  # Re-check
  command -v tectonic >/dev/null 2>&1 || command -v xelatex >/dev/null 2>&1 || command -v lualatex >/dev/null 2>&1 || command -v pdflatex >/dev/null 2>&1 || command -v wkhtmltopdf >/dev/null 2>&1 || command -v weasyprint >/dev/null 2>&1
}

# Choose a PDF engine in order of preference
choose_engine() {
  if command -v pdflatex >/dev/null 2>&1; then echo "pdflatex"; return; fi
  if command -v xelatex  >/dev/null 2>&1; then echo "xelatex";  return; fi
  if command -v lualatex >/dev/null 2>&1; then echo "lualatex"; return; fi
  if command -v tectonic >/dev/null 2>&1; then echo "tectonic"; return; fi
  if command -v wkhtmltopdf >/dev/null 2>&1; then echo "wkhtmltopdf"; return; fi
  if command -v weasyprint  >/dev/null 2>&1; then echo "weasyprint";  return; fi
  echo "none"
}

ensure_pdf_engine || { echo "Could not install a PDF engine automatically. Please install a TeX engine (pdflatex/xelatex/lualatex) and re-run." >&2; exit 1; }

if [[ -z ${PDF_ENGINE:-} ]]; then
  PDF_ENGINE=$(choose_engine)
else
  echo "Using PDF engine from environment: $PDF_ENGINE"
fi
if [[ "$PDF_ENGINE" == "none" ]]; then
  echo "Error: No PDF engine found after installation attempt. Install tectonic or a LaTeX engine (xelatex/lualatex/pdflatex) and retry." >&2
  exit 1
fi

# Build combined Markdown for PDF
: > "$TMP_MD"
cat <<'YAML' >> "$TMP_MD"
---
title: ""
header-includes:
  - "\\AtBeginDocument{\\let\\maketitle\\relax}"
  - "\\usepackage{xcolor}"
  - "\\usepackage{fvextra}"
  - "\\usepackage{framed}"
  - "\\definecolor{shadecolor}{HTML}{F6F8FA}"
  - "\\definecolor{linenocolor}{HTML}{6A737D}"
  - "\\AtBeginDocument{\\renewenvironment{Shaded}{\\begin{snugshade}}{\\end{snugshade}}}"
  - "\\AtBeginDocument{\\fvset{breaklines=true,breakanywhere=true,numbers=left,numbersep=10pt,framesep=3pt,frame=single,rulecolor=\\color{linenocolor},xleftmargin=1em,fontsize=\\small,breaksymbol=\\color{linenocolor}\\scriptsize\\ensuremath{\\hookrightarrow}}}"
  - "\\AtBeginDocument{\\renewcommand{\\theFancyVerbLine}{\\textcolor{linenocolor}{\\scriptsize\\arabic{FancyVerbLine}}}}"
---

YAML

python3 - "$TMP_MD" <<'PY_COVER'
import sys
from pathlib import Path

tmp_path = Path(sys.argv[1])

content = [
    "```{=latex}",
    "\\thispagestyle{empty}",
    "\\vspace*{\\fill}",
    "\\begin{center}",
    "{\\Huge\\bfseries Avalonia Book}",
    "\\end{center}",
    "\\vspace*{\\fill}",
    "\\clearpage",
    "```",
    "",
]

with tmp_path.open("a", encoding="utf-8") as handle:
    handle.write("\n".join(content))
PY_COVER

python3 - "$TMP_MD" <<'PY_TOC'
import sys
from pathlib import Path

tmp_path = Path(sys.argv[1])

content = [
    "```{=latex}",
    "\\setcounter{tocdepth}{3}",
    "\\tableofcontents",
    "\\clearpage",
    "```",
    "",
]

with tmp_path.open("a", encoding="utf-8") as handle:
    handle.write("\n".join(content))
PY_TOC

# Extract part headings and chapter files from Index.md in order
count=0
part_count=0

while IFS= read -r line; do
  [[ -z "$line" ]] && continue

  if [[ $line =~ ^##[[:space:]]+Part ]]; then
    part_heading=${line#\#\# }
    if [[ -n "$part_heading" ]]; then
      python3 - "$TMP_MD" "$part_heading" "$part_count" <<'PY_PART'
import sys
from pathlib import Path

tmp_path = Path(sys.argv[1])
heading = sys.argv[2]
part_index = int(sys.argv[3])

def escape_latex(text: str) -> str:
    replacements = {
        "\\": r"\\\\",
        "&": r"\\&",
        "%": r"\\%",
        "$": r"\\$",
        "#": r"\\#",
        "_": r"\\_",
        "{": r"\\{",
        "}": r"\\}",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)
    return text

content = ["```{=latex}"]
if part_index > 0:
    content.append("\\clearpage")
latex_heading = escape_latex(heading)
content.extend([
    "\\phantomsection",
    f"\\addcontentsline{{toc}}{{section}}{{{latex_heading}}}",
    "\\thispagestyle{empty}",
    "\\vspace*{\\fill}",
    "\\begin{center}",
    f"{{\\Huge\\bfseries {latex_heading}}}",
    "\\end{center}",
    "\\vspace*{\\fill}",
    "\\clearpage",
    "```",
    "",
])

with tmp_path.open("a", encoding="utf-8") as handle:
    handle.write("\n".join(content))
PY_PART
      part_count=$((part_count+1))
    fi
    continue
  fi

  chapter_path=$(printf '%s\n' "$line" | sed -n 's/.*(\(Chapters\/[^)]*\.md\)).*/\1/p')
  if [[ -n "$chapter_path" ]]; then
    if [[ $count -gt 0 ]]; then
      printf '\n```{=latex}\n\\newpage\n```\n\n' >> "$TMP_MD"
    fi
    chapter_file="$ROOT_DIR/$chapter_path"
    if [[ ! -f "$chapter_file" ]]; then
      echo "Error: Chapter file $chapter_file not found" >&2
      exit 1
    fi
    python3 - "$chapter_file" 1 >> "$TMP_MD" <<'PY_HELPER'
import sys
import re
from pathlib import Path

path = Path(sys.argv[1])
shift = int(sys.argv[2])
lines = path.read_text(encoding='utf-8').splitlines()

heading_re = re.compile(r'^( {0,3})(#{1,6})(\s+)(.*)$')

shifted_lines = []
for line in lines:
    match = heading_re.match(line)
    if not match:
        shifted_lines.append(line)
        continue
    indent, hashes, space, rest = match.groups()
    if shift > 0 and len(hashes) == 1:
        new_count = min(len(hashes) + shift, 6)
    else:
        new_count = len(hashes)
    shifted_lines.append(f"{indent}{'#' * new_count}{space}{rest}")

sys.stdout.write("\n".join(shifted_lines) + "\n")
PY_HELPER
    printf '\n' >> "$TMP_MD"
    echo "Added $chapter_path"
    count=$((count+1))
  fi
done < "$INDEX_FILE"

if [[ $count -eq 0 ]]; then
  echo "Error: Could not parse chapters from $INDEX_FILE" >&2
  exit 1
fi

# Normalize fenced code block languages for Pandoc/LaTeX conversion
python3 - "$TMP_MD" <<'PY_LANG'
from pathlib import Path
import re

path = Path(__import__('sys').argv[1])
text = path.read_text(encoding='utf-8')

text = re.sub(r'^```csharp(\s*$)', r'```{.csharp}\1', text, flags=re.MULTILINE)
text = re.sub(r'^```Csharp(\s*$)', r'```{.csharp}\1', text, flags=re.MULTILINE)
text = re.sub(r'^```xml(\s*$)', r'```{.xml}\1', text, flags=re.MULTILINE)
text = re.sub(r'^```bash(\s*$)', r'```{.bash}\1', text, flags=re.MULTILINE)
text = re.sub(r'^```yaml(\s*$)', r'```{.yaml}\1', text, flags=re.MULTILINE)
path.write_text(text, encoding='utf-8')
PY_LANG

# Common Pandoc options
COMMON_OPTS=(
  --resource-path="$ROOT_DIR:$ROOT_DIR/Chapters"
  --highlight-style=pygments
  -f markdown+raw_tex
  "--metadata=title-meta:Avalonia Book"
  --pdf-engine="$PDF_ENGINE"
)

# Add a modest page margin for LaTeX engines
if [[ "$PDF_ENGINE" == "xelatex" || "$PDF_ENGINE" == "lualatex" || "$PDF_ENGINE" == "pdflatex" || "$PDF_ENGINE" == "tectonic" ]]; then
  COMMON_OPTS+=( -V geometry:margin=1in )
fi

pandoc "${COMMON_OPTS[@]}" -o "$OUT_PDF" "$TMP_MD"
echo "PDF generated at $OUT_PDF"

# Also emit the combined LaTeX source for reference/debugging
LATEX_OPTS=(
  --resource-path="$ROOT_DIR:$ROOT_DIR/Chapters"
  --highlight-style=pygments
  -f markdown+raw_tex
  "--metadata=title-meta:Avalonia Book"
  -t latex
)

pandoc "${LATEX_OPTS[@]}" -o "$OUT_TEX" "$TMP_MD"
echo "LaTeX source saved to $OUT_TEX"
echo "Markdown source saved to $TMP_MD"
