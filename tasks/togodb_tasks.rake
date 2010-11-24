namespace "togodb" do
  desc "reset 'root' account"
  task "reset:root" => :environment do
    Togodb::User.reset_root_account
  end
end
