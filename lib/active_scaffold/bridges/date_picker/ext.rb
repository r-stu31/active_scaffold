class File #:nodoc:

  unless File.respond_to?(:binread)
    def self.binread(file)
      File.open(file, 'rb') { |f| f.read }
    end
  end

end 

ActiveScaffold::Config::Core.class_eval do
  def initialize_with_date_picker(model_id)
    initialize_without_date_picker(model_id)
    
    date_picker_fields = self.model.db_schema.collect {|name,properties| {:name => name, :type => properties[:type]} if [:date, :datetime].include?(properties[:type])}.compact
    # check to see if file column was used on the model
    return if date_picker_fields.empty?
    
    # automatically set the forum_ui to a file column
    date_picker_fields.each{|field|
      col_config = self.columns[field[:name]] 
      col_config.form_ui = (field[:type] == :date ? :date_picker : :datetime_picker)
    }
  end
  
  alias_method_chain :initialize, :date_picker
end

ActionView::Base.class_eval do
  include ActiveScaffold::Bridges::Shared::DateBridge::SearchColumnHelpers
  alias_method :active_scaffold_search_date_picker, :active_scaffold_search_date_bridge
  alias_method :active_scaffold_search_datetime_picker, :active_scaffold_search_date_bridge
  include ActiveScaffold::Bridges::Shared::DateBridge::HumanConditionHelpers
  alias_method :active_scaffold_human_condition_date_picker, :active_scaffold_human_condition_date_bridge
  alias_method :active_scaffold_human_condition_datetime_picker, :active_scaffold_human_condition_date_bridge
  include ActiveScaffold::Bridges::DatePicker::Helper::SearchColumnHelpers
  include ActiveScaffold::Bridges::DatePicker::Helper::FormColumnHelpers
  alias_method :active_scaffold_input_datetime_picker, :active_scaffold_input_date_picker
  include ActiveScaffold::Bridges::DatePicker::Helper::DatepickerColumnHelpers
end
ActiveScaffold::Finder::ClassMethods.module_eval do
  include ActiveScaffold::Bridges::Shared::DateBridge::Finder::ClassMethods
  alias_method :condition_for_date_picker_type, :condition_for_date_bridge_type
  alias_method :condition_for_datetime_picker_type, :condition_for_date_picker_type
end
