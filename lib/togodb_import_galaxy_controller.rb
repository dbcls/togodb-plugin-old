class TogodbImportGalaxyController < TogodbImportController
  layout "togodb/import_galaxy"

  def csv_reader
    # for tabular
    super
    return CSV::Reader.create(File.open(@utf8.to_s, 'r'), "\t")
  end

  def guess_column_types(column_indexes = nil)
    Togodb::Utils::GuessColumnType.new(uploaded_file(:sjis), :header=>header?, :fs => "\t").execute(column_indexes)
  end

  def upload
    raise NotNamedYet unless @table
    return unless request.post?

    buffer = params[:dataset]
    reset_uploaded
    @sjis.open("w+"){|f| f.print buffer}

    # convert
    @nkf_option = "-w -x -d --no-best-fit-chars"
    @utf8.open("w+"){|f| f.print NKF.nkf(@nkf_option, @sjis.read)}
    @table.columns.destroy_all

    redirect_to :action=>"schema"
    flash[:notice] = as_("got 1 file") + " (%s)" % number_to_human_size(@sjis.size)
  end

  def name
    prepare_variables
    @table = nil
    super

    if performed?
      erase_results
      redirect_to params.merge!(:method => :get, :action => :upload)
    end
  end
end
