class TogodbReimportController < TogodbImportController
  class InvalidTable < RuntimeError; end
  class DuplicatedColumn < RuntimeError; end

  def table
    local_session.clear
    begin
      table_id = params[:id].to_i
      Togodb::Table.find(table_id)
    rescue ActiveRecord::RecordNotFound => e
      raise InvalidTable
    end

    local_session[:table_id] = table_id
    @sjis.delete if @sjis.exist?

    redirect_to :action => "upload"
  end

  def name
    redirect_to :action => "upload"
  end

  def upload
    if request.get?
      @instance_id = random_str
      render :template => "togodb_import/upload"
      return
    end

    file_path = params[:solmetraUploaderData][params[:solmetraUploaderInstance]].split('|')[1]
    move_file(file_path, @sjis)

    local_session[:header] = true
    local_session[:column_names] = head_entries[0]

    duplicated_col_name = check_duplicated_column(local_session[:column_names])
    unless duplicated_col_name.empty?
      @message = duplicated_col_name.map {|n| as_("Duplicated column: '#{n}'")}.join("<br />") 
      raise DuplicatedColumn
    end

    flash[:notice] = as_("got 1 file") + " (%s)" % number_to_human_size(@sjis.size)

    new_columns = check_columns(local_session[:column_names])
    local_session[:new_columns] = new_columns
    if new_columns.empty?
      redirect_to :action => "import"
    else
      local_session[:new_columns] = new_columns
      redirect_to :action => "columns"
    end
  end

  def schema
    if local_session[:new_columns].empty?
      redirect_to :action => "import"
    else
      redirect_to :action => "columns"
    end
  end

  def columns
    if local_session[:new_columns].empty?
      redirect_to :action => "import"
      return
    end

    @message = "Setting for new columns"
    @submit_button_label = "Add new columns"
    @columns = []
    @samples = []

    column_id = 100001
    new_columns = local_session[:new_columns]
    types = guess_column_types(new_columns.map {|c| c[:column_id]})
    new_columns.each_with_index {|column, i|
      name = coerce_to_column_name(column[:column_name])
      label = name
      type = types[i]
      column_model = Togodb::Column.new(column_attributes(name, label, type, -1))
      column_model.id = column_id
      @columns << column_model
      @samples << head_entries[1][column[:column_id]]
      column_id += 1
    }

    render :template => "togodb_import/columns"
  end

  def create_table
    position = @table.columns.maximum(:position) + 1 
    params.each_pair {|id, hash|
      next unless /^\d+$/ === id.to_s
      name = coerce_to_column_name(hash[:name])
      label = hash[:label]
      type = hash[:type]
      @table.columns.create(column_attributes(name, label, type, position))
      position += 1
    }

    redirect_to :action => "import"
  end

  def import
    if request.get?
      render :template => "togodb_import/import"
      return
    end
    return unless request.xhr?

    count = import_csv(true)
    flash[:notice] = as_("%d data were imported into '%s'") % [count, @table.name]

    render :update do |page|
      page.redirect_to :action => "done"
    end

    local_session.clear
  end

  def done
    local_session.clear

    render :template => "togodb_import/done"
  end

private

  def check_duplicated_column(column_names)
    duplicated_columns = []
    used = {}
    column_names.each {|col_name|
      if used[col_name]
        duplicated_columns << col_name
      end
      used[col_name] = true
    }

    duplicated_columns
  end

  def check_columns(column_names)
    new_columns = []
    existing_column_names = @table.columns.map(&:name)
    column_names.each_with_index {|column_name, i|
      unless existing_column_names.include?(column_name)
        new_columns << {:column_id => i, :column_name => column_name}
      end
    }

    new_columns
  end

  def column_attributes(name, label, type, position)
    text = (/^(string|text)$/ === type.to_s)
    {:name           => name,
     :label          => label,
     :type           => type,
     :enabled        => true,
     :sanitize       => true,
     :position       => position,
     :action_search  => text,
     :action_luxury  => text}
  end

=begin
  def rescue_action(err)
    case err
    when InvalidTable
      @message = "Table not found"
      render :template => "togodb_import/error"
      return
    when DuplicatedColumn
      render :template => "togodb_import/error"
      return
    when InvalidColumnName
      render :template => "togodb_import/columns"
      return
    else
      render :template => "togodb_import/error"
    end
 end
=end
end
