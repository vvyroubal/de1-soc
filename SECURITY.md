# Security policy

This is a development-board bring-up project (bootloader, Linux image, FPGA
designs), not a production service. Still, if you find a security-relevant issue
we'd like to know.

## Reporting a vulnerability
Please report privately rather than opening a public issue:

- Preferred: open a **private security advisory** via GitHub
  (repository **Security → Report a vulnerability**), or
- contact the maintainer (see the author/contact details in the manual colophon,
  `manual/main_en.pdf`).

Include the affected component (bootloader / kernel config / rootfs / a script or
FPGA design), the version or commit, and steps to reproduce. We'll acknowledge and
respond as availability allows; this is a small, best-effort project.

## Known, intentional defaults (not vulnerabilities)
The shipped image is a **development** image with well-known default credentials:
users `debian` and `root`, password `temppwd`. This is documented and deliberate.
**Change the passwords immediately** (`passwd`) and do not expose the board to an
untrusted network with the defaults in place. Treat the image as a starting point
to harden, not a secured product.
