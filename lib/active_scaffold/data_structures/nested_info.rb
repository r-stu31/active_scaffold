module ActiveScaffold::DataStructures
  class NestedInfo
    def self.get(model, params)
      nested_info = {}
      begin
        nested_info[:name] = params[:association].to_sym
        nested_info[:parent_scaffold] = "#{params[:parent_scaffold].to_s.camelize}Controller".constantize
        nested_info[:parent_model] = nested_info[:parent_scaffold].active_scaffold_config.model
        nested_info[:parent_id] = params[nested_info[:parent_model].name.foreign_key]
        if nested_info[:parent_id]
          ActiveScaffold::DataStructures::NestedInfo.new(model, nested_info)
        end
      rescue ActiveScaffold::ControllerNotFound
        nil
      end
    end
    
    attr_accessor :association, :child_association, :parent_model, :parent_scaffold, :parent_id, :constrained_fields
        
    def initialize(model, nested_info)
      @parent_model = nested_info[:parent_model]
      @parent_id = nested_info[:parent_id]
      @parent_scaffold = nested_info[:parent_scaffold]
      @association = @parent_model.association_reflection(nested_info[:name])
      iterate_model_associations(model)
    end
    
    def to_params
      {:parent_scaffold => parent_scaffold.controller_path, :association => association[:name], :assoc_id => parent_id}
    end

    def parent_scope
      parent_model[parent_id]
    end

    def name
      association[:name]
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
    
    def sorted?
      association.has_key? :order
    end

    def default_sorting
      association[:order]
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
end
