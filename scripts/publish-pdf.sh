#!/usr/bin/env bash
set -euo pipefail

# Publish AvaloniaBook as a single PDF using Pandoc
# Usage: bash scripts/publish-pdf.sh

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="${SCRIPT_DIR%/scripts}"
INDEX_FILE="$ROOT_DIR/Index.md"
OUT_DIR="$ROOT_DIR/dist"
TMP_MD="$OUT_DIR/_book_combined.md"
OUT_PDF="$OUT_DIR/AvaloniaBook.pdf"

mkdir -p "$OUT_DIR"

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
  if command -v tectonic >/dev/null 2>&1; then echo "tectonic"; return; fi
  if command -v xelatex  >/dev/null 2>&1; then echo "xelatex";  return; fi
  if command -v lualatex >/dev/null 2>&1; then echo "lualatex"; return; fi
  if command -v pdflatex >/dev/null 2>&1; then echo "pdflatex"; return; fi
  if command -v wkhtmltopdf >/dev/null 2>&1; then echo "wkhtmltopdf"; return; fi
  if command -v weasyprint  >/dev/null 2>&1; then echo "weasyprint";  return; fi
  echo "none"
}

ensure_pdf_engine || { echo "Could not install a PDF engine automatically. Please install tectonic or a TeX engine and re-run." >&2; exit 1; }

PDF_ENGINE=$(choose_engine)
if [[ "$PDF_ENGINE" == "none" ]]; then
  echo "Error: No PDF engine found after installation attempt. Install tectonic or a LaTeX engine (xelatex/lualatex/pdflatex) and retry." >&2
  exit 1
fi

# Build combined Markdown for PDF
: > "$TMP_MD"
{
  echo "---";
  echo "title: \"Avalonia Book\"";
  echo "---";
  echo;
} >> "$TMP_MD"

# Extract chapter files from Index.md in order (portable, no mapfile)
count=0
while IFS= read -r chapter; do
  [ -z "$chapter" ] && continue
  count=$((count+1))
  # Insert a page break between chapters for LaTeX engines
  printf '\n```{=latex}\n\\newpage\n```\n\n' >> "$TMP_MD"
  cat "$ROOT_DIR/$chapter" >> "$TMP_MD"
  printf '\n' >> "$TMP_MD"
  echo "Added $chapter"
done <<EOF
$(grep -oE "\(Chapters/[^)]+\.md\)" "$INDEX_FILE" | sed 's/[()]//g')
EOF
if [[ $count -eq 0 ]]; then
  echo "Error: Could not parse chapters from $INDEX_FILE" >&2
  exit 1
fi

# Common Pandoc options
COMMON_OPTS=(
  --toc --toc-depth=2
  --resource-path="$ROOT_DIR:$ROOT_DIR/Chapters"
  --highlight-style=pygments
  -f markdown+raw_tex
  --pdf-engine="$PDF_ENGINE"
)

# Add a modest page margin for LaTeX engines
if [[ "$PDF_ENGINE" == "xelatex" || "$PDF_ENGINE" == "lualatex" || "$PDF_ENGINE" == "pdflatex" || "$PDF_ENGINE" == "tectonic" ]]; then
  COMMON_OPTS+=( -V geometry:margin=1in )
fi

pandoc "${COMMON_OPTS[@]}" -o "$OUT_PDF" "$TMP_MD"
echo "PDF generated at $OUT_PDF"