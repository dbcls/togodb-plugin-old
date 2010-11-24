module Togodb::TemporaryWorkspace
  def self.included(base)
    base.instance_eval do
      before_filter :prepare_temporary_workspace, :except=>"index"
    end
  end

protected
  def prepare_temporary_workspace
    path = workspace_path.realpath
    path.directory? or path.mkdir

    unless path.directory?
      raise as_("cannot create temporary directory")
    end

    return true
  end

  def workspace_path_base
    Pathname.new(RAILS_ROOT) + "tmp"
  end

  def workspace_path_dirs
    ["togodb", "temporary_workspace"]
  end

  def workspace_path
    @workspace_path ||=
      workspace_path_dirs.inject(workspace_path_base){ |path, dir|
        path += dir; path.mkdir unless path.directory?; path
    }
  end
end
