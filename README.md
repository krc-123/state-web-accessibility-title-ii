# State government web accessibility, six months before the ADA Title II deadline

An automated accessibility scan of the three state government pages a family needs in the first months after a baby is identified as deaf or hard of hearing: the Medicaid application page, the Early Hearing Detection and Intervention (EHDI) program page, and the IDEA Part C early intervention page. All 50 states and the District of Columbia, 153 pages, scanned on 19 October 2026 with axe-core 4.14.0.

The Department of Justice's Title II rule requires state and local governments to meet WCAG 2.1 Level AA. The original deadline for states and large local governments was 24 April 2026. On 20 April 2026 the Department published an interim final rule pushing that to **26 April 2027** (and to 26 April 2028 for governments under 50,000 people and special districts). This repository is a baseline taken six months out. The scanner and the analysis are here so anyone can run it again at the deadline.

I run a national nonprofit for families of deaf children, and these three pages are the ones I send parents to. That is why these pages and not, say, the DMV.

## What the scan found

- **89 of 152 pages (59 percent) fail at least one WCAG 2.1 A or AA check that axe can detect.** 88 of those have at least one failure axe rates serious or critical.
- **Six states were clean on all three pages:** Florida, Indiana, Massachusetts, Missouri, South Carolina, and Vermont. Another four (Connecticut, Nevada, North Carolina, Pennsylvania) had a single failing element across three pages.
- **Mississippi, New Mexico, Kansas, Delaware, and Rhode Island are furthest from the standard.** Mississippi's EHDI and Part C pages on msdh.ms.gov carry 53 and 52 color contrast failures each. New Mexico's Part C page has 68 contrast failures and disables pinch zoom on mobile. Kansas's EHDI page has 35 contrast failures, Rhode Island's Medicaid page 25.
- **Color contrast is the problem.** It fails on 22 percent of pages and accounts for 57 percent of all failing elements (368 of 647). Three rules explain 74 percent of failing elements: color contrast, visible link text that does not match the accessible name (19 percent of pages, a screen reader and voice control problem), and links with no discernible text (11 percent).
- **Images with no alt text, the failure everyone has heard of, turn up on only 9 pages.** The common failures in 2026 are subtler than missing alt text and most of them are fixable in a stylesheet.
- **Medicaid application pages fail most often, Part C pages fail hardest.** 35 of 51 Medicaid pages had at least one failure, against 27 of 51 EHDI pages and 27 of 50 Part C pages. But Part C pages carry the most failing elements (5.3 per page, against 4.1 for EHDI and 3.4 for Medicaid), because a handful of them are a long way off.
- **The directories that point families to these pages are rotting.** 11 of the 153 URLs listed by the national directories I started from (CMS for Medicaid, NCHAM for EHDI, the ECTA Center for Part C) returned a 404, and 22 more were redirected to errors, blocked, or unreachable. The CMS list of state Medicaid application sites appears to date from July 2020; 20 of its 51 links did not lead the scanner to a working page. Every replacement is recorded in `pages.csv` with a note.

### Ten states with the most failing elements per page

| Rank | State | Pages scanned | Failing elements | Per page | Serious or critical |
|---|---|---|---|---|---|
| 1 | Mississippi | 3 | 128 | 42.7 | 128 |
| 2 | New Mexico | 3 | 80 | 26.7 | 79 |
| 3 | Kansas | 3 | 39 | 13.0 | 39 |
| 4 | Delaware | 3 | 31 | 10.3 | 31 |
| 5 | Rhode Island | 3 | 25 | 8.3 | 25 |
| 6 | Ohio | 3 | 24 | 8.0 | 24 |
| 7 | Illinois | 3 | 23 | 7.7 | 23 |
| 8 | Utah | 3 | 23 | 7.7 | 23 |
| 9 | Minnesota | 3 | 22 | 7.3 | 22 |
| 10 | West Virginia | 3 | 19 | 6.3 | 19 |

### Ten most common failing rules

| Rule | What it means | Impact | WCAG | Pages | Share | Elements |
|---|---|---|---|---|---|---|
| color-contrast | Text does not meet the minimum contrast ratio | serious | 1.4.3 | 33 | 22% | 368 |
| label-content-name-mismatch | Visible text is not part of the accessible name | serious | 2.5.3 | 29 | 19% | 73 |
| link-name | Links have no discernible text | serious | 2.4.4, 4.1.2 | 16 | 11% | 36 |
| image-alt | Images have no alternative text | critical | 1.1.1 | 9 | 6% | 15 |
| list | Lists contain elements that are not list items | serious | 1.3.1 | 7 | 5% | 12 |
| listitem | List items sit outside a list | serious | 1.3.1 | 7 | 5% | 39 |
| aria-allowed-attr | Unsupported ARIA attributes | critical | 4.1.2 | 6 | 4% | 25 |
| aria-roles | Invalid ARIA roles | critical | 4.1.2 | 6 | 4% | 8 |
| aria-prohibited-attr | ARIA attributes not permitted on the element | serious | 4.1.2 | 5 | 3% | 7 |
| frame-title | Frames with no accessible name | serious | 4.1.2 | 5 | 3% | 7 |

Full tables: `output/state_summary.csv`, `output/rule_summary.csv`, `output/page_summary.csv`.

![Lollipop chart ranking all 50 states and DC by failing elements per scanned page. Mississippi is far right at about 43 per page, New Mexico at about 27, then Kansas at 13; the long tail from Delaware down sits under 10, and six states at the bottom have zero.](figures/fig1_state_ranking.png)

![Heatmap of states by the three page types, Medicaid application, EHDI newborn hearing, and Part C early intervention, with each tile showing its failing element count. The worst tiles are Mississippi EHDI 63, Mississippi Part C 65, New Mexico Part C 73, Kansas EHDI 35, Delaware Part C 30, and Rhode Island Medicaid 25.](figures/fig2_state_program_heatmap.png)

![Bar chart of the twelve most common WCAG 2.1 A and AA failures by share of pages. Color contrast leads at 22 percent, label content name mismatch 19 percent, link name 11 percent, image alt 6 percent, then a tail of list, ARIA, frame, zoom, and link styling rules at 3 to 5 percent each.](figures/fig3_top_rules.png)

## What this does and does not measure

axe-core runs a fixed set of rules against the rendered page and reports a failure only when it is certain. That makes it a floor, not a ceiling. Deque's own research puts automated coverage at a bit over half of accessibility issues by volume, and the things it cannot judge are often the ones that matter most to the families these pages serve: whether a video is captioned accurately, whether an ASL video is placed where a signing user can find it, whether the application can be completed with a keyboard from start to finish, whether the reading level is reasonable. A page with zero failures here has passed the automated checks. It has not been shown to conform to WCAG 2.1 AA.

The reverse holds too. Every failure in `data/violations.csv` is a real failure of a specific success criterion, with the offending element recorded in `data/nodes.csv`.

Other limits worth knowing:

- One page per program per state, the entry page a family would land on, at a 1280 by 900 desktop viewport. Deeper pages and mobile layouts were not scanned.
- The headline numbers use only rules tagged WCAG 2.0 or 2.1, level A or AA, which is the Title II standard. Best-practice rules (landmarks, heading order, and so on) and WCAG 2.2-only rules were recorded but kept out of the counts; they are in `output/out_of_scope_rules.csv`.
- A page counts as scanned only if the server returned HTTP 200 and axe ran. One page, Arizona's Part C page on des.az.gov, sat behind a Cloudflare challenge that blocks automated browsers and is excluded. It is listed in `output/pages_excluded.csv`.
- The scanning environment blocked some third-party hosts. On 8 pages that included a web font host (Font Awesome or Google Fonts), which can shift the large-text threshold for contrast checks on a handful of elements. `data/pages_scanned.csv` records the blocked hosts for every page.
- Pages change. A scan on a different day will produce different numbers, which is rather the point of leaving the scanner here.

## Policy context

The Department of Justice published the Title II web and mobile accessibility rule on 24 April 2024 (28 CFR part 35, subpart H). It adopts WCAG 2.1 Level AA as the technical standard for state and local government web content and mobile apps, including content provided through contractors. On 20 April 2026 the Department published an interim final rule extending the compliance dates by a year: 26 April 2027 for public entities with a population of 50,000 or more, and 26 April 2028 for smaller entities and special district governments. Every state government falls in the first group.

The pages here are not a random sample of state web content. They are the pages a parent of a newly identified deaf child is sent to by the hospital, the audiologist, and the state EHDI program, in that order, usually within the first three months. Many of those parents are deaf themselves. Some have low vision. Contrast failures on the page that explains how to get a hearing aid covered are not an abstraction.

Sources: [ADA.gov, Fact sheet on the Title II web rule and the 2026 interim final rule](https://www.ada.gov/resources/2024-03-08-web-rule/); [ADA.gov, First steps toward complying with the rule](https://www.ada.gov/resources/web-rule-first-steps/); [Deque, automated testing study](https://www.deque.com/blog/automated-testing-study-identifies-57-percent-of-digital-accessibility-issues/).

## Reproducing it

The scan (Node, about ten minutes for 153 pages):

```
npm install
npx playwright install chromium
node scan.js pages.csv data/
```

The analysis (R, from RStudio open `analysis.R` and source it, or from a terminal):

```
Rscript analysis.R
```

`analysis.R` installs `tidyverse` and `scales` if they are missing and writes the tables to `output/` and the figures to `figures/`. The map (`figures/fig4_map.png`) needs the `usmap` package and a recent `ggplot2`; it is skipped with a message if either is out of date.

To re-run at the April 2027 deadline: run the scan into a new folder (say `data-2027/`), point the three `read_csv` lines at it, and the same script produces the comparison tables.

## Files

| Path | What it is |
|---|---|
| `pages.csv` | The 153 pages: state, program type, URL scanned, the URL the directory originally listed, where it came from, and a note where the directory URL had to be replaced |
| `scan.js` | The scanner. Playwright drives Chromium, injects axe-core, records every rule result |
| `data/pages_scanned.csv` | One row per page: final URL after redirects, HTTP status, title, axe version, rule counts, blocked third-party hosts, error if any |
| `data/violations.csv` | One row per failed rule per page: rule id, impact, WCAG criteria, tags, whether it is in the Title II scope, element counts by impact |
| `data/nodes.csv` | Up to five failing elements per rule per page: CSS selector, HTML snippet, axe's failure summary |
| `analysis.R` | Builds the summaries and figures |
| `output/` | State, rule, and page summary tables; headline numbers; the markdown tables above; the excluded page list |
| `figures/` | The charts |

Code is MIT licensed. The data files are released under CC0; use them however you like, and please cite the scan date.
