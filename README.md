# supply-chain-example

GoReleaser + Go Mod proxying + Cosign keyless signing + Syft SBOM generation example.

## How it works

GoReleaser manages the entire thing, basically.

It will:

- build using the Go Mod Proxy as source of truth
- call `syft` to create the SBOMs
- create the checksum file
- sign it with `cosign`
- create a docker image using the binary it just built (thus, the binary inside the docker image is the same as the one released)
- sign the docker image with `cosign` as well

## Verifying

Your users will need to know how to verify the artifacts, and this is what this
section is all about.

The first thing we need to do, is get the current latest version:

```bash
export VERSION="$(gh release list -L 1 -R goreleaser/example-supply-chain --json=tagName -q '.[] | .tagName')"
```

Then, we download the `checksums.txt` and the signature bundle
(`checksums.txt.sigstore.json`) files, and then verify them:

```bash
wget https://github.com/goreleaser/example-supply-chain/releases/download/$VERSION/checksums.txt
wget https://github.com/goreleaser/example-supply-chain/releases/download/$VERSION/checksums.txt.sigstore.json
cosign verify-blob \
    --certificate-identity "https://github.com/goreleaser/example-supply-chain/.github/workflows/release.yml@refs/tags/$VERSION" \
    --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
    --bundle "checksums.txt.sigstore.json" \
    ./checksums.txt
```

This should succeed - which means that we can from now on verify any artifact
from the release with this checksum file!

You can then download any file you want from the release, and verify it with, for example:

```bash
wget "https://github.com/goreleaser/example-supply-chain/releases/download/$VERSION/supply-chain-example_linux_amd64.tar.gz"
sha256sum --ignore-missing -c checksums.txt
```

Which should, ideally, say "OK".

You can then inspect the SBOM file to see the entire dependency tree of the
binary, check for vulnerable dependencies and whatnot.

To get the SBOM of an artifact, you can use the same download URL, adding
`.sbom.json` to the end of the URL, and we can then check it out with `grype`:

```bash
wget "https://github.com/goreleaser/example-supply-chain/releases/download/$VERSION/supply-chain-example_linux_amd64.tar.gz.sbom.json"
sha256sum --ignore-missing -c checksums.txt
grype sbom:supply-chain-example_linux_amd64.tar.gz.sbom.json
```

Finally, we can also use the `gh` CLI to verify the attestations:

```bash
gh attestation verify \
  --owner goreleaser \
  *.tar.gz
```

Docker images are a bit simpler, you can verify them with cosign
and grype directly, and check the attestations as well.

Signature:

```bash
cosign verify \
  --certificate-identity "https://github.com/goreleaser/example-supply-chain/.github/workflows/release.yml@refs/tags/$VERSION" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "ghcr.io/goreleaser/example-supply-chain:$VERSION"
```

Vulnerabilities:

```bash
grype "docker:ghcr.io/goreleaser/example-supply-chain:$VERSION"
```

Attestations:

```bash
gh attestation verify \
  --owner goreleaser \
  "oci://ghcr.io/goreleaser/example-supply-chain:$VERSION"
```

If all these checks are OK, you have a pretty good indication that everything
is good.
