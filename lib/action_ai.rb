# frozen_string_literal: true

#--
# Copyright (c) David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require "abstract_controller"
require "action_ai/version"
require "action_ai/deprecator"

# Common Active Support usage in Action AI
require "active_support"
require "active_support/rails"
require "active_support/core_ext/class"
require "active_support/core_ext/module/attr_internal"
require "active_support/core_ext/string/inflections"
require "active_support/lazy_load_hooks"

# :include: ../README.rdoc
module ActionAI
  extend ::ActiveSupport::Autoload

  autoload :Agent
  autoload :Callbacks
  autoload :PromptHelper
  autoload :Parameterized
  autoload :Preview
  autoload :Previews, "action_ai/preview"
  autoload :TestCase
  autoload :TestHelper
  autoload :Interaction
  autoload :ImplicitInteraction
  autoload :ExecutionJob
  autoload :QueuedExecution

  def self.eager_load!
    super

    require "ruby_llm"
    RubyLLM.eager_autoload!

    Agent.descendants
         .reject(&:abstract?)
         .each(&:eager_load!)
  end
end

autoload :Mime, "action_dispatch/http/mime_type"

ActiveSupport.on_load(:action_view) do
  ActionView::Base.default_formats ||= Mime::SET.symbols
  ActionView::Template.mime_types_implementation = Mime
  ActionView::LookupContext::DetailsKey.clear
end
