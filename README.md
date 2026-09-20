# Thermodynamics (ENGI 1111) — lecture notes

One source file per chapter. Everything below is built from it.

**The website is the lecture.** Gaps start covered and are uncovered one at a
time from the keyboard; the same page stays up afterwards. That is the whole
point — the screen in the room and the notes on Ultra are the same file, so a
"completed" version can never say something slightly different from what the
class actually saw.

| Output | Built by | Who it is for |
|:--|:--|:--|
| `_site/` | `./build.sh site` | the lecture view **and** the posted version; also holds the interactive figures |
| `pdf/ch02-student.pdf` | `./build.sh pdf` | students, printed before the lecture — gaps blank, so they still write |
| `pdf/ch02-complete.pdf` | `./build.sh pdf` | the paper twin of the site, for students who prefer print |
| `pdf/ch02-presenter.pdf` | `./build.sh pdf` | you — everything in small grey type with a one-line **Board:** prompt per gap |

`./build.sh` on its own does all of it.

### Running a lecture

Open the chapter page and press **P** for presentation mode (hides the site
furniture, enlarges the type). Then:

| key | |
|:--|:--|
| space, →, ↓, PageDown, or a clicker | uncover the next gap and scroll to it |
| ←, ↑, PageUp | cover the last one again |
| **A** | uncover everything |
| **H** | cover everything again |
| **P** | leave presentation mode |

Clicking a covered panel jumps straight to it — useful when someone asks about
something three steps back. A student opening the page later resumes where they
left off; `?all=1` on the URL opens it fully uncovered.

Maths is rendered by KaTeX served from `js/katex/` in this repository, not from
a CDN, so equations still render if the lecture-theatre network is slow or
blocked.

---

## How the source works

### Gaps

Anything you currently write on the board in the lecture is wrapped like this:

```markdown
::: {.gap height="45mm" hint="$P$--$V$ axes; mark both states, join them, label the path."}
$$ W = -\int P_\text{ext}\,\mathrm{d}V $$
:::
```

* `height` — how much blank space the student copy leaves. Only used there.
* `hint` — the one-line prompt that appears on **your** copy. Markdown, so maths works.

Which version gets built is set by `gapmode`:

* `reveal` — the website: covered, uncovered live (set in `_quarto.yml`)
* `student` — blank space of `height`, for the printed handout
* `complete` — everything shown
* `lecturer` — everything shown, small and grey, with the `hint` as a prompt

`build.sh` passes the right one for each output. You never maintain more than
one file.

### Boxes

```markdown
::: {.note} ... :::          ::: {.warning} ... :::
::: {.key} ... :::           ::: {.example} ... :::
::: {.activity} ... :::      ::: {.objectives} ... :::
::: {.solution} ... :::
```

`.solution` blocks are dropped from the student copy and kept everywhere else.
To release solutions separately, build with `-M solutions:true`.

### Figures

* **Line drawings** live in `figures/tikz/*.tex` as standalone TikZ files and
  are built to both PDF (for print) and SVG (for the web) by
  `./build-figures.sh`. In the `.qmd` always write the `.svg` path;
  `filters/figext.lua` swaps it for the PDF when building print.
* **Photographs and 3D renders** live in `figures/img/`.
* Add `{.wrap width=30%}` to an image to float it beside the text. Do not do
  this next to a heading or inside a note/example box — `wrapfigure` and
  breakable `tcolorbox`es fight.

### Interactive figures

`widgets/*.html` are self-contained pages, embedded in the website with an
`<iframe>` and replaced by a static figure in the PDF:

```markdown
::: {.content-visible when-format="html"}
```{=html}
<iframe src="widgets/pv-explorer.html" class="widget-frame"></iframe>
```
:::

::: {.content-visible when-format="pdf"}
![Static stand-in](figures/out/polytropic-family.svg)
:::
```

---

## Building locally

You need [Quarto](https://quarto.org/docs/get-started/) and a TeX distribution
(on Windows, [MiKTeX](https://miktex.org/) is easiest — let it install packages
on demand the first time).

```bash
./build.sh          # figures + three PDFs + website
./build.sh pdf      # PDFs only
./build.sh site     # website only
quarto preview      # live-reloading website while you edit
```

## Publishing to GitHub Pages

1. Create an empty repository on GitHub, e.g. `thermo-l1`.
2. In `_quarto.yml`, replace `USERNAME` in `site-url` with your GitHub username.
3. Push:

   ```bash
   git init
   git add .
   git commit -m "Chapter 2 in the new format"
   git branch -M main
   git remote add origin https://github.com/USERNAME/thermo-l1.git
   git push -u origin main
   ```

4. On GitHub: **Settings → Pages → Build and deployment → Source = GitHub
   Actions**.

Every push to `main` then rebuilds the figures, the PDFs and the website,
and publishes to `https://USERNAME.github.io/thermo-l1/`. Nothing needs
uploading to Ultra except a link.

If the repository is private, GitHub Pages needs a paid plan — for a public
course site, keep the repository public.

## Layout

```
ch02-first-law.qmd      the chapter -- text, gaps, examples, problems, solutions
index.qmd               the site's front page
_quarto.yml             website + HTML settings, filter list
_pdf.yml                print settings (kept separate so `quarto render` stays fast)
tex/preamble.tex        LaTeX: Durham colours, running heads, all the boxes
styles.css              the same boxes for the web, plus the reveal styling
js/lecture-reveal.html  the keyboard-driven reveal + presentation mode
js/katex/               self-hosted maths renderer (no CDN in the lecture theatre)
filters/gaps.lua        reveal / student / complete / lecturer, and solution visibility
filters/boxes.lua       ::: {.note} etc. -> LaTeX environment or styled div
filters/figext.lua      .svg -> .pdf for the print build
filters/wrapfig.lua     {.wrap} images float beside the text
figures/tikz/           line drawings, source
figures/img/            photographs and renders
widgets/                interactive figures
build.sh                everything
```
