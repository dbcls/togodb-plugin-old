module Togodb::Actions
  protected
    def list_authorized?
      if @list_authorized.nil?
        @list_authorized = togodb_table.enabled || togodb_authorized_for?(:read)
        logger.debug "[AS] list_authorized? -> %s" % @list_authorized
      end
      return @list_authorized
    end

    def update_authorized?
      if @update_authorized.nil?
        @update_authorized = togodb_authorized_for?(:write)
        logger.debug "[AS] update_authorized? -> %s" % @update_authorized
      end
      return @update_authorized
    end

    def create_authorized?
      if @create_authorized.nil?
        @create_authorized = togodb_authorized_for?(:write)
        logger.debug "[AS] create_authorized? -> %s" % @create_authorized
      end
      return @create_authorized
    end

    def delete_authorized?
      if @delete_authorized.nil?
        @delete_authorized = togodb_authorized_for?(:write)
        logger.debug "[AS] delete_authorized? -> %s" % @delete_authorized
      end
      return @delete_authorized
    end

  private
    def current_user
      session[:current_user]
    end

    def togodb_authorized_for?(action)
      togodb_table.authorized_for?(action)
    end

    def togodb_table
      @togodb_table ||= Togodb::Table.find(togodb_table_id)
    rescue
      Togodb::Syslog.write  "Cannot find table(#{togodb_table_id}) in #{self.class.name}"
      raise Togodb::ServiceUnavailable, "#{html_title} is not available"
    end
end
