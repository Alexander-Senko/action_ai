# frozen_string_literal: true

class BaseAgent < ActionAI::Agent
  self.agent_name = "base_agent"

  def welcome
    ask
  end

  def attachment_with_content(hash = {})
    attachments << __FILE__
    ask
  end

  def implicit_with_locale(hash = {})
    ask
  end

  def explicit_different_template(template_name = "")
    ask render(template: "#{agent_name}/#{template_name}")
  end

  def different_layout(layout_name = "")
    ask render(layout: layout_name)
  end

  def prompt_with_translations
    ask render("prompt_with_translations")
  end

  def with_nil_as_return_value
    ask render("welcome")
    nil
  end
end
