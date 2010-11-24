module <%= class_name %>WebService
  class <%= class_name %> < ActionWebService::Struct
<%- columns.each do |column| -%>
  <%- if column.action_show? -%>
    member :<%= column.name %>,     :<%= column.aws_type %>
  <%- else -%>
    # member :<%= column.name %>,     :<%= column.aws_type %>
  <%- end -%>
<%- end -%>
  end

  class Api < ActionWebService::API::Base
    inflect_names false
    api_method :count,
    :expects => [{:query => :string}],
    :returns => [:int]

    api_method :search,
    :expects => [{:query => :string}, {:limit => :int}, {:offset => :int}],
    :returns => [[<%= class_name %>]]
  end

  class Service < ActionWebService::Base
    web_service_api Api
    include Togodb::WebService
  end

  def self.append_features(base)
    base.class_eval do
      web_service_dispatching_mode :delegated
      web_service :api, <%= class_name %>WebService::Service.new
      wsdl_namespace '<%= option(:wsdl_namespace) %>'
      # web_service_scaffold :invoke
    end
  end
end
