module TogodbImportHelper
  def oneline_message(message, css_class)
    return nil if message.blank?
    message  = message.strip
    summary, = message.split(/\r?\n/, 2)
    if summary == message
      html = summary
    else
      body = h(message.to_s).gsub(/\n/,'<BR>')
      tips = content_tag('div', body, :class=>"tips")
      html = "%s&nbsp;%s" % [summary, content_tag('a', as_("[more]") + tips, :href=>'#')]
    end
    return content_tag('span', html, :class=>css_class)
  end

  def option_radio(key, name1, name2, check_no = 1)
    "%s&nbsp;%s&nbsp;&nbsp;%s&nbsp;%s" %
      [
       radio_button_tag("opts[#{ key}]", 1, check_no == 1), name1,
       radio_button_tag("opts[#{ key}]", 0, check_no != 1), name2
      ]
  end

  def human_time(sec)
    sec ||= 0
    format(as_("%dm%02ds"), *(sec.divmod(60)))
  end

  def array2table(array, options = {})
    tags = ['td'] * array.size
    tags.unshift 'th' if options.delete(:header)

    tr = array.map{|tds|
      tag = tags.shift
      content_tag(:tr, tds.map{|td| content_tag(tag, h(td.to_s))})
    }.join
    content_tag(:table, tr, options)
  end

  def column_types
    [:string, :text, :integer, :float, :decimal, :time, :date, :binary, :boolean]
  end

  def select_type_for(i)
    elems = column_types.map{|type|
      tagid = "column_#{@column.id}_type_#{type}"
      options = {
        :name => "#{@column.id}[type]",
        :checked => type.to_s == @column[:type].to_s,
        :id   => tagid,
      }
      button = radio_button :column, :type, type, options
      "%s%s" % [button, content_tag(:label, type, :for=>tagid)]
    }
    links = []
    elems.each_with_index {|elem, i|
      links << elem
      if (i + 1) % 7 == 0
        links << "<br />"
      else
        links << "&nbsp;"
      end
    }

    type = "other"
    tagid = "column_#{@column.id}_type_#{type}"
    options = {:name => "#{@column.id}[type]", :checked => false, :id => tagid}
    button = radio_button :column, :type, type, options
    select = select_tag "#{@column.id}[other_type]", options_for_select(other_types)

    return "#{links}<br />#{button}#{content_tag(:label, type, :for => tagid)} #{select}"
  end

  def other_types
    [["----- Select -----", ""],
     ["GenBank accession", "GenBank"],
     ["EMBL accession", "EMBL"],
     ["DDBJ accession", "DDBJ"],
     ["UniProt accession", "UniProt"],
     ["PDB ID", "PDB"],
     ["PubMed ID", "PubMed"]]
  end

  def multibyte_truncate(text, length = 30, truncate_string = "...")
    array = text.to_s.split(//)
    if array.size <= length
      return text
    else
      size = [0,length-1].max
      text = array[0, size].join
      return text + truncate_string
    end
  end
end
