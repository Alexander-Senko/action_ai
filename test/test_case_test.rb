# frozen_string_literal: true

require "abstract_unit"

class TestTestMailer < ActionAI::Base
end

class ClearTestDeliveriesMixinTest < ActiveSupport::TestCase
  include ActionAI::TestCase::ClearTestDeliveries

  def before_setup
    ActionAI::Base.delivery_method, @original_delivery_method = :test, ActionAI::Base.delivery_method
    ActionAI::Base.deliveries << "better clear me, setup"
    super
  end

  def after_teardown
    super
    assert_equal [], ActionAI::Base.deliveries
    ActionAI::Base.delivery_method = @original_delivery_method
  end

  def test_deliveries_are_cleared_on_setup_and_teardown
    assert_equal [], ActionAI::Base.deliveries
    ActionAI::Base.deliveries << "better clear me, teardown"
  end
end

class MailerDeliveriesClearingTest < ActionAI::TestCase
  def before_setup
    ActionAI::Base.deliveries << "better clear me, setup"
    super
  end

  def after_teardown
    super
    assert_equal [], ActionAI::Base.deliveries
  end

  def test_deliveries_are_cleared_on_setup_and_teardown
    assert_equal [], ActionAI::Base.deliveries
    ActionAI::Base.deliveries << "better clear me, teardown"
  end
end

class ManuallySetNameMailerTest < ActionAI::TestCase
  tests TestTestMailer

  def test_set_mailer_class_manual
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

class ManuallySetSymbolNameMailerTest < ActionAI::TestCase
  tests :test_test_mailer

  def test_set_mailer_class_manual_using_symbol
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

class ManuallySetStringNameMailerTest < ActionAI::TestCase
  tests "test_test_mailer"

  def test_set_mailer_class_manual_using_string
    assert_equal TestTestMailer, self.class.mailer_class
  end
end
