# frozen_string_literal: true

class ParamsAgent < ActionAI::Agent
  before_action { @inviter, @invitee = params[:inviter], params[:invitee] }

  def invitation
    ask "#{@inviter} welcomes #{@invitee} to the project"
  end
end
