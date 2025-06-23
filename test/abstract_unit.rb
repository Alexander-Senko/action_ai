# frozen_string_literal: true

require "active_support/core_ext/kernel/reporting"

# These are the normal settings that will be set up by Railties
# TODO: Have these tests support other combinations of these values
silence_warnings do
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end

module Rails
  def self.root
    File.expand_path("..", __dir__)
  end
end

require "active_support/testing/autorun"
require "active_support/testing/method_call_assertions"
require "action_ai"
require "action_ai/test_case"

# Emulate AV railtie
require "action_view"
ActionAI::Base.include(ActionView::Layouts)

# Show backtraces for deprecated behavior for quicker cleanup.
ActionAI.deprecator.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

FIXTURE_LOAD_PATH = File.expand_path("fixtures", __dir__)
ActionAI::Base.view_paths = FIXTURE_LOAD_PATH

ActionAI::Base.delivery_job = ActionAI::MailDeliveryJob

class ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions
end
