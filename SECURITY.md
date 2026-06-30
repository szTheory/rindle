# Security Policy

## Supported Versions

Rindle is still pre-1.0. Security fixes are applied to the latest 0.x release
line only; older 0.x minors should upgrade to the latest release.

| Version | Supported |
| ------- | --------- |
| latest 0.x | Yes |
| older 0.x | No, upgrade to the latest release |

## Reporting a Vulnerability

Please report suspected vulnerabilities through GitHub Security Advisories:
open the repository's Security tab and choose **Report a vulnerability**.

Do not open a public issue for a vulnerability report. Rindle does not use an
email disclosure channel; GitHub Private Vulnerability Reporting is the private
intake path for security reports.

Expect an acknowledgment within a few business days. Triage and fix timing will
depend on severity, exploitability, and the affected release line.

Operational note: the **Report a vulnerability** button appears only after
Private Vulnerability Reporting is enabled in the repository settings.

## What to Report

Rindle handles untrusted media and security-sensitive delivery paths. Good
security reports include suspected issues in:

- Upload validation, filename handling, metadata validation, and storage-key
  sanitization before promotion.
- MIME and content-type sniffing, including spoofed extensions or confusing
  magic bytes.
- Malware scanning hooks, especially failures to scan before promotion.
- Signed, time-limited delivery URLs and accidental public exposure. See
  [Secure Delivery](guides/secure_delivery.md) for the private-by-default
  posture.
- Webhook HMAC verification, replay windows, raw-body handling, and secret
  handling for provider callbacks.
- Media subprocess argument handling for FFmpeg, FFprobe, libvips, or related
  tooling.

Reports that include a minimal reproduction, affected versions, and expected
versus observed behavior are the most actionable.
