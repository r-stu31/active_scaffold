module ActiveScaffold::DataStructures
  class NestedInfo
    def self.get(model, params)
      nested_info = {}
      begin
        nested_info[:name] = (params[:association] || params[:named_scope]).to_sym
        nested_info[:parent_scaffold] = "#{params[:parent_scaffold].to_s.camelize}Controller".constantize
        nested_info[:parent_model] = nested_info[:parent_scaffold].active_scaffold_config.model
        nested_info[:parent_id] = params[nested_info[:parent_model].name.foreign_key]
        if nested_info[:parent_id]
          unless params[:association].nil?
            ActiveScaffold::DataStructures::NestedInfoAssociation.new(model, nested_info)
          else
            ActiveScaffold::DataStructures::NestedInfoScope.new(model, nested_info)
          end
        end
      rescue ActiveScaffold::ControllerNotFound
        nil
      end
    end
    
    attr_accessor :association, :child_association, :parent_model, :parent_scaffold, :parent_id, :constrained_fields, :scope
        
    def initialize(model, nested_info)
      @parent_model = nested_info[:parent_model]
      @parent_id = nested_info[:parent_id]
      @parent_scaffold = nested_info[:parent_scaffold]
    end
    
    def to_params
      {:parent_scaffold => parent_scaffold.controller_path}
    end
    
    def new_instance?
      result = @new_instance.nil?
      @new_instance = false
      result
    end
    
    def parent_scope
      parent_model.find(parent_id)
    end
    
    def habtm?
      false 
    end
    
    def belongs_to?
      false
    end

    def has_one?
      false
    end
    
    def readonly?
      false
    end

    def sorted?
      false
    end
  end
  
  class NestedInfoAssociation < NestedInfo
    def initialize(model, nested_info)
      super(model, nested_info)
      @association = parent_model.association_reflection(nested_info[:name])
      iterate_model_associations(model)
    end
    
    def name
      self.association[:name]
    end
    
    def habtm?
      association[:type] == :many_to_many
    end
    
    def belongs_to?
      association[:type] == :many_to_one
    end

    def has_one?
      association[:type] == :one_to_one
    end
    
    def readonly?
      false
    end

    def sorted?
      association.has_key? :order
    end

    def default_sorting
      association[:order]
    end
    
    def to_params
      super.merge(:association => @association[:name], :assoc_id => parent_id)
    end
    
    protected
    
    def iterate_model_associations(model)
      @constrained_fields = []
      @constrained_fields << association[:key] unless belongs_to?
      model.association_reflections.each do |ass_name, ass_properties|
        if !ass_properties[:type] == :many_to_one && association[:key] == ass_properties[:class_name].foreign_key
          constrained_fields << ass_name
          @child_association = ass_properties if ass_properties.associated_class == @parent_model
        end
        if association[:key] == ass_properties[:key]
          # show columns for has_many and has_one child associationes
          constrained_fields << ass_name if ass_properties[:type] == :many_to_one
          @child_association = ass_properties if ass_properties.associated_class == @parent_model
        end
      end
    end
  end
  
  class NestedInfoScope < NestedInfo
    def initialize(model, nested_info)
      super(model, nested_info)
      @scope = nested_info[:name]
      @constrained_fields = [] 
    end
    
    def to_params
      super.merge(:named_scope => @scope)
    end
    
    def name
      self.scope
    end
  end
end
