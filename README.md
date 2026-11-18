# axiom-quarto

Quarto formats for Axiom working papers, with local static fonts for hermetic
PDF and HTML rendering.

```sh
quarto add TheAxiomFoundation/axiom-quarto
```

Use `axiom-paper-pdf` and `axiom-paper-html` in the document `format` block.

Metadata:

- `wordmark`: the Axiom Foundation wordmark heads the PDF and HTML title
  blocks; defaults to `true`. Set `wordmark: false` to omit it from a
  document, or set it under one format to omit it there only. When no author
  lists an affiliation, the title block falls back to an "Axiom Foundation"
  byline; the wordmark replaces that fallback. Author affiliations always
  print.
- `kicker`: short register line above the title; defaults to `WORKING PAPER`.
- `revision`: revision number shown with the ISO document date.
- `status`: Markdown body for the status banner; the format supplies its label.
- `theme`: Axiom is the sole v1 theme and is already selected. Leave Quarto's
  HTML `theme` override unset; shared values live in `theme-axiom.yml` so a
  future format can point the same partials at one new theme file.

See `example/paper.qmd` for a minimal two-format paper.

Rendering copies the format's resources beside the document: `fonts/` and
`axiom-wordmark.pdf` for PDF, `axiom-wordmark.svg` for HTML. A file of the same
name beside the document is overwritten. Add the copies beside source documents
to `.gitignore`. Projects with an output directory also copy the SVG beside
each rendered page there; publish it with the page.

## Development

`scripts/check.sh` validates the SVG assets, confirms the committed PDF
wordmark still matches the SVG, and renders test documents in every paper
format with and without the wordmark. It needs Quarto, XeLaTeX, xmllint,
rsvg-convert, pdftoppm and ImageMagick; CI runs it on every pull request.

`_extensions/axiom/assets/axiom-wordmark.svg` is the full lockup from the
[Axiom brand kit](https://github.com/TheAxiomFoundation/axiom-brand),
`svg/wordmark/full/axiom-full-w350-gradient.svg`, copied unchanged. Replace
it with a newer kit file rather than editing it. The PDF wordmark is a vector
conversion of that SVG, committed so rendering needs no conversion step.
After changing the SVG, run `scripts/build-wordmark-pdf.sh` and commit both
files, update the kit blob id in `scripts/check.sh`, and re-measure the left
padding that `partials/title.tex` trims and `axiom.scss` offsets so the first
glyph stays flush with the kicker.
