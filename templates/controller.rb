class <%= class_name %>Controller < ApplicationController
  ### comment out following line if you don't want to overwrite this file automatically
  <%= ActiveScaffold::Activator::File::AUTO_GENERATED %>

<%- default_sorting_column = columns.select(&:sorting).map(&:name) -%>
<%- if default_sorting_column.nil? || default_sorting_column.empty? -%>
<%-   default_sorting_column = 'id' -%>
<%- else -%>
<%-   default_sorting_column = default_sorting_column[0] -%>
<%- end -%>
  
<%- join_colmuns = Array.new -%> 
<%- Togodb::Through.find(:all,:conditions=>["table1=? OR table2=?",@table.name,@table.name]).each do |line|  -%>
  <%- join_colmuns << ([line.table1,line.table2]-[@table.name]).to_s-%>
  <%- join_colmuns << @table.name if [line.table1,line.table2]-[@table.name] ==[] -%>
<%- end -%>

<%- if setting.action_service? -%>
  include <%= class_name %>WebService
<%- end -%>
  include ActiveScaffold::Actions::TogodbAction
  include Togodb::TemporaryWorkspace

  layout "togodb/application"
  helper "togodb/application"
  helper "togodb/external_search"
  helper "luxury_search"

  before_filter {|controller_instance|
    if controller_instance.params[:limit].blank?
      if active_scaffold_config.list.per_page.nil?
        active_scaffold_config.list.per_page = 15
      end
    else
      active_scaffold_config.list.per_page = controller_instance.params[:limit].to_i
    end

    @togodb_table = Togodb::Table.find(:first, :conditions => ['name = ?', controller_instance.controller_name])
  }

  active_scaffold :<%= singular_name %> do |config|
<%- unless setting.label.blank? -%>
    config.label = <%= setting.label.to_s.inspect %>
<%- end -%>

    # valid crud actions
    config.actions = %w( nested search create update delete list subform show )

    # global columns
<%- columns.each do |column|  -%>
    config.columns[:<%= column.name %>].label = <%= column.label.to_s.inspect %>
    config.columns[:<%= column.name %>].sanitize = <%= column.sanitize %>
  <%- unless @table.sortable -%>
    config.columns[:<%= column.name %>].sort = false
  <%- end -%>
<%- end -%>

    # list action
    config.list.columns = %w( <%= @table.list_column_names.map{|c| c[:name]}.join(' ') %> )
    #-->config.list.columns = %w( <%= columns.select(&:action_list?).map(&:name).join(' ') %> )
    config.list.per_page = <%= [setting.per_page.to_i,1].max %>

    # show action
    config.show.columns = %w( <%= @table.show_column_names.map{|c| c[:name]}.join(' ') %> )
    #config.show.columns = %w( <%= columns.select(&:action_show?).map(&:name).join(' ') %> )

    # edit action
    config.update.columns = %w( <%= columns.select{|c| c.name != 'id'}.map(&:name).join(' ') %> )

    # search_sql
<%- columns.each do |column|  -%>
<%-   next unless column.text? -%>
<%-   comment = column.searchable? ? '# ' : '' -%>
    <% comment %>config.columns[:<%= column.name %>].search_sql = false
<%- end if false -%>
    config.search.columns = %w( <%= columns.select(&:action_search?).map(&:name).join(' ') %> )
    config.actions << :luxury_search
    config.luxury_search.columns = %w( <%= columns.select(&:action_luxury?).map(&:name).join(' ') %> )

<%- unless setting.externals.blank? -%>
    # togodb
    config.actions << :togodb
    togodb.table_name = '<%= table_name %>'
    # togodb.per_page = 10
<%- end -%>

<% join_colmuns.each do |join_column| -%>
    #-->config.nested.add_link('<%= join_column %>', [:<%= join_column %>])
<% end -%>

    # Sorting
    list.sorting = {:<%= default_sorting_column %> => 'ASC'}

  end

  # action links
  active_scaffold_config.action_links[:show].inline = false
  active_scaffold_config.action_links[:show_search].type = false
  active_scaffold_config.action_links[:new].label = 'Add Record'
  active_scaffold_config.action_links[:show].popup = true

  include Togodb::Actions
  dsl_accessor :togodb_table_id, <%= @table.id %>, :instance=>true

  def download
    record = Togodb::Table.find(:first, :conditions => ["name = ?", '<%= table_name %>'])

    if params[:search].kind_of?(Hash)
      # Advanced Search
      parameters = params[:search]
      valid_columns = active_scaffold_config.luxury_search.columns

      columns = []
      parameters.each do |column_name, value|
        next if value.nil? || value.to_s.strip.blank?
        next unless valid_columns.include?(column_name)
        next unless column = active_scaffold_config.columns[column_name]
        columns << column
      end
        
      condition_builder = ::LuxurySearch::ConditionBuilder.new(false)
      conditions = condition_builder.build(parameters, columns)
      if conditions.empty?
        data = record.active_record.find(:all, :order => sort_order)
      else
        data = record.active_record.find(:all, :conditions => conditions, :order => sort_order)
      end
    else
      # Simple Search
      query = params[:search]
      if query.blank?
        data = record.active_record.find(:all, :order => sort_order)
      else
        valid_columns = active_scaffold_config.search.columns
        condition_builder = ::LuxurySearch::ConditionBuilder.new
        conditions = condition_builder.build(query, valid_columns)
        data = record.active_record.find(:all, :conditions => conditions, :order => sort_order)
      end
    end

    pathname = workspace_path + "<%= table_name %>_#{Time.now.to_i}.csv"
    if windows_client?
      opts = {:encoding => :sjis}
    else
      opts = {}
    end
    Togodb::Utils::Exports::Writers::Csv.new(data, pathname, opts).execute

    # output
    send_file pathname.to_s, :filename => '<%= table_name %>.csv', :type => 'text/csv'
  end
      
  private
    def html_title
      <%= setting.html_title.to_s.inspect %>
    end

    def sort_order
      if params[:sort_column].blank? && params[:sort_direction].blank?
        initial_sort_order
      else
        direction = params['sort_direction'].strip.upcase
        if direction == 'RESET'
          reset_sort_order
        else
          "<%= table_name %>.\"#{params[:sort_column]}\" #{direction}"
        end
      end
    end

    def initial_sort_order
      "<%= table_name %>.\"<%= default_sorting_column %>\" ASC"
    end

    def reset_sort_order
      #"<%= table_name %>.\"#{active_scaffold_config.list.columns.collect[0].column.name}\" ASC"
      "<%= table_name %>.\"<%= default_sorting_column %>\" ASC"
    end

    def windows_client?
      user_agent = request.user_agent

      user_agent.include?("Windows") ||
      user_agent.include?("Win95") ||
      user_agent.include?("Win98") ||
      user_agent.include?("WinNT")
    end

end

