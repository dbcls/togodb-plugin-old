module Togodb::ExternalSearchHelper
  def external_search_links
    active_scaffold_config.togodb.setting.valid_externals.map do |ext|
      external_search_link_to_remote_for(ext)
    end
  rescue
    # It seems external search is not available in this controller.
  end

  def external_search_link_to_remote_for(ext)
    href = url_for(params_for(:action => "external_search", :id=>ext.name, :escape => false).delete_if{|k,v| k == 'search'})
#    link_to_remote ext.label,
    submit_to_remote ext.name, ext.label,
                    :url => href,
                    :method => :get,
                    :before => "addActiveScaffoldPageToHistory('#{href}', '#{params[:controller]}')",
                    :after => "$('#{loading_indicator_id(:action => :search, :id => params[:id])}').style.visibility = 'visible'; Form.disable('#{search_form_id}');",
                    :complete => "$('#{loading_indicator_id(:action => :search, :id => params[:id])}').style.visibility = 'hidden'; Form.enable('#{search_form_id}');",
                    :failure => "ActiveScaffold.report_500_response('#{active_scaffold_id}')",
                    :update => active_scaffold_content_id,
                    :submit => search_form_id,
                    :html => { :class => 'submit' }
  end
end

