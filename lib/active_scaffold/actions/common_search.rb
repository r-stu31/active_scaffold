module ActiveScaffold::Actions
  module CommonSearch
    protected
    def store_search_params_into_session
      if params[:search]
        s = params.delete(:search).strip
        active_scaffold_session_storage[:search] = (s == '' ? nil : s)
      end
    end
    
    def search_params
      active_scaffold_session_storage[:search]
    end

    def search_ignore?
      active_scaffold_config.list.always_show_search
    end
    
    # The default security delegates to ModelPermissions.
    # You may override the method to customize.
    def search_authorized?
      authorized_for?(:crud_type => :read)
    end
  end
end
