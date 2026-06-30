# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-06-30

### Added

- Implicit `ask` behavior for AI actions without explicit prompts, matching Action Controller-style ergonomics.
- Action chaining, enabling users to construct complex AI workflows from discrete jobs.

### Fixed

- `echo` test model to support multiple chat interactions.

## [0.1.0] - 2026-05-05

Refactored from Action Mailer.

### Added

- In-memory AI testing provider (see `RubyLLM::Tester`).

### Changed

- Forked from Action Mailer and renamed framework internals to `ActionAI`.
- Decoupled the package identity and gem structure toward standalone Action AI usage.
- Introduced `ActionAI::Agent` as the primary base class and rewired the public API around `ask` / prompt execution instead of email delivery.
- Updated execution pipeline, callbacks, rescuable flow, previews, log subscriber, parameterized execution, test helpers, and railtie integration to the new agent lifecycle.
- Renamed helper/generator surface from mailer to agent (`mail_helper` -> `prompt_helper`; `rails g mailer` templates replaced with `rails g ai` templates).

### Removed

- Email-delivery-first concepts from the primary API surface (headers/delivery method workflow) in favor of prompt and model execution.
