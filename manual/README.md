# DE1-SoC Setup Manual (LaTeX)

Setup manual for the Terasic DE1-SoC — booting Linux on the Cyclone V HPS, plus
cross-compiling and runtime FPGA reconfiguration. Produced as **two separate
documents** (English and Croatian) that share one preamble.

## Files
| File | Purpose |
|------|---------|
| `preamble.tex` | Shared preamble — palette, code/callout styling, fonts, babel. |
| `main_en.tex` | English edition (title page + includes `content_en.tex`). |
| `content_en.tex` | English content. |
| `main_hr.tex` | Croatian edition (title page + includes `content_hr.tex`). |
| `content_hr.tex` | Croatian content (Hrvatski). |
| `Makefile` | Build targets. |

Outputs: **`main_en.pdf`** and **`main_hr.pdf`**.

## Build
```bash
make            # both editions
make en         # main_en.pdf only
make hr         # main_hr.pdf only
make clean      # remove build artifacts

# without make:
latexmk -pdf main_en.tex
latexmk -pdf main_hr.tex
# or plain:  pdflatex main_en.tex && pdflatex main_en.tex
```

Requires a full TeX Live (`babel` with croatian+english, `listings`, `tcolorbox`,
`hyperref`). Compiles with `pdflatex`; UTF-8 + T1 fonts render the Croatian
diacritics.

## Visual identity (VUKA brand)
Styling follows the Veleučilište u Karlovcu graphic standards:
- **Colours** — primary Pantone 235 C purple `#840B55` + Pantone 124 C gold
  `#EAAA00`; secondary palette (slate 431 C, red 704 C, green 349 C) drives the
  note / warning / tip callouts.
- **Type** — TeX Gyre Heros (a Helvetica clone standing in for the brand's Neue
  Haas Grotesk / Arial), Inconsolata for code.
- **Title page** — full purple cover with the gold VUKA wordmark, and a colophon
  crediting the author and the institution ("Created at Karlovac University of
  Applied Sciences").

## Author / institution block
Edit these macros in `preamble.tex` (one place, both editions):
```
\newcommand{\ManualAuthor}{Vedran Vyroubal}
\newcommand{\ManualEmail}{vedran.vyroubal [at] vuka.hr}   % obfuscated (no @) vs harvesting
\newcommand{\ManualInstHR}{Veleučilište u Karlovcu}
\newcommand{\ManualInstEN}{Karlovac University of Applied Sciences}
\newcommand{\ManualAddr}{Trg J. J. Strossmayera 9, 47000 Karlovac, Hrvatska}
```
> The email is shown obfuscated (`[at]` instead of `@`, no `mailto:` link) to
> reduce automated harvesting from the published PDF.

The official interlocking-star **logo mark** is not embedded (the brand book requires
the original artwork). Drop the vector/PNG into `preamble.tex`'s `\vukawordmarklight`/
`\vukawordmarkdark` if you have the asset; the wordmark is currently typographic.

## Editing content
- Keep `content_en.tex` and `content_hr.tex` structurally in sync (same sections, same order).
- Callout titles are per language: `\begin{note}[Napomena]`, `\begin{warn}[Upozorenje]`, `\begin{tip}[Savjet]`.
- The download sections name the vendor sources (Terasic Resources / System CD for
  images; Quartus Prime Lite from Intel/Altera for tools). Vendor URLs and page
  names change over time — treat them as starting points.
