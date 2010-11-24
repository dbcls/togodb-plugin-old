class Togodb::Auths::Account < Togodb::Auths::Base
  def login
#    return nil unless request.post?
    # Parameters: {"login"=>"root", "password"=>"root"}
    Togodb::User.authorize(params[:login], params[:password]) or
      raise "Sorry, that username/password doesn't work"
  end

  def nop?
    ActiveRecord::Base.logger.debug "#{self.class}: nop? -> %s" % request.get?
    request.get?
  end
end
