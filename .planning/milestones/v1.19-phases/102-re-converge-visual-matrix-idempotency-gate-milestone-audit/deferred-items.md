# Phase 102 Deferred Items

## Out-of-Scope Browser Failures Observed During 102-01

- `npx playwright test e2e/admin-screenshots.spec.js --grep "captures admin-screenshots light and dark matrix"` now gets past the duplicate `[data-rindle-admin-root]` shell lookup and fails on the already-recorded admin focus-token host-cascade issue: `[data-rindle-admin-theme="light"]` computes a 3px/0px/`rgb(16, 20, 23)` outline instead of the expected 2px/2px/`#123A35`.
- `npx playwright test e2e/admin-console.spec.js --grep "admin console top-level surfaces render the shell and seeded rows"` now gets past `expectAdminShell` and fails on a separate strict text locator: `getByText("Doctor checks")` matches both the heading and the visually hidden `Runtime/Doctor checks` caption.

Both failures are outside the 102-01 strict admin root helper scope. Do not resolve them by loosening root selection, reducing the admin matrix, deleting backstops, or adding a second visual lane.
