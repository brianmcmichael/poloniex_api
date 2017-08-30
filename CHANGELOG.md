# Changelog
All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed
- Fixed logger calls on timeouts
- Replaced `Digest::HMAC` with `OpenSSL::HMAC` for Ruby 2.2+ support

## [0.0.2] - 2017-08-29

### Added
- Wrap get and post calls in retry loops
- Add timeout values to requests

### Changed
- Updated `market_trade_hist` to follow the call pattern

## 0.0.1 - 2017-08-27
### Added
- Public and private API commands return JSON response 

[Unreleased]: https://github.com/brianmcmichael/poloniex_api/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/brianmcmichael/poloniex_api/compare/v0.0.1...v0.0.2
