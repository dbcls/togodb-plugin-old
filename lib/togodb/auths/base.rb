class Togodb::Auths::Base
  attr_reader :controller
  delegate :params, :request, :to=>"@controller"

  def initialize(controller)
    @controller = controller
  end

  def login
    raise NotImplementedError, "subclass responsibility"
  end

  def nop?
    true
  end
end
