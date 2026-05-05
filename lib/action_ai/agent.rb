# frozen_string_literal: true

require "ruby_llm"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/hash/except"
require "active_support/core_ext/module/anonymous"
require "memery"

require "action_ai/log_subscriber"
require "action_ai/rescuable"

module ActionAI
  # = Action AI \Agent
  #
  # Action AI allows you to send AI prompts from your application using an agent model and views.
  #
  # == Agent Models
  #
  # To use Action AI, you need to create an agent model.
  #
  #   $ bin/rails generate ai:agent Generator
  #
  # The generated model inherits from <tt>ApplicationAI</tt> which in turn
  # inherits from +ActionAI::Agent+. An agent model defines methods
  # used to generate an AI prompt. In these methods, you can set up variables to be used in
  # the prompt views, options on the AI model used such as the <tt>:model</tt> ID, and attachments.
  #
  #   class ApplicationAI < ActionAI::Agent
  #     default model: 'gpt-4o-mini',
  #             provider: :openai
  #   end
  #
  #   class Generator < ApplicationAI
  #     default model: 'gpt-4o'
  #
  #     def code(task, language)
  #       @task     = task
  #       @language = language
  #     end
  #   end
  #
  # Within the agent method, you have access to the following methods:
  #
  # * <tt>attachments</tt> - Allows you to add attachments to your prompt in an intuitive
  #   manner; <tt>attachments << 'url_or_path/to/filename.png'</tt>
  #
  # * <tt>ask</tt> - Allows you to specify a prompt to be sent.
  #   Like +render+ in Action Controller, this is optional.
  #
  # The +ask+ method uses [rdoc-ref:RubyLLM::Chat#ask] under the hood and provides the same API,
  # except that +prompt+ is optional. If the +prompt+ is not specified, it will be rendered from the view.
  #
  # == Prompt views
  #
  # Like Action Controller, each agent class has a corresponding view directory in which each
  # method of the class looks for a template with its name.
  #
  # To define a template to be used with an agent, create an <tt>.erb</tt> file with the same
  # name as the method in your agent model. For example, in the agent defined above, the template at
  # <tt>app/ai/prompts/generator/code.erb</tt> would be used to generate the prompt.
  #
  # Variables defined in the methods of your agent model are accessible as instance variables in their
  # corresponding view.
  #
  # Prompts by default are sent in plain text, so a sample view for our model example might look like this:
  #
  #   You are an expert <%= @language.to_s.camelize %> developer.
  #   Write clean, well-commented code to accomplish the following:
  #   <%= @task %>
  #
  # You can even use Action View helpers in these views. For example:
  #
  #   You are an expert <%= t @language, scope: 'languages' %> developer.
  #   Write clean, well-commented code to accomplish the following:
  #   <%= @task %>
  #
  # If you need to access the AI provider or model in the view, you can do that through chat object:
  #
  #   You are a <%= chat.model.name %> model, an expert <%= @language.to_s.camelize %> developer.
  #   Write clean, well-commented code to accomplish the following:
  #   <%= @task %>
  #
  #
  # == Generating URLs
  #
  # URLs can be generated in agent views using <tt>url_for</tt> or named routes. Unlike controllers from
  # Action Pack, the agent instance doesn't have any context about the incoming request, so you'll need
  # to provide all of the details needed to generate a URL.
  #
  # When using <tt>url_for</tt> you'll need to provide the <tt>:host</tt>, <tt>:controller</tt>, and <tt>:action</tt>:
  #
  #   <%= url_for(host: "example.com", controller: "projects", action: "show", id: @project.id) %>
  #
  # When using named routes you only need to supply the <tt>:host</tt>:
  #
  #   <%= project_url(@project, host: "example.com") %>
  #
  # You should use the <tt>named_route_url</tt> style (which generates absolute URLs) and avoid using the
  # <tt>named_route_path</tt> style (which generates relative URLs), since a model reading the prompt will
  # have no concept of a current URL from which to determine a relative path.
  #
  # It is also possible to set a default host that will be used in all agents by setting the <tt>:host</tt>
  # option as a configuration option in <tt>config/application.rb</tt>:
  #
  #   config.action_ai.default_url_options = { host: "example.com" }
  #
  # You can also define a <tt>default_url_options</tt> method on individual agents to override these
  # default settings per-agent.
  #
  # By default when <tt>config.force_ssl</tt> is +true+, URLs generated for hosts will use the HTTPS protocol.
  #
  # == Sending prompts
  #
  # Once an agent action and template are defined, you can chat with an AI model using your prompt
  # or defer its creation and all the interactions for later:
  #
  #   Generator.code("Parse CSV", :ruby).content  # returns the generated code
  #   prompt = Generator.code("Parse CSV", :ruby) # => an ActionAI::Interaction object
  #   prompt.run                                  # generates and executes the prompt now
  #
  # The ActionAI::Interaction class is a wrapper around a delegate that will call
  # your method to generate the prompt. If you want direct access to the delegator, or +RubyLLM::Message+,
  # you can call the <tt>message</tt> method on the ActionAI::Interaction object.
  #
  #   Generator.code("Parse CSV", :ruby).message # => a RubyLLM::Message object
  #
  # Action AI is nicely integrated with Active Job so you can generate and send prompts in the background
  # (example: outside of the request-response cycle, so the user doesn't have to wait on it):
  #
  #   Generator.code("Parse CSV", :ruby).later # enqueue the AI processing to Active Job
  #
  # Note that <tt>later</tt> will execute your method from the background job.
  #
  # You never instantiate your agent class. Rather, you just call the method you defined on the class itself.
  #
  # == Attachments
  #
  # Sending attachments with prompts is easy:
  #
  #   class Generator < ApplicationAI
  #     def code(task, language, spec_file = nil)
  #       @task     = task
  #       @language = language
  #       attachments << spec_file if spec_file
  #     end
  #   end
  #
  # If you need to send attachments with no prompt, you need to create an empty view for it,
  # or pass an empty prompt explicitly:
  #
  #     class Generator < ApplicationAI
  #       def code(spec_file)
  #         attachments << spec_file
  #         ask ""
  #       end
  #     end
  #
  # == Default \Hash
  #
  # Action AI provides some intelligent defaults for your AI interactions, these are usually specified in a
  # default method inside the class definition:
  #
  #   class Generator < ApplicationAI
  #     default model: 'gpt-4o'
  #   end
  #
  # You can pass in any config value that a +RubyLLM::Chat+ accepts.
  #
  # Finally, Action AI also supports passing <tt>Proc</tt> and <tt>Lambda</tt> objects into the default hash,
  # so you can define methods that evaluate as the message is being generated:
  #
  #   class Generator < ApplicationAI
  #     default model: -> { Current.user.preferred_model },
  #             api_key: proc { Current.user.ai_api_key }
  #   end
  #
  # Note that the proc/lambda is evaluated right at the start of the prompt generation, so if you
  # set something in the default hash using a proc, and then set the same thing inside of your
  # agent method, it will get overwritten by the agent method.
  #
  # It is also possible to set these default options that will be used in all agents through
  # the <tt>default_options=</tt> configuration in <tt>config/application.rb</tt>:
  #
  #    config.action_ai.default_options = { provider: :openai, model: "gpt-4o-mini" }
  #
  # == \Callbacks
  #
  # You can specify callbacks using <tt>before_action</tt> and <tt>after_action</tt> to manage your AI interactions,
  # and using <tt>before_execution</tt> and <tt>after_execution</tt> for wrapping the prompt execution process.
  # For example, when you want to add default attachments and log execution for all prompts
  # executed by a certain agent class:
  #
  #   class Generator < ApplicationAI
  #     before_action :add_shared_context!
  #     after_execution :log_costs
  #
  #     def code(task, language)
  #       @task     = task
  #       @language = language
  #     end
  #
  #     private
  #       def add_shared_context!
  #         @context = Rails.root.join('ARCHITECTURE.md').read
  #       end
  #
  #       def log_costs
  #         Rails.logger.info "Generated code using #{message.input_tokens} input and #{message.output_tokens} output tokens."
  #       end
  #   end
  #
  # Action callbacks in Action AI Agent are implemented using
  # AbstractController::Callbacks, so you can define and configure
  # callbacks in the same manner that you would use callbacks in classes that
  # inherit from ActionController::Base.
  #
  # Note that unless you have a specific reason to do so, you should prefer
  # using <tt>before_action</tt> rather than <tt>after_action</tt> in your
  # Action AI Agent classes for setup.
  #
  # == Rescuing Errors
  #
  # +rescue+ blocks inside of an agent method cannot rescue errors that occur
  # outside of rendering -- for example, record deserialization errors in a
  # background job.
  #
  # To rescue errors that occur during any part of the AI interaction process, use
  # {rescue_from}[rdoc-ref:ActiveSupport::Rescuable::ClassMethods#rescue_from]:
  #
  #   class Generator < ApplicationAI
  #     rescue_from RubyLLM::ApiQuotaExceededError do |error|
  #       Rails.logger.warn "API quota exceeded: #{error.message}"
  #     end
  #
  #     def code(task, language)
  #       @task     = task
  #       @language = language
  #     end
  #   end
  #
  # == Previewing prompts
  #
  # You can preview your prompt templates visually by adding a prompt preview file to the
  # <tt>ActionAI::Agent.preview_paths</tt>. Since prompts may do something interesting
  # with database data, you may need to write some scenarios to load messages with fake data:
  #
  #   class GeneratorPreview < ActionAI::Preview
  #     def code
  #       Generator.code("Sort an array efficiently", :ruby)
  #     end
  #   end
  #
  # Methods must return a +RubyLLM::Message+ object which can be generated by calling the agent
  # method without the additional <tt>content</tt> / <tt>later</tt>. The location of the
  # agent preview directories can be configured using the <tt>preview_paths</tt> option which has a default
  # of <tt>test/ai/agents/previews</tt>:
  #
  #   config.action_ai.preview_paths << "#{Rails.root}/lib/ai/previews"
  #
  # An overview of all previews is accessible at <tt>http://localhost:3000/rails/ai/agents</tt>
  # on a running development server instance.
  #
  # == Configuration options
  #
  # These options are specified on the class level, like
  # <tt>ActionAI::Agent.raise_execution_errors = true</tt>
  #
  # * <tt>default_options</tt> - You can pass this in at a class level as well as within the class itself as
  #   per the above section.
  #
  # * <tt>logger</tt> - the logger is used for generating information on prompt execution if available.
  #   Can be set to +nil+ for no logging. Compatible with both Ruby's own +Logger+ and Log4r loggers.
  #
  # * <tt>execution_job</tt> - The job class used with <tt>later</tt>. Agents can set this to use a
  #   custom execution job. Defaults to +ActionAI::ExecutionJob+.
  #
  # * <tt>execute_later_queue_name</tt> - The queue name used by <tt>later</tt> with the default
  #   <tt>execution_job</tt>. Agents can set this to use a custom queue name.
  class Agent < AbstractController::Base
    include Callbacks
    include ImplicitInteraction
    include QueuedExecution
    include Rescuable
    include Parameterized
    include Previews

    abstract!

    include AbstractController::Rendering

    include AbstractController::Logger
    include AbstractController::Helpers
    include AbstractController::Translation
    include AbstractController::AssetPaths
    include AbstractController::Callbacks
    include AbstractController::Caching

    include ActionView::Layouts

    include Memery

    PROTECTED_IVARS = AbstractController::Rendering::DEFAULT_PROTECTED_INSTANCE_VARIABLES + [:@_action_has_layout]

    helper ActionAI::PromptHelper

    class_attribute :default_params, default: {
      # none
    }.freeze

    class << self
      # Returns the name of the current agent. This method is also being used as a path for a view lookup.
      # If this is an anonymous agent, this method will return +anonymous+ instead.
      def agent_name
        @agent_name ||= anonymous? ? "anonymous" : name.underscore
      end
      # Allows to set the name of current agent.
      attr_writer :agent_name
      alias :controller_path :agent_name

      # Allows to set defaults through app configuration:
      #
      #    config.action_ai.default_options = { provider: :openai }
      def default(value = nil)
        self.default_params = default_params.merge(value).freeze if value
        default_params
      end
      alias :default_options= :default

    private
      def method_missing(method_name, ...)
        if action_methods.include?(method_name.name)
          Interaction.new(self, method_name, ...)
        else
          super
        end
      end

      def respond_to_missing?(method, include_all = false)
        action_methods.include?(method.name) || super
      end
    end

    attr_internal :message

    memoize def chat = RubyLLM.chat(**apply_defaults)

    def process(method_name, *args) # :nodoc:
      payload = {
        agent: self.class.name,
        action: method_name,
        args: args
      }

      ActiveSupport::Notifications.instrument("process.action_ai", payload) do
        super
      end
    end
    ruby2_keywords(:process)

    def response_body = message&.content

    # Returns the name of the agent object.
    def agent_name = self.class.agent_name

    def prompt = render_to_string

    # Allows you to add attachments to a prompt, like so:
    #
    #  attachments << '/path/to/filename.jpg'
    #
    def attachments = @attachments ||= []

    # The main method that sends the rendered prompt to the AI model. There are
    # two ways to call this method, with a block, or without a block.
    # If +prompt+ is omitted, it is rendered from the matching template.
    #
    # It accepts an optional +with:+ keyword for attachments:
    #
    # * +:with+ - Array of file paths or URLs to attach to the prompt.
    #
    # You can set default model options using the ::default class method:
    #
    #  class Generator < ActionAI::Agent
    #    default model: 'gpt-4o', provider: :openai
    #  end
    #
    # It will find a template in the view paths using by default the agent name and the
    # method name that it is being called from, it will then call
    # +RubyLLM::Chat#ask+ and return a resulting +RubyLLM::Message+.
    #
    # For example:
    #
    #   class Generator < ActionAI::Agent
    #     default model: 'gpt-4o'
    #
    #     def code(task, language)
    #       @task     = task
    #       @language = language
    #
    #       ask # can be omitted, like +render+ in action controllers
    #     end
    #   end
    #
    # Will look for all templates at "app/ai/prompts/generator" with name "code".
    # If no code template exists, it will raise an ActionView::MissingTemplate error.
    #
    # However, those can be customized:
    #
    #   ask render(template: 'shared/prompt')
    #
    # You can even render plain text directly without using a template:
    #
    #   ask("Write Ruby code for the following task: #{task}")
    #
    def ask(prompt = self.prompt, with: use_attachments, &)
      @_message = chat.ask(prompt, with:, &)
    end

    private
      # Prompts do not support relative path links.
      def self.supports_path? # :doc:
        false
      end

      def apply_defaults(config = {})
        default_values = self.class.default.except(*config.keys).transform_values do |value|
          compute_default(value)
        end

        config.reverse_merge(default_values)
      end

      def compute_default(value)
        return value unless value.is_a?(Proc)

        if value.arity == 1
          instance_exec(self, &value)
        else
          instance_exec(&value)
        end
      end

      def use_attachments
        attachments.presence
          .tap { @attachments = nil } # reset
      end

      # This and #instrument_name is for caching instrument
      def instrument_payload(key)
        {
          agent: agent_name,
          key: key
        }
      end

      def instrument_name
        "action_ai"
      end

      def _protected_ivars
        PROTECTED_IVARS
      end

      ActiveSupport.run_load_hooks(:action_ai, self)
  end
end
