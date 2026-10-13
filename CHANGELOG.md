# Changelog

All notable changes to this project will be documented in this file.


## [0.4.0] - UNRELEASED

### Changed

- Moved agent-level configuration to RubyLLM agents.

### Added

#### Configuration

- RubyLLM agent configuration DSL support on `ActionAI::Agent`: class methods `model`, `instructions`, `tools`, `tool_options`, `server_tools`, `thinking`, `citations`, `caching`, `compaction`, `provider_options`, `headers`, `schema`, `fallbacks`, `context`, `chat_model`, `inputs`, `temperature`, `max_output_tokens`, and `end_user` configure a private, internally managed `RubyLLM::Agent` subclass.
  `chat` is built via that agent’s `.chat` instead of plain `RubyLLM.chat`.
- Parameters set through `ActionAI::Parameterized` are forwarded as the agent’s runtime `inputs`.

### Removed

#### Configuration

- `default`/`default_options=` class method and `default_params` class attribute.
  Use the RubyLLM agent DSL (`model`, `instructions`, and so on) instead.


## [0.3.0] - 2026-10-13

### Changed

- Moved to RubyLLM 2.
- Dropped `echo` test model in favor of `echo` protocol.

### Added

#### Structured output

- `.schema` class method on any `ActiveModel::API` model, returning a cached `Schematist::Schema` instance derived from the model’s attribute types and constraints.
  - Include Active Record associations as nested schemas via objects/arrays.
    Consider associations registered for _nested attributes_ only.
  - Prefer custom schemas over inferred ones.
    Define them as `<ModelName>Schema < ActionAI::Schema` classes under `app/schemas`.
- `#returns(ModelClass)` instance method in agent actions: configures structured output via `chat.with_schema` and decorates the resulting `RubyLLM::Message` with `#object` returning a model instance.
  - Use Strong Parameters to decorate returned JSON for security reasons.
    AI model’s output shouldn’t be considered a trusted input.
- `#returns([ModelClass])` array syntax: configures an array schema and `#object` returns an array of model instances.


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
