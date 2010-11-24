class Togodb::Auths::OpenId < Togodb::Auths::Base
  def login
    user = nil

    unless controller.respond_to?(:using_open_id?, true)
      raise "Sorry, OpenID auth is not available in this site. Please install open_id_authentication plugin."
    end

    if controller.send(:using_open_id?)
      controller.send :authenticate_with_open_id do |result, identity_url|
        if result.successful?
          user = Togodb::User.register(identity_url)
        else
          raise result.message
        end
      end
    end
    return user
  end

  def nop?
    request.get? and !params["openid.mode"]
  end
end
