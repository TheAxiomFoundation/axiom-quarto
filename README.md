# axiom-quarto

Quarto formats for Axiom working papers, with local static fonts for hermetic
PDF and HTML rendering.

```sh
quarto add TheAxiomFoundation/axiom-quarto
```

Use `axiom-paper-pdf` and `axiom-paper-html` in the document `format` block.

Metadata:

- `kicker`: short register line above the title; defaults to `WORKING PAPER`.
- `revision`: revision number shown with the ISO document date.
- `status`: Markdown body for the status banner; the format supplies its label.
- `theme`: Axiom is the sole v1 theme and is already selected. Leave Quarto's
  HTML `theme` override unset; shared values live in `theme-axiom.yml` so a
  future format can point the same partials at one new theme file.

See `example/paper.qmd` for a minimal two-format paper.
