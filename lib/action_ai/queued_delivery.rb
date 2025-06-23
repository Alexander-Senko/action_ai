# frozen_string_literal: true

module ActionAI
  module QueuedDelivery
    extend ActiveSupport::Concern

    included do
      class_attribute :delivery_job, default: ::ActionAI::MailDeliveryJob
      class_attribute :deliver_later_queue_name, default: :mailers
    end
  end
end
