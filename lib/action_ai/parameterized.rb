# frozen_string_literal: true

module ActionAI
  # = Action AI \Parameterized
  #
  # Provides the option to parameterize AI agents in order to share instance variable
  # setup, processing, and common defaults.
  #
  # Consider this example that does not use parameterization:
  #
  #   class InvitationAgent < ApplicationAI
  #     def account_invitation(inviter, invitee)
  #       @account = inviter.account
  #       @inviter = inviter
  #       @invitee = invitee
  #     end
  #
  #     def project_invitation(project, inviter, invitee)
  #       @account = inviter.account
  #       @project = project
  #       @inviter = inviter
  #       @invitee = invitee
  #       @summarizer = ProjectInvitationSummarizer.new(@project.bucket)
  #     end
  #
  #     def bulk_project_invitation(projects, inviter, invitee)
  #       @account  = inviter.account
  #       @projects = projects.sort_by(&:name)
  #       @inviter  = inviter
  #       @invitee  = invitee
  #     end
  #   end
  #
  #   InvitationAgent.account_invitation(person_a, person_b).later
  #
  # Using parameterized agents, this can be rewritten as:
  #
  #   class InvitationAgent < ApplicationAI
  #     before_action { @inviter, @invitee = params[:inviter], params[:invitee] }
  #     before_action { @account = params[:inviter].account }
  #
  #     def account_invitation
  #     end
  #
  #     def project_invitation
  #       @project = params[:project]
  #       @summarizer = ProjectInvitationSummarizer.new(@project.bucket)
  #     end
  #
  #     def bulk_project_invitation
  #       @projects = params[:projects].sort_by(&:name)
  #     end
  #   end
  #
  #   InvitationAgent.with(inviter: person_a, invitee: person_b).account_invitation.later
  module Parameterized
    extend ActiveSupport::Concern

    included do
      attr_writer :params

      def params
        @params ||= {}
      end
    end

    module ClassMethods
      # Provide the parameters to the agent in order to use them in the instance methods and callbacks.
      #
      #   InvitationAgent.with(inviter: person_a, invitee: person_b).account_invitation.later
      #
      # See Parameterized documentation for full example.
      def with(params)
        ActionAI::Parameterized::Agent.new(self, params)
      end
    end

    class Agent # :nodoc:
      def initialize(agent, params)
        @agent, @params = agent, params
      end

      private
        def method_missing(method_name, ...)
          if @agent.action_methods.include?(method_name.name)
            ActionAI::Parameterized::PromptExecution.new(@agent, method_name, @params, ...)
          else
            super
          end
        end

        def respond_to_missing?(method, include_all = false)
          @agent.respond_to?(method, include_all)
        end
    end

    class PromptExecution < ActionAI::Interaction # :nodoc:
      def initialize(agent_class, action, params, ...)
        super(agent_class, action, ...)
        @params = params
      end

      private
        def processed_agent
          @processed_agent ||= @agent_class.new.tap do |agent|
            agent.params = @params
            agent.process @action, *@args
          end
        end

        def enqueue_execution(...)
          if processed?
            super
          else
            @agent_class.execution_job.set(...).perform_later(
              @agent_class.name, @action.to_s, params: @params, args: @args)
          end
        end
    end
  end
end
