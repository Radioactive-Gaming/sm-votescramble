## [1.5.1] 2026-04-26

### Fixed

- A logic issue with tracking the vote count.

## [1.5.0] 2026-04-26

### Added

- Logging on successful plugin load.
- AutoExecConfig.

### Changed

- Updated logic for the command listener to reduce processing time.
- Updated logic for menu handling to replace if statements with a switch.
- Updating formatting.

## [1.4.0] 2026-04-25

### Changed

- Formatting updates

### Fixed

- Updated code to new declarations.
- Math failures in vote calculations due to incorrect types.
- Fixed missing return values for action functions.

## [1.3.0] 2026-04-25

### Changed

- Replaced morecolors.inc with the newer multicolors.inc.

### Fixed

- Updated the deprecated 'FloatDiv' symbol to the division operator.

### Removed

- Updater include file and functionality.

## [1.2.0] 2013-08-03

### Changed

- Moved scramble time to end of the round instead of the start of the next one, to prevent the round from starting twice

## [1.1.0] 2013-01-04

### Added

- Added ability to restrict access to !votescramble by overriding 'votescramble'

## [1.0.1] 2013-01-03

### Fixed

- Do not reset team scores when scrambling (credit: Powerlord)

## [1.0.0] 2013-01-02

Initial commit.
