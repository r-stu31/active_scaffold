# TODO: clean up extensions. some could be organized for autoloading, and others could be removed entirely.
Dir["#{File.dirname __FILE__}/active_scaffold/extensions/*.rb"].each { |file| require file }

ActionController::Base.send(:include, ActiveScaffold)
ActionController::Base.send(:include, ActiveScaffold::RespondsToParent)
ActionController::Base.send(:include, ActiveScaffold::Helpers::ControllerHelpers)
ActionView::Base.send(:include, ActiveScaffold::Helpers::ViewHelpers)

ActionController::Base.class_eval {include ActiveScaffold::ModelPermissions::ModelUserAccess::Controller}
Sequel::Model.class_eval     {include ActiveScaffold::ModelPermissions::ModelUserAccess::Model}
Sequel::Model.class_eval     {include ActiveScaffold::ModelPermissions::Permissions}
