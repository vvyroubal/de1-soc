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

## Editing content
- Keep `content_en.tex` and `content_hr.tex` structurally in sync (same sections, same order).
- Callout titles are per language: `\begin{note}[Napomena]`, `\begin{warn}[Upozorenje]`, `\begin{tip}[Savjet]`.
- The download sections name the vendor sources (Terasic Resources / System CD for
  images; Quartus Prime Lite from Intel/Altera for tools). Vendor URLs and page
  names change over time — treat them as starting points.
