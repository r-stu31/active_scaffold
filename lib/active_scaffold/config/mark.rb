module ActiveScaffold::Config
  class Mark < Base
    self.crud_type = :read

    def initialize(core_config)
      @core = core_config
      if core_config.actions.include?(:update)
        @core.model.send(:include, ActiveScaffold::MarkedModel) unless @core.model.ancestors.include?(ActiveScaffold::MarkedModel)
        add_mark_column
      else
        raise "Mark action requires update action in controller for model: #{core_config.model.to_s}"
      end
    end
    
    protected
    
    def add_mark_column
      @core.columns.prepend(:marked)
      @core.columns[:marked].label = 'M'
      @core.columns[:marked].form_ui = :checkbox
      @core.columns[:marked].inplace_edit = true
      @core.columns[:marked].sort = false
      @core.list.columns = [:marked] + @core.list.columns.names_without_auth_check unless @core.list.columns.include? :marked
    end
  end
end
