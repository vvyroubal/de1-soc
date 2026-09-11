# DE1-SoC manual -- separate English and Croatian editions
LATEXMK := latexmk -pdf -interaction=nonstopmode -halt-on-error

.PHONY: all en hr clean
all: en hr

en: main_en.pdf
hr: main_hr.pdf

main_en.pdf: main_en.tex content_en.tex preamble.tex
	$(LATEXMK) main_en.tex

main_hr.pdf: main_hr.tex content_hr.tex preamble.tex
	$(LATEXMK) main_hr.tex

clean:
	latexmk -C main_en.tex main_hr.tex 2>/dev/null || true
	rm -f *.aux *.log *.out *.toc *.fls *.fdb_latexmk build*.log
