module ActiveScaffold
  module Helpers
    module FormColumnHelpers
      def active_scaffold_input_dragonfly(column, options)
        options = active_scaffold_input_text_options(options)
        input = file_field(:record, column.name, options)
        dragonfly = @record.send("#{column.name}")
        if dragonfly.present?
          js_remove_file_code = "jQuery(this).prev().val('true'); jQuery(this).parent().hide().next().show(); return false;";

          content = active_scaffold_column_dragonfly(column, @record)
          content_tag(:div,
            content + " | " +
              hidden_field(:record, "remove_#{column.name}", :value => "false") +
              content_tag(:a, as_(:remove_file), {:href => '#', :onclick => js_remove_file_code}) 
          ) + content_tag(:div, input, :style => "display: none")
        else
          input
        end
      end
    end
  end
end
