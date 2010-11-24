module Togodb::Auths::System
  def self.authentication_method_for(name)
    case name.to_s
    when "open_id" then Togodb::Auths::OpenId
    when "account" then Togodb::Auths::Account
    else
      raise RuntimeError, "This authentication method is not supported: #{name}"
    end
  end

  public
    def login
      return if params[:id].blank?
      auth = Togodb::Auths::System.authentication_method_for(params[:id]).new(self)
      return if auth.nop?
      user = auth.login
      if user
        successful_login user
      end
    rescue => error
      failed_login error.message + ' [' + auth.login.inspect + ']'
    end

    def logout
      session[:current_user] = nil
      redirect_to_login
    end

  private
    def current_user
      session[:current_user]
    end

    def login?
      current_user
    end

    def login_required
      return true if current_user
      redirect_to :controller => "togodb", :action => "login" unless performed?
      return false
    end

    def redirect_to_login
      redirect_to(:action => 'login')
    end

    def successful_login(user)
      raise TypeError, "Togodb::User is expected, but got %s" % user.class unless user.is_a?(Togodb::User)
      session[:current_user] = user
      redirect_to(:action => 'index')
    end

    def failed_login(message)
      flash[:error] = message.to_s
      redirect_to_login
    end
end
