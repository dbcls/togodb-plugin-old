# Make sure that ActiveScaffold has already been included
ActiveScaffold rescue throw "should have included ActiveScaffold plugin first"

config.controller_paths << directory + "/lib"

# Load
require File.dirname(__FILE__) + '/core_ext/class/dsl_accessor'
require File.dirname(__FILE__) + '/core_ext/rails/acts_as_bits'
require File.dirname(__FILE__) + '/core_ext/active_scaffold/data_structures/column'
require File.dirname(__FILE__) + '/core_ext/active_scaffold/activator'
require File.dirname(__FILE__) + '/core_ext/active_scaffold/actions/luxury_search'
require File.dirname(__FILE__) + '/core_ext/active_scaffold/config/luxury_search'
require File.dirname(__FILE__) + '/core_ext/active_scaffold/actions/togodb_action'
require File.dirname(__FILE__) + '/core_ext/active_scaffold/config/togodb'
require File.dirname(__FILE__) + '/lib/togodb'

# Install
Togodb.mirror("app/views/layouts/togodb")
Togodb.mirror("app/views/active_scaffold_overrides")
Togodb.mirror("app/views/togodb")
Togodb.mirror("app/views/togodb_import")
Togodb.mirror("app/views/togodb_user")
Togodb.mirror("public/uploader")
Togodb.mirror("public/images")
Togodb.mirror("public/images/togodb")
Togodb.mirror("public/stylesheets")
Togodb.mirror("public/stylesheets/togodb")
Togodb.mirror("public/javascripts")
Togodb.mirror("public/javascripts/yui/dragdrop")
Togodb.mirror("public/javascripts/yui/yahoo-dom-event")
Togodb.mirror("public/javascripts/uploader")
Togodb.mirror("bin/external_search")
Togodb.mirror("bin/external_search/blast")
Togodb.mirror("bin/external_search/blast/bin")

# Migrate
Togodb.migrate

