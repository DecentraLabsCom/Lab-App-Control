# Changelog

## [2.4.0] - 2025-11-19

### Added
- `tests/ArgumentParsingTests.ahk` regression suite that runs through common and Guacamole-specific CLI permutations.
- GitHub Actions matrix (`tests.yml`) executes the parser suite on every push/pr to `main` for Windows coverage.

### Fixed
- Preserves quoting when reconstructing commands split by Guacamole or cmd.exe before adding kiosk flags or custom close options.
- Rejects malformed `@close-coords` mixes and ensures tab-title quotes survive trimming in dual mode.

## [2.3.0] - 2025-xx-xx
- Refer to the `v2.3` tag for historical details.
