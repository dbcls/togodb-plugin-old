class <%= class_name %> < ActiveRecord::Base

<%- Togodb::Through.find(:all,:conditions=>["table1=? OR table2=?",@table.name,@table.name]).each do |line|  -%>
  has_many :<%= line.name %>
  has_many :<%= line.table1 == table_name ? line.table2 : line.table1 %>, :through => :<%= line.name %>
<%- end -%>

  ### comment out following line if you don't want to overwrite this file automatically
  <%= ActiveScaffold::Activator::File::AUTO_GENERATED %>
<%- unless @table.primary_key == "id" -%>
  set_primary_key <%= @table.primary_key.inspect %>
<%- end -%>
<%- unless class_name.tableize == table_name -%>
  set_table_name  :<%= table_name %>
<%- end -%>

<%- unless @table.primary_column_name.blank? -%>
  def to_label
    self[:<%= @table.primary_column_name %>]
  end
<%- end -%>
end
