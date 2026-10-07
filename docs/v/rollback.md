# Roll back to a known-good release

Roll back by installing an earlier published version from the **same channel**
you use now. Keep the CLI, Desktop installer, and any downstream package on a
compatible release; do not replace the V runtime with the retired Python CLI.

## Choose and verify the version

1. Identify the last known-good tag from the
   [GitHub Releases](https://github.com/ulises-jeremias/agent-toolkit/releases).
2. Download the matching platform artifact or installer from that tag. For
   GitHub binary assets, use that same release's `SHA256SUMS` and follow the
   verification steps in [Trust](../TRUST.md).
3. Reinstall or select that version using the distribution channel's normal
   mechanism. For example:

   ```bash
   uv tool install 'agent-toolkit-cli=<version>'
   npm install --global 'agent-toolkit-cli@<version>'
   ```

   For Homebrew or AUR, install the package revision that points to the chosen
   release. For Desktop, reinstall the platform package from the chosen GitHub
   Release; its bundled backend travels with the app.
4. Confirm the result with `agent-toolkit version` or Desktop's Settings and
   verify that the affected workflow recovers.

Do not retag or overwrite a published release. The release process and
artifact naming are documented in [Releasing](../RELEASING.md); installation
channels and checksum expectations are in [Installation](../INSTALLATION.md)
and [Trust](../TRUST.md).

## Migration history

The V cutover and the retired Python implementation are preserved under
[`archive/`](archive/README.md). Those records explain the migration but are
not rollback instructions for current releases.
