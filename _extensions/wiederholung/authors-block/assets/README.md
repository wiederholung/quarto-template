# Author-block assets

`orcid.svg` is the unmodified official ORCID iD artwork from the ORCID source repository:
https://github.com/ORCID/ORCID-Source/blob/main/orcid-web/src/main/webapp/static/img/id-icon.svg
Git blob: `48e146a675629af232fc44dac8a06f23702e292a` (retrieved 2026-11-15).

`orcid.pdf` contains vector paths converted from this SVG for LaTeX.
`orcid.png` is a 128 × 128 compatibility fallback for Word viewers without SVG support;
modern Word uses the embedded SVG. Both are bundled, so ordinary rendering needs no
network access or SVG converter. To regenerate the derivatives with librsvg 2.40.20:

```sh
rsvg-convert -w 256 -h 256 -f pdf -o orcid.pdf orcid.svg
rsvg-convert -w 128 -h 128 -o orcid.png orcid.svg
```

ORCID and its icons are trademarks of ORCID, Inc. The icon is not covered by the extension's MIT license.
Display guidance: https://info.orcid.org/documentation/integration-guide/orcid-id-display-guidelines/ .
This extension formats author-supplied identifiers and checks their syntax and checksum; it does not perform OAuth or certify author identity. Treat supplied IDs accordingly in your publication workflow.

## Correspondence envelope

`envelope.svg` is original artwork included under the extension's MIT license.
It retains the upstream envelope's default black text color, rather than the
gray used in the Nature samples. Its 102 x 90 canvas contains a 102 x 78 black
outline with six clear units above and below; this provides optical alignment
without superscripting the Word image. `envelope.png` is its 204 x 180 fallback:

```sh
rsvg-convert -w 204 -h 180 -o envelope.png envelope.svg
```

`envelope.pdf` is the same SVG converted with `rsvg-convert -f pdf` for the LaTeX backend.
