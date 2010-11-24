module TogodbUserHelper
  def list_row_class(record)
    ""
  end

  def role_column(record)
    if record.superuser?
      return "Super User"
    else
      array = []
      record.flag_names.each do |name|
        next if name == "superuser"
        array << name.humanize if record.send(name)
      end

      if array.blank?
        "-"
      else
        array.join("<BR>")
      end
    end
  end

  ######################################################################
  ### Form Columns

  def login_form_column(record, name)
    text_field :record, :login, :size=>60
  end

  def superuser_form_column(record, name)
    input_role_for(:superuser, "All privileges")
  end

  def import_table_form_column(record, name)
    input_role_for(:import_table)
  end

  def users_form_column(record, name)
    rwx_form_column_for(:user)
  end

  def groups_form_column(record, name)
    rwx_form_column_for(:group)
  end

  def others_form_column(record, name)
    rwx_form_column_for(:other)
  end

  def rwx_form_column_for(column)
    %w( read write execute ).map do |op|
      input_role_for("#{column}_#{op}", op)
    end
  end

  def input_role_for(column, help = nil)
    help ||= column.to_s.humanize
    "<span class='role'>%s %s</span>" %
      [check_box(:record, column),
       content_tag(:label, help, :for=>"record_#{column}")]
  end

end
