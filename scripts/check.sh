#!/usr/bin/env bash
# Validate the wordmark assets, then render test documents in every paper
# format with and without the wordmark and check each title block. Needs git,
# quarto, xelatex, xmllint, rsvg-convert, poppler's pdfinfo and pdftoppm, and
# ImageMagick's identify and compare.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
assets="$root/_extensions/axiom/assets"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

failures=0
ok() { printf 'ok - %s\n' "$1"; }
not_ok() {
  printf 'not ok - %s\n' "$1"
  failures=$((failures + 1))
}
check() {
  local description="$1"
  shift
  if "$@"; then ok "$description"; else not_ok "$description"; fi
}
has() { grep -qF -- "$2" "$1"; }
has_line() { grep -qE -- "$2" "$1"; }
# A missing file fails instead of passing as one that lacks everything.
lacks() {
  [[ -r "$1" ]] || {
    printf '# missing %s\n' "$1"
    return 1
  }
  ! grep -qF -- "$2" "$1"
}

# The SVG assets must parse as XML; rsvg-convert and browsers reject
# malformed markup.
svgs=0
while IFS= read -r svg; do
  svgs=$((svgs + 1))
  check "$svg parses as XML" xmllint --noout "$root/$svg"
done < <(git -C "$root" ls-files '*.svg')
check "the repository tracks SVG assets to validate" test "$svgs" -gt 0

# The wordmark is the brand kit's file, unchanged: axiom-brand@8a738e0
# svg/wordmark/full/axiom-full-w350-gradient.svg, which axiom.org also serves
# as /logos/axiom-foundation.svg. Replacing it with a newer kit file means
# updating this blob id, rebuilding the PDF, and re-measuring the left padding
# that partials/title.tex trims and axiom.scss offsets.
kit_blob=721f9e8233cfd069f9e81623da743e9931aff6f3
check "axiom-wordmark.svg is the brand kit's full lockup" \
  test "$(git hash-object "$assets/axiom-wordmark.svg")" = "$kit_blob"

# The committed PDF must still be the conversion of the SVG. Rebuild it and
# rasterize both PDFs with the same pdftoppm, so antialiasing matches and any
# difference is content. A fresh conversion matches to the pixel, both on
# macOS and with Ubuntu 24.04's librsvg 2.58. At 2% fuzz, the kit's w300 or
# ink lockup moves about 5% of pixels, its flat amber lockup 0.8%, shifting
# one gradient stop by 16 per channel 0.5%, and dropping FOUNDATION's F 0.17%,
# so the bar is 0.1%. Each step fails closed: this runs under `if`, where
# `set -e` is off.
pdf_matches_svg() {
  local shipped="$assets/axiom-wordmark.pdf" shipped_size fresh_size
  local width height differing
  "$root/scripts/build-wordmark-pdf.sh" "$work/fresh.pdf" >/dev/null || return 1
  shipped_size="$(pdfinfo "$shipped" | sed -n 's/^Page size: *//p')"
  fresh_size="$(pdfinfo "$work/fresh.pdf" | sed -n 's/^Page size: *//p')"
  if [[ -z "$shipped_size" || "$shipped_size" != "$fresh_size" ]]; then
    printf '# page size: shipped %s, rebuilt %s\n' \
      "${shipped_size:-unknown}" "${fresh_size:-unknown}"
    return 1
  fi
  pdftoppm -singlefile -png -r 96 "$shipped" "$work/shipped" || return 1
  pdftoppm -singlefile -png -r 96 "$work/fresh.pdf" "$work/fresh" || return 1
  read -r width height < <(identify -format '%w %h\n' "$work/shipped.png") || return 1
  differing="$({ compare -metric AE -fuzz 2% "$work/shipped.png" "$work/fresh.png" null: 2>&1 || true; } | awk '{print $1}')"
  printf '# %s of %s pixels differ from a fresh conversion\n' "$differing" "$((width * height))"
  awk -v d="$differing" -v n="$((width * height))" \
    'BEGIN { exit !(d ~ /^[0-9][0-9.]*(e[+-]?[0-9]+)?$/ && n > 0 && d / n < 0.001) }'
}
check "axiom-wordmark.pdf matches a fresh conversion of the SVG" pdf_matches_svg

project="$work/project"
mkdir -p "$project"
cp -R "$root/_extensions" "$project/"
printf 'project:\n  type: default\n' >"$project/_quarto.yml"

render() {
  local log="$work/$1.log"
  if (cd "$project" && quarto render "$1/paper.qmd" -M keep-tex:true) >"$log" 2>&1; then
    ok "$1 renders"
  else
    not_ok "$1 renders"
    sed 's/^/    /' "$log"
    return 1
  fi
}

wordmark_tex=']{axiom-wordmark.pdf}'
wordmark_html='<img class="axiom-wordmark" src="axiom-wordmark.svg" alt="Axiom Foundation">'
# The fallback byline; author affiliations print on their own line instead,
# which only the second pattern matches.
theme_affiliation_tex='\sffamily\small Axiom Foundation\par}'
author_affiliation_tex='^[[:space:]]*Axiom Foundation\\par\}$'
actual_text_tex='ActualText={Axiom Foundation}'
# The wordmark's alt text also reads "Axiom Foundation", so match the span.
affiliation_html='<span class="affiliation">Axiom Foundation</span>'

# The shipped example: wordmark by default, author affiliation kept.
mkdir -p "$project/example"
cp "$root/example/paper.qmd" "$project/example/"
if render example; then
  d="$project/example"
  check "example PDF includes the wordmark" has "$d/paper.tex" "$wordmark_tex"
  check "example PDF gives the wordmark its text" has "$d/paper.tex" "$actual_text_tex"
  check "example PDF keeps the author affiliation" has_line "$d/paper.tex" "$author_affiliation_tex"
  check "example PDF exists" test -s "$d/paper.pdf"
  check "example HTML includes the wordmark" has "$d/paper.html" "$wordmark_html"
  check "example HTML wordmark file sits beside the page" test -s "$d/axiom-wordmark.svg"
  check "example HTML keeps the author affiliation" has "$d/paper.html" "$affiliation_html"
  check "example HTML keeps the affiliations block" has "$d/paper.html" 'class="axiom-affiliations"'
fi

case_document() {
  mkdir -p "$project/$1"
  cat >"$project/$1/paper.qmd"
}

# Without author affiliations, the wordmark replaces the theme byline.
case_document no-affiliation <<'QMD'
---
title: "No affiliation"
author: Ada Example
format:
  axiom-paper-pdf: default
  axiom-paper-html: default
---
Body.
QMD
if render no-affiliation; then
  d="$project/no-affiliation"
  check "no-affiliation PDF includes the wordmark" has "$d/paper.tex" "$wordmark_tex"
  check "no-affiliation PDF gives the wordmark its text" has "$d/paper.tex" "$actual_text_tex"
  check "no-affiliation PDF omits the theme byline" lacks "$d/paper.tex" "$theme_affiliation_tex"
  check "no-affiliation HTML includes the wordmark" has "$d/paper.html" "$wordmark_html"
  check "no-affiliation HTML omits the theme byline" lacks "$d/paper.html" "$affiliation_html"
  check "no-affiliation HTML has no empty affiliations block" lacks "$d/paper.html" "axiom-affiliations"
fi

# `wordmark: false` removes it from both formats and restores the byline.
case_document opt-out <<'QMD'
---
title: "Opt out"
author: Ada Example
wordmark: false
format:
  axiom-paper-pdf: default
  axiom-paper-html: default
---
Body.
QMD
if render opt-out; then
  d="$project/opt-out"
  check "opt-out PDF omits the wordmark" lacks "$d/paper.tex" "axiom-wordmark"
  check "opt-out PDF prints the theme byline" has "$d/paper.tex" "$theme_affiliation_tex"
  check "opt-out HTML omits the wordmark" lacks "$d/paper.html" "axiom-wordmark"
  check "opt-out HTML prints the theme byline" has "$d/paper.html" "$affiliation_html"
fi

# A format-level `wordmark: false` affects only that format.
case_document pdf-opt-out <<'QMD'
---
title: "PDF opt out"
author: Ada Example
format:
  axiom-paper-pdf:
    wordmark: false
  axiom-paper-html: default
---
Body.
QMD
if render pdf-opt-out; then
  d="$project/pdf-opt-out"
  check "pdf-opt-out PDF omits the wordmark" lacks "$d/paper.tex" "axiom-wordmark"
  check "pdf-opt-out PDF prints the theme byline" has "$d/paper.tex" "$theme_affiliation_tex"
  check "pdf-opt-out HTML includes the wordmark" has "$d/paper.html" "$wordmark_html"
  check "pdf-opt-out HTML omits the theme byline" lacks "$d/paper.html" "$affiliation_html"
fi

case_document html-opt-out <<'QMD'
---
title: "HTML opt out"
author: Ada Example
format:
  axiom-paper-pdf: default
  axiom-paper-html:
    wordmark: false
---
Body.
QMD
if render html-opt-out; then
  d="$project/html-opt-out"
  check "html-opt-out PDF includes the wordmark" has "$d/paper.tex" "$wordmark_tex"
  check "html-opt-out PDF omits the theme byline" lacks "$d/paper.tex" "$theme_affiliation_tex"
  check "html-opt-out HTML omits the wordmark" lacks "$d/paper.html" "axiom-wordmark"
  check "html-opt-out HTML prints the theme byline" has "$d/paper.html" "$affiliation_html"
fi

# Self-contained HTML embeds the SVG instead of linking it.
case_document embedded <<'QMD'
---
title: "Embedded"
author: Ada Example
format:
  axiom-paper-html:
    embed-resources: true
---
Body.
QMD
if render embedded; then
  d="$project/embedded"
  check "embedded HTML inlines the wordmark" has "$d/paper.html" 'class="axiom-wordmark" src="data:image/svg+xml;base64,'
  check "embedded HTML does not link the wordmark file" lacks "$d/paper.html" 'src="axiom-wordmark.svg"'
fi

# The base extension's HTML format shares the partials. Its PDF format is not
# rendered here: it already fails on main, because Quarto resolves its
# axiom-font-dir to an extension path (#3).
case_document base-html <<'QMD'
---
title: "Base HTML"
author: Ada Example
format:
  axiom-html: default
---
Body.
QMD
if render base-html; then
  check "base-html includes the wordmark" has "$project/base-html/paper.html" "$wordmark_html"
fi

# Projects with an output directory copy the wordmark beside the page.
site="$work/site"
mkdir -p "$site/papers"
cp -R "$root/_extensions" "$site/"
printf 'project:\n  type: website\n  output-dir: _site\n' >"$site/_quarto.yml"
printf -- '---\ntitle: Home\n---\n' >"$site/index.qmd"
printf -- '---\ntitle: "In a website"\nformat: axiom-paper-html\n---\nBody.\n' >"$site/papers/paper.qmd"
if (cd "$site" && quarto render) >"$work/site.log" 2>&1; then
  ok "website renders"
  check "website output includes the wordmark" has "$site/_site/papers/paper.html" "$wordmark_html"
  check "website output copies the wordmark file" test -s "$site/_site/papers/axiom-wordmark.svg"
else
  not_ok "website renders"
  sed 's/^/    /' "$work/site.log"
fi

if ((failures > 0)); then
  printf '%d check(s) failed\n' "$failures"
  exit 1
fi
echo "All checks passed"
