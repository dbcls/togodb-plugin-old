module Togodb::AdminHelper
  # not used yet
  def tab_menu(name, *args)
    selected = current_menu?(args)
    options  = NamedOptions.new(args, optionize(:controller, :action, :id))
    html     = link_to h(name), options
    style    = selected ? "on" : ""

    content_tag :li, html, :class=>style
  end

  def render_partial_tabs(args)
    keys = args.map(&:first)
    divs = keys.map{|key| tab_body_for(key, keys)}
    tabs = args.map{|(key, label)|
      js = render :update do |page|
        (keys - [key]).each do |id|
          page[id].hide
          page << "Element.removeClassName($('tab_for_#{id}'), 'on')"
        end
        page[key].show
        page << "Element.addClassName($('tab_for_#{key}'), 'on')"
      end
      html  = link_to_function label, js
      style = (keys.first == key) ? "tab on" : "tab"
      content_tag :span, html, :class=>style, :id=>"tab_for_#{key}"
    }

    content_tag(:div, tabs.join, :class=>"tab") + divs.join
  end

  def tab_body_for(key, keys)
    html  = render :partial=>"tab_#{key}"
    style = "display:%s;" % ((keys.first == key) ? "block" : "none")
    content_tag(:div, html, :id=>key, :class=>"tab", :style=>style)
  end
end
