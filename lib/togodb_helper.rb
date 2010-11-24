module TogodbHelper
  def list_row_class(record)
    if !record.exist?
      "broken"
    elsif record.enabled?
      "enabled"
    else
      ""
    end
  end

  def service_column(record)

    "%s (%s)" % [service_status_for(record), service_link_for(record)]
  end

  def service_status_for(record)
    if record.enabled?
      as_("Service is up")
    else
      as_("Service is down")
    end
  end


  def service_link_for(record)
    if record.enabled?
      safe_link_to_remote as_("Stop"), ajax(:url=>{:action=>"stop_service", :id=>record})
    else
      safe_link_to_remote as_("Start"), ajax(:url=>{:action=>"start_service", :id=>record})
    end
  end

  def page_column(record)
    url = url_for(:controller=>record.singular_name)
    link_to url, :controller=>record.singular_name
  end

  def link_to_download(record)
    link_to "#{record.name}.csv", :action=>"download", :id=>record
  end

  def with_spinner(spinner, options)
    content = spinner.pop if spinner.is_a?(Array)
    show = proc{|e| e ? "$('#{e}').show()" : nil}
    hide = proc{|e| e ? "$('#{e}').hide()" : nil}

    options[:loading]  = [options[:loading], hide.call(content), show.call(spinner)].compact.join(";")
    options[:complete] = [hide.call(spinner),show.call(content), options[:complete]].compact.join(";")
    return options
  end

  def ajax(*args)
    with_spinner([:autoloading, :workspace], *args)
  end

  def columns_for_add
    [:string, :text, :integer, :decimal, :time, :date, :binary, :boolean]
  end
  
  def select_tag_for_add_column_type
    options = []
    columns_for_add.each {|type_name|
      options << [type_name, type_name]
    }
    select :column, :type, options
  end

  ######################################################################
  ### Auths

  def current_user
    @controller.send :current_user
  end

  def login?
    current_user
  end

  def roled?(name)
    return false unless login?
    return true  if current_user.superuser?
    return current_user.send("#{name}?")
  rescue => error
    Togodb::Syslog.write error
    false
  end

  def login_information
    return nil unless login?
    link = link_to(current_user.login, :controller=>"togodb", :action=>"login")
    "Logged in as : <b>%s</b>" % link
  end


  def file_icon_img_tag(record)
    id = "#{element_row_id(:action => :list, :id => record.id)}-icon"
    if !record.exist?
      image_tag("/images/togodb/file_broken.png", :alt => "broken", :id => id)
    elsif record.enabled?
      image_tag("/images/togodb/html.png", :alt => "started", :id => id)
    else
      image_tag("/images/togodb/file.png", :alt => "stopped", :id => id)
    end
  end

end
