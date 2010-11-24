class <%= class_name %> < ActiveRecord::Base
  set_table_name :<%= table_name %>
  belongs_to :<%= table1 %>
  belongs_to :<%= table2 %>
end
