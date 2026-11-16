# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Use GitHub's private reporting: on this repository, open the **Security** tab,
choose **Report a vulnerability**, and describe what you found. Only the
maintainer can see it. Include the version (Settings, About), your macOS
version, and steps to reproduce.

You can expect an acknowledgement within a week, and a fix or a plan within
a month for anything serious. You will be credited in the release notes unless
you prefer not to be.

## Supported versions

Only the latest release gets security fixes.

## What is in scope

Haul runs a small web server so its browser extension can hand it downloads.
These are the parts most worth testing:

- **The local bridge** (`app/lib/services/bridge`). It listens only on
  `127.0.0.1`, checks the `Host` header, requires a secret token (compared in
  constant time) on every route that does anything, limits bodies to 256 KB,
  accepts only `http` and `https` links, and sends no CORS headers. Anything that
  lets a web page or another user on the Mac drive it is in scope.
- **The pairing token** (stored in Haul's settings database, shown only by the
  Copy token button).
- **Stored secrets.** Proxy and site-login passwords belong in the macOS
  Keychain only. A password found in the database, a log or a banner is a bug.
- **Cookies** the browser extension forwards to the app. They go only to the app
  on the same Mac and are used only to fetch that one file.
- **File handling:** a download that can write outside its folder, overwrite an
  existing file, or run something.
- **The extension** (`extension/`): permissions it uses beyond what
  the extension's store description explains.
- **Release integrity:** the signing and notarization scripts and the GitHub
  Actions workflows.

## Out of scope

- Problems that need the attacker to already control the person's Mac or
  account (for example, reading the user's own files).
- A website serving a file that is harmful. Haul downloads what it is told to.
- Findings about a development build, or about tools used only to build Haul.
- Denial of service against your own machine through huge downloads.

## For people running Haul

- Download releases only from this repository's Releases page.
- Treat the pairing token like a password. If you think it leaked, it cannot be
  regenerated from the UI yet; quit Haul and delete the `bridgeToken` row in
  its settings database, and a new one is made at the next start (then pair the
  extension again).
