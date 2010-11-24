module Togodb::ApplicationHelper
  ######################################################################
  ### for ActiveScaffold
  def loading_indicator_tag(options)
    image_tag "/images/togodb/indicator.gif", :style => "visibility:hidden;", :id => loading_indicator_id(options), :alt => "loading indicator", :class => "loading-indicator"
  end

  def togodb_get_show_column_value(record, column)
    column_value = togodb_get_column_value(record, column)
    togodb_render_list_column(column_value, column, record)
  end

  # We should avoid native methods of Ruby
  def togodb_record_value(record, column)
    togodb_record_value_by_column_name(record, column.name)
  end

  def togodb_record_value_by_column_name(record, column_name)
    if record.class.columns_hash[column_name]
      record[column_name]
    else
      record.send(column_name)
    end
  end
  
  # Derived from: active_scaffold/lib/helpers/list_column_helpers.rb
  def togodb_get_column_value(record, column)
        value = if column_override? column
          send(column_override(column), record)
        elsif column.list_ui and override_column_ui?(column.list_ui)
          send(override_column_ui(column.list_ui), column, record)

        elsif column.inplace_edit and record.authorized_for?(:action => :update, :column => column.name)
          active_scaffold_inplace_edit(record, column)
        else
          value = togodb_record_value(record, column)

          if column.association.nil? or column_empty?(value)
            formatted_value = format_column(value)
            formatted_value = clean_column_value(formatted_value) if column.sanitize
          else
            case column.association.macro
              when :has_one, :belongs_to
                formatted_value = clean_column_value(format_column(value.to_label))

              when :has_many, :has_and_belongs_to_many
                firsts = value.first(4).collect { |v| v.to_label }
                firsts[3] = '…' if firsts.length == 4
                formatted_value = clean_column_value(format_column(firsts.join(', ')))
            end
          end

          formatted_value
        end

        value = '&nbsp;' if value.nil? or (value.respond_to?(:empty?) and value.empty?) # fix for IE 6
        return value
  end

  def togodb_render_list_column(column_value, column, record)
    if column_override?(column)
      if column.sanitize
        show_column_value = convert_url_link(column_value)
      else
        show_column_value = column_value
      end
    else
      # we don't trust this 'column_value' given by ActiveScaffold
      show_column_value = togodb_record_value(record, column)

      #  ar_column = record.class.columns_hash[column.name.to_s]
      #  if ar_column and ar_column.type == :text
      #    return togodb_sanitize_text_value(togodb_record_value(record, column))[0,3].join("<BR>")
      #  end

      if column.link
         show_column_value = convert_url_link(render_list_column(column_value, column, record))
      else
        if column.sanitize
          show_column_value = convert_url_link(h(column_value))
        else
          show_column_value = column_value
        end
      end
    end

    value = add_html_link(record, column.name.to_s, show_column_value)
    value.blank? ? active_scaffold_config.list.empty_field_text : simple_format(value)
  end

  def togodb_sanitize_text_value(value)
    value.to_s.split(/\n/).map{|i| h(i)}
  end

  def convert_url_link(str)
    if str
      str.gsub(/(https?:\/\/[\w\-\.\!\~\*\(\)\;\/\?\:\@\&\=\+\$\,\%\#]+)/) {
        '<a href="' + $1 + '" target="_blank">' + $1 + '</a>'
      }
    end
  end

  def add_html_link(record, column_name, column_value)
    begin
      togodb_table = Togodb::Table.find_by_name(params[:controller])
      togodb_column = Togodb::Column.find(:first, :conditions => ['name = ? AND table_id = ?', column_name, togodb_table.id])
      
      if togodb_column.html_link_prefix.blank? && togodb_column.html_link_suffix.blank?
        if togodb_column.other_type.blank?
          column_value
        else
          add_xref_link(column_value, togodb_column.other_type)
        end
      else
        html_link_prefix = ""
        unless togodb_column.html_link_prefix.blank?
          html_link_prefix = replace_html_link_column_value(record, togodb_column.html_link_prefix)
          return "" if html_link_prefix.blank?
        end

        html_link_suffix = ""
        unless togodb_column.html_link_suffix.blank?
          html_link_suffix = replace_html_link_column_value(record, togodb_column.html_link_suffix)
          return "" if html_link_suffix.blank?
        end

        html_link_prefix + column_value + html_link_suffix
      end
    rescue
      column_value
    end
  end

  def replace_html_link_column_value(record, link_str)
    return "" unless link_str

    s = link_str.dup
    replace_columns = s.scan(/\{.+?\}/)
    if replace_columns.kind_of?(Array)
      return s if replace_columns.size == 0
      return "" if replace_columns.reject {|column| record[column[1 .. -2]].blank?}.size == 0
      replace_columns.uniq.each {|replace_column|
        col_value = record[replace_column[1 .. -2]].to_s
        s = s.gsub(/#{Regexp.escape(replace_column)}/, col_value)
      }
    end

    s
  end

  def add_xref_link(column_value, xrefdb)
    case xrefdb
    when "GenBank"
      href = "http://www.ncbi.nlm.nih.gov/nucleotide/#{column_value}"
    when "EMBL"
      href = "http://srs.ebi.ac.uk/srsbin/cgi-bin/wgetz?-e+%5bEMBL:#{column_value}%5d+-newId"
    when "DDBJ"
      href = "http://getentry.ddbj.nig.ac.jp/search/get_entry?mode=view&type=flatfile&database=ddbj&format=&accnumber=#{column_value}"
    when "UniProt"
      href = "http://www.uniprot.org/uniprot/#{column_value}"
    when "PDB"
      href = "http://service.pdbj.org/mine/Detail?PDBID=#{column_value}&PAGEID=Summary"
    when "PubMed"
      href = "http://www.ncbi.nlm.nih.gov/pubmed/#{column_value}"
    end

    "<a href=\"#{href}\" target=\"_blank\">#{column_value}</a>"
  end

  def togodb_webservice_column_value(record)
    ws = []
    @togodb_table.columns.each {|togodb_column|
      next unless togodb_column.web_service?
      togodb_column.web_service_list.each {|ws_name|
        ws << togodb_ws_link(ws_name, togodb_record_value_by_column_name(record, togodb_column.name))
      }
    }
    ws.join("<br />")
  end
  
  def togodb_ws_link(ws_name, value)
    case ws_name
    when 'genbank_entry_text'
      content_tag "a", "GenBank: All Entry(Text)",
        :href => "http://togows.dbcls.jp/entry/genbank/#{value}", :target => "_blank"
    when 'genbank_entry_xml'
      content_tag "a", "GenBank: All Entry(XML)",
        :href => "http://togows.dbcls.jp/entry/genbank/#{value}.xml", :target => "_blank"
    when 'genbank_seq_fasta'
      content_tag "a", "GenBank: Sequence(FASTA)",
        :href => "http://togows.dbcls.jp/entry/genbank/#{value}.fasta", :target => "_blank"
    when 'pubmed_abstract'
      content_tag "a", "PubMed Abstract",
        :href => "http://togows.dbcls.jp/entry/pubmed/#{value}/abstract", :target => "_blank"
    when 'embl_entry_text'
      content_tag "a", "EMBL: All Entry(Text)",
        :href => "http://togows.dbcls.jp/entry/embl/#{value}", :target => "_blank"
    when 'embl_entry_xml'
      content_tag "a", "EMBL: All Entry(XML)",
        :href => "http://togows.dbcls.jp/entry/embl/#{value}.xml", :target => "_blank"
    when 'embl_seq_fasta'
      content_tag "a", "EMBL: Sequence(FASTA)",
        :href => "http://togows.dbcls.jp/entry/embl/#{value}", :target => "_blank"
    when 'ddbj_entry_text'
      content_tag "a", "DDBJ: All Entry(Text)",
        :href => "http://togows.dbcls.jp/entry/ddbj/#{value}", :target => "_blank"
    when 'ddbj_entry_xml'
      content_tag "a", "DDBJ: All Entry(XML)",
        :href => "http://togows.dbcls.jp/entry/ddbj/#{value}.xml", :target => "_blank"
    when 'ddbj_seq_fasta'
      content_tag "a", "DDBJ: Sequence(FASTA)",
        :href => "http://togows.dbcls.jp/entry/ddbj/#{value}.fasta", :target => "_blank"
    else
      value
    end
  end
  
  def togodb_pagination_ajax_link(page_number, params, opts = {})
    indicator_id = opts[:indicator_id] ? opts[:indicator_id] : :pagination
    page_link = link_to_remote(page_number,
              { :url => params.merge(:page => page_number),
                :after => "$('#{loading_indicator_id(:action => indicator_id)}').style.visibility = 'visible';",
                :complete => "$('#{loading_indicator_id(:action => indicator_id)}').style.visibility = 'hidden';",
                :update => active_scaffold_content_id,
                :failure => "ActiveScaffold.report_500_response('#{active_scaffold_id}')",
                :method => :get },
              { :href => url_for(params.merge(:page => page_number)) })
  end

  def togodb_pagination_ajax_links(current_page, params, opts = {})
    start_number = current_page.number - 2
    end_number = current_page.number + 2
    start_number = 1 if start_number <= 0
    end_number = current_page.pager.last.number if end_number > current_page.pager.last.number

    html = []
    html << togodb_pagination_ajax_link(1, params, opts) unless current_page.number <= 3
    html << ".." unless current_page.number <= 4
    start_number.upto(end_number) do |num|
      if current_page.number == num
        html << num
      else
        html << togodb_pagination_ajax_link(num, params, opts)
      end
    end
    html << ".." unless current_page.number >= current_page.pager.last.number - 3
    html << togodb_pagination_ajax_link(current_page.pager.last.number, params, opts) unless current_page.number >= current_page.pager.last.number - 2
    html.join(' ')
  end

  def togodb_loading_indicator_id(position = :up)
    "pagination_#{position.to_s}"
  end

  ######################################################################
  ### for Togodb

  def togodb_record_name(record, field, prefix = "records")
    "%s[%s][%s]" % [prefix, record.id, field]
  end

  def togodb_text_field(record, field, options = {})
    name = togodb_record_name(record, field)
    text_field_tag name, record[field], options
  end

  def togodb_check_box(record, field, options = {})
    name = togodb_record_name(record, field)
    html = check_box_tag name, 1, record.send(field), options
    html << hidden_field_tag(name, 0)
    return html
  end

  def togodb_disp_order_select(record, field, num_columns, prefix = "records")
    name = togodb_record_name(record, field, prefix)
    options = [["--", ""]]
    1.upto(num_columns) {|n|
      options << [n.to_s, n]
    }
    select_tag name, options_for_select(options, record[field])
  end

  def togodb_radio_for_unique(record, field = :primary_key, options = {})
    radio_button_tag field, record.id, record.send(field), options
  end

  def togodb_html_title
    begin
      if @controller.action_name == 'show'
        @record.to_label
      else
        @controller.send :html_title
      end
    rescue
      '???'
    end
  end

  def safe_link_to_remote(name, options = {}, html_options = {})
    label   = options.delete(:label) || name
    link_id = html_options[:id] || "safe_caller_%d" %
      (@safe_caller = @safe_caller.to_i + 1)
    load_id = "#{link_id}_loading"

    loading = "$('%s').hide(); $('%s').show();" % [link_id, load_id]
    loaded  = "$('%s').hide(); $('%s').show();" % [load_id, link_id]

    options[:url] ||= url_for(:id=>params[:id])
    options[:loading] = "%s;%s" % [options[:loading], loading]
    options[:loaded]  = "%s;%s" % [options[:loaded],  loaded]

    content_tag(:span, label, :id=>load_id, :style=>"background-color:yellow; display: none;") +
    link_to_remote(name, options, html_options.merge(:id=>link_id))
  end

  def togodb_metadata_yes_no_cloud(value)
    case value
    when 1
      '○'
    when 0
      '×'
    when -1
      '不明'
    end
  end
end
