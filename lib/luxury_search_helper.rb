module LuxurySearchHelper
  def luxury_search_form(action_name = :update_table, form_name = 'simple')
    href = url_for(params_for(:action => action_name, :escape => false).delete_if{|k,v| k == 'search'})
    form_remote_tag :url => href,
                    :method => :get,
                    :before => "addActiveScaffoldPageToHistory('#{href}', '#{params[:controller]}')",
                    :after => "$('#{loading_indicator_id(:action => form_name, :id => params[:id])}').style.visibility = 'visible'; Form.disable('#{search_form_id}');",
                    :complete => "$('#{loading_indicator_id(:action => form_name, :id => params[:id])}').style.visibility = 'hidden'; Form.enable('#{search_form_id}');",
                    :failure => "ActiveScaffold.report_500_response('#{active_scaffold_id}')",
                    :update => active_scaffold_content_id,
                    :html => { :href => href, :id => search_form_id, :class => 'search', :name => form_name }
  end

  def luxury_search_toggle
    <<-JS
      if (Element.visible($('luxury_search'))) {
        $('luxury-search-toggler-image').src = '#{image_path("togodb/show_advanced_search.png")}';
        #{luxury_search_close}
        #{simple_search_open}
      } else {
        $('luxury-search-toggler-image').src = '#{image_path("togodb/hide_advanced_search.png")}';
        #{simple_search_close}
        #{luxury_search_open}
      }
    JS
  end

  def simple_search_open
    <<-JS
      Element.show('simple_search');
      $('simple_search').visualEffect('highlight',{"duration":0.5});
    JS
  end

  def simple_search_close
    <<-JS
      Element.hide('simple_search');
    JS
  end

  def luxury_search_open
    <<-JS
      Element.show('luxury_search');
      $('luxury_search').visualEffect('highlight',{"duration":0.5});
    JS
  end

  def luxury_search_close
    <<-JS
      Element.hide('luxury_search');
    JS
  end

  def luxury_search?
    !active_scaffold_config.luxury_search.columns.blank?
  end
end
