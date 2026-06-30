# AGENTS.md

## Scope and source notes
- From the requested glob (`**/{.github/copilot-instructions.md,AGENT.md,AGENTS.md,CLAUDE.md,.cursorrules,.windsurfrules,.clinerules,.cursor/rules/**,.windsurf/rules/**,.clinerules/**,README.md}`), only this root `AGENTS.md` is present in the repo.
- Use `README.rdoc` plus code/tests as the canonical source of behavior.

## Big picture architecture
- `ActionAI::Agent` (`lib/action_ai/agent.rb`) is the core abstraction: ActionMailer-like class API, ActionView rendering, and RubyLLM execution.
- Class action calls are intercepted via `method_missing` and return lazy `ActionAI::Interaction` objects (`lib/action_ai/interaction.rb`).
- Execution flow is: `AgentClass.action(args)` -> `Interaction#message`/delegated call -> `Agent#process` -> implicit `ask` (if not already performed) -> `RubyLLM::Chat#ask`.
- Prompt text is rendered from templates through `render_to_string` (`Agent#prompt`), so view files are first-class, not an afterthought.
- Defaults are merged in `Agent#apply_defaults`; proc/lambda defaults are evaluated at runtime (`compute_default`).
- Parameterized execution is a first-class path: `Agent.with(params).action(...)` uses `ActionAI::Parameterized::PromptExecution` (subclass of `Interaction`) and injects params into the agent before `process` (`lib/action_ai/parameterized.rb`).

## Async and job boundaries
- `.later` enqueues `ActionAI::ExecutionJob` (`lib/action_ai/execution_job.rb`) with agent class name + action + args (+ optional params).
- Important: only action arguments are serialized; mutating/reading the interaction before `.later` is intentionally blocked (`Interaction#enqueue_execution`).
- Default queue is `:ai_agents` (`lib/action_ai/queued_execution.rb`), override per agent via `self.execute_later_queue_name`.
- Agent-level `rescue_from` handlers are used by both sync and async paths (`lib/action_ai/rescuable.rb`, `ExecutionJob#handle_exception_with_agent_class`).

## Conventions specific to this repo
- In practice, core prompt API is `ask`; several tests/fixtures still exercise older naming conventions.
- Prefer `before_action`/`after_action` for action-time setup/teardown (including `params` hydration for parameterized agents); see `test/agents/params_agent.rb` and callback coverage in `test/agent_test.rb`.
- Callback model for execution is custom: `before_execution`, `after_execution`, `around_execution` (`lib/action_ai/callbacks.rb`).
- `process.action_ai` is asserted in `test/agent_test.rb`; execution/process log output is covered by `test/log_subscriber_test.rb` via `ActionAI::LogSubscriber` (`lib/action_ai/log_subscriber.rb`).
- Tests rely on fixture-based templates under `test/fixtures/**` and set `ActionAI::Agent.view_paths` in `test/abstract_unit.rb`.

## Integration points
- Rails integration is in `lib/action_ai/railtie.rb`: URL helpers, preview paths, config propagation, and inclusion of `ActionAI::TestHelper` in integration tests.
- Preview system is `ActionAI::Preview` (`lib/action_ai/preview.rb`), loading `*_preview.rb` from configured preview paths.
- Runtime dependency boundary is `ruby_llm`; tests use `ruby_llm/tester` (see `test/agents/base_agent.rb`) to avoid real provider calls.

## Developer workflow (validated here)
- Run full suite: `bundle exec rake test`
- Run isolated file-by-file mode: `bundle exec rake test:isolated`
- Run a single test file: `bundle exec ruby -w -Ilib:test test/agent_test.rb`
- The current workspace state has many failing tests (API mismatch and provider/rate-limit related), so prefer targeted runs while changing specific behavior.

## Style and editing guardrails
- RuboCop is strict and opt-in (`AllCops: DisabledByDefault`); follow existing conventions in `.rubocop.yml` (notably double quotes and explicit method parentheses).
- Preserve backward-compatibility cues in tests and comments unless the change explicitly modernizes the API surface.

