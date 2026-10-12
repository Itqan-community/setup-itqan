# setup-itqan

Install the [itqan CLI](https://github.com/Itqan-community/itqan-cli) in a GitHub Actions
workflow, then install your project's [Itqan](https://cms.itqan.dev) Quranic assets from its
`itqan-assets.yaml` and `itqan-assets.lock`.

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: itqan-community/setup-itqan@v1
  - run: itqan install
```

The action downloads the standalone `itqan` binary for the runner from the
[itqan-cli releases](https://github.com/Itqan-community/itqan-cli/releases), checks it against
the release's `SHA256SUMS`, caches it and puts it on the `PATH`. It runs on Linux (x64, arm64),
macOS (arm64, x64) and Windows (x64) runners, and needs no Python.

## Inputs

| Input | Default | Description |
|---|---|---|
| `version` | `latest` | The itqan version to install, such as `0.1.3`. `latest` is the latest final release. |
| `registry-url` | the public registry | Sets `ITQAN_REGISTRY_URL` for the rest of the job. |
| `install` | `false` | Also run `itqan install`. |
| `working-directory` | `.` | Where to run `itqan install`: the folder with `itqan-assets.yaml`. |
| `api-key` | | An API key for `itqan install`. Needed only for assets that require access approval. |
| `cache` | `true` | Cache the binary with `actions/cache`. |

## Outputs

| Output | Description |
|---|---|
| `version` | The installed itqan version, such as `0.1.3`. |
| `path` | The path to the `itqan` executable. |
| `cache-hit` | Whether the binary came from the cache. |

## Examples

Pin the CLI and install in one step:

```yaml
- uses: itqan-community/setup-itqan@v1
  with:
    version: 0.1.3
    install: true
```

Assets that need access approval need the API key of an account that was granted access. Store
it as a repository secret and pass it as `api-key`, or as `ITQAN_API_KEY` to the steps that run
`itqan`:

```yaml
- uses: itqan-community/setup-itqan@v1
- run: itqan install
  env:
    ITQAN_API_KEY: ${{ secrets.ITQAN_API_KEY }}
```

A project in a subfolder:

```yaml
- uses: itqan-community/setup-itqan@v1
  with:
    install: true
    working-directory: apps/mobile
```

### Checking dependency update PRs

`itqan install` uses the exact versions in `itqan-assets.lock`, so running it on a pull request
that bumps an asset version checks that the new version resolves and downloads:

```yaml
name: Assets
on:
  pull_request:
    paths: [itqan-assets.yaml, itqan-assets.lock]
jobs:
  install:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: itqan-community/setup-itqan@v1
        with:
          install: true
          api-key: ${{ secrets.ITQAN_API_KEY }}
```

## Releasing

Publish a GitHub Release tagged `vX.Y.Z` from `main`. The
[major-tag workflow](.github/workflows/major-tag.yml) then moves `vX` to it, which is what
`@v1` resolves to. Tick *Publish this Action to the GitHub Marketplace* on the release to update
the Marketplace listing.

## License

[MIT](LICENSE)
