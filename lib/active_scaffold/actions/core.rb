module ActiveScaffold::Actions
  module Core
    def self.included(base)
      base.class_eval do
        before_filter :register_constraints_with_action_columns
        after_filter :clear_flashes
      end
      base.helper_method :nested?
      base.helper_method :beginning_of_chain
      base.helper_method :new_model
    end
    def render_field
      if params[:in_place_editing]
        render_field_for_inplace_editing
      else
        render_field_for_update_columns
      end
    end
    
    protected

    def nested?
      false
    end

    def render_field_for_inplace_editing
      register_constraints_with_action_columns(nested.constrained_fields, active_scaffold_config.update.hide_nested_column ? [] : [:update]) if nested?
      @record = find_if_allowed(params[:id], :update)
      render :inline => "<%= active_scaffold_input_for(active_scaffold_config.columns[params[:update_column].to_sym]) %>"
    end

    def render_field_for_update_columns
      column = active_scaffold_config.columns[params[:column]]
      unless column.nil?
        @source_id = params.delete(:source_id)
        @columns = column.update_columns
        @scope = params[:scope]
        
        if column.send_form_on_update_column
          hash = if @scope
            @scope.gsub('[','').split(']').inject(params[:record]) do |hash, index|
              hash[index]
            end
          else
            params[:record]
          end
          @record = hash[:id] ? find_if_allowed(hash[:id], :update) : new_model
          @record = update_record_from_params(@record, active_scaffold_config.send(@scope ? :subform : (params[:id] ? :update : :create)).columns, hash)
        else
          @record = new_model
          value = column_value_from_param_value(@record, column, params[:value])
          @record.send "#{column.name}=", value
        end
        
        after_render_field(@record, column)
      end
    end
    
    # override this method if you want to do something after render_field
    def after_render_field(record, column); end

    def authorized_for?(options = {})
      active_scaffold_config.model.authorized_for?(options)
    end

    def clear_flashes
      if request.xhr?
        flash.keys.each do |flash_key|
          flash[flash_key] = nil
        end
      end
    end

    def marked_records
      active_scaffold_session_storage[:marked_records] ||= Set.new
    end
    
    def default_formats
      [:html, :js, :json, :xml, :yaml]
    end
    # Returns true if the client accepts one of the MIME types passed to it
    # ex: accepts? :html, :xml
    def accepts?(*types)
      for priority in request.accepts.compact
        if priority == Mime::ALL
          # Because IE always sends */* in the accepts header and we assume
          # that if you really wanted XML or something else you would say so
          # explicitly, we will assume */* to only ask for :html
          return types.include?(:html)
        elsif types.include?(priority.to_sym)
          return true
        end
      end
      false
    end

    def response_status
      if successful?
        action_name == 'create' ? 201 : 200
      else
        422
      end
    end

    # API response object that will be converted to XML/YAML/JSON using to_xxx
    def response_object
      @response_object = successful? ? (@record || @records) : @record.errors
    end

    # Success is the existence of certain variables and the absence of errors (when applicable).
    # Success can also be defined.
    def successful?
      if @successful.nil?
        @records or (@record and @record.errors.count == 0 and @record.no_errors_in_associated?)
      else
        @successful
      end
    end

    def successful=(val)
      @successful = (val) ? true : false
    end

    # Redirect to the main page (override if the ActiveScaffold is used as a component on another controllers page) for Javascript degradation
    def return_to_main
      redirect_to main_path_to_return
    end

    # Override this method on your controller to define conditions to be used when querying a recordset (e.g. for List). The return of this method should be any format compatible with the :conditions clause of Sequel::Model's find.
    def conditions_for_collection
    end
  
    # Override this method on your controller to define joins to be used when querying a recordset (e.g. for List).  The return of this method should be any format compatible with the :joins clause of Sequel::Model's find.
    def joins_for_collection
    end
  
    # Override this method on your controller to provide custom finder options to the find() call. The return of this method should be a hash.
    def custom_finder_options
      {}
    end
  
    # Overide this method on your controller to provide model with named scopes
    # This method returns a model class or a dataset.
    def beginning_of_chain
      active_scaffold_config.model.qualify
    end

    # This method returns a model class.
    def origin_class
      active_scaffold_config.model
    end

    def origin_class_with_build_options
      [origin_class, {}]
    end

    # Builds search conditions by search params for column names. This allows urls like "contacts/list?company_id=5".
    def conditions_from_params
      conditions = nil
      params.reject {|key, value| [:controller, :action, :id, :page, :sort, :sort_direction].include?(key.to_sym)}.each do |key, value|
        next unless active_scaffold_config.model.columns.include?(key)
        conditions = merge_conditions(conditions, {"#{active_scaffold_config.model.table_name}__#{key}".to_sym => value})
      end
      conditions
    end

    def new_model
      model, build_options = origin_class_with_build_options
      if model.respond_to?(:sti_key)
        build_options[model.sti_key] = active_scaffold_config.model_id if nested? && nested.association && nested.association.collection?
        sti_key = model.sti_key.to_s
        if params[sti_key]  # in new action sti_key must be in params
          model = params[sti_key].constantize
        elsif params[:record] and params[:record][sti_key]  # in create action must be inside record key
          model = params[:record][sti_key].constantize
        end
      end
      model.new(build_options)
    end

    private
    def respond_to_action(action)
      respond_to do |type|
        action_formats.each do |format|
          type.send(format){ send("#{action}_respond_to_#{format}") }
        end
      end
    end

    def action_formats
      @action_formats ||= if respond_to? "#{action_name}_formats", true
        send("#{action_name}_formats")
      else
        (default_formats + active_scaffold_config.formats).uniq
      end
    end

    def response_code_for_rescue(exception)
      case exception
        when ActiveScaffold::RecordNotAllowed
          "403 Record Not Allowed"
        when ActiveScaffold::ActionNotAllowed
          "403 Action Not Allowed"
        else
          super
      end
    end
  end
end
