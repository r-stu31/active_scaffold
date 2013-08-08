# coding: utf-8
module ActiveScaffold
  module Helpers
    # Helpers that assist with the rendering of a List Column
    module ListColumnHelpers
      def get_column_value(record, column)
        begin
          # check for an override helper
          value = if column_override? column
            # we only pass the record as the argument. we previously also passed the formatted_value,
            # but mike perham pointed out that prohibited the usage of overrides to improve on the
            # performance of our default formatting. see issue #138.
            send(column_override(column), record)
          # second, check if the dev has specified a valid list_ui for this column
          elsif column.list_ui and override_column_ui?(column.list_ui)
            send(override_column_ui(column.list_ui), column, record)
          elsif column.column and override_column_ui?(column.column[:type])
            send(override_column_ui(column.column[:type]), column, record)
          else
            format_column_value(record, column)
          end

          value = '&nbsp;'.html_safe if value.nil? or (value.respond_to?(:empty?) and value.empty?) # fix for IE 6
          return value
        rescue Exception => e
          logger.error Time.now.to_s + "#{e.inspect} -- on the ActiveScaffold column = :#{column.name} in #{controller.class}"
          raise e
        end
      end

      # TODO: move empty_field_text and &nbsp; logic in here?
      # TODO: we need to distinguish between the automatic links *we* create and the ones that the dev specified. some logic may not apply if the dev specified the link.
      def render_list_column(text, column, record)
        if column.link
          link = column.link
          associated = column.association ? record.send(column.association[:name]) : nil
          url_options = params_for(:action => nil, :id => record.id)

          # setup automatic link
          if column.autolink? && column.singular_association? # link to inline form
            link = action_link_to_inline_form(column, record, associated, text)
            return text if link.nil?
          else
            url_options[:link] = text
          end

          if column_link_authorized?(link, column, record, associated)
            render_action_link(link, url_options, record)
          else
            "<a class='disabled'>#{text}</a>".html_safe
          end
        elsif inplace_edit?(record, column)
          active_scaffold_inplace_edit(record, column, {:formatted_column => text})
        else
          text
        end
      end

      # setup the action link to inline form
      def action_link_to_inline_form(column, record, associated, text)
        link = column.link.clone
        link.label = text
        configure_column_link(link, associated, column.actions_for_association_links)
      end

      def configure_column_link(link, associated, actions)
        if column_empty?(associated) # if association is empty, we only can link to create form
          if actions.include?(:new)
            link.action = 'new'
            link.crud_type = :create
            link.label = as_(:create_new)
          end
        elsif actions.include?(:edit)
          link.action = 'edit'
          link.crud_type = :update
        elsif actions.include?(:show)
          link.action = 'show'
          link.crud_type = :read
        elsif actions.include?(:list)
          link.action = 'index'
          link.crud_type = :read
        end
        link if link.action.present?
      end

      def column_link_authorized?(link, column, record, associated)
        if column.association
          associated_for_authorized = if associated.nil? || (associated.respond_to?(:blank?) && associated.blank?)
            column.association.associated_class
          elsif column.plural_association?
            associated.first
          else
            associated
          end
          authorized = associated_for_authorized.authorized_for?(:crud_type => link.crud_type)
          authorized = authorized and record.authorized_for?(:crud_type => :update, :column => column.name) if link.crud_type == :create
          authorized
        else
          record.authorized_for?(:crud_type => link.crud_type)
        end
      end

      # There are two basic ways to clean a column's value: h() and sanitize(). The latter is useful
      # when the column contains *valid* html data, and you want to just disable any scripting. People
      # can always use field overrides to clean data one way or the other, but having this override
      # lets people decide which way it should happen by default.
      #
      # Why is it not a configuration option? Because it seems like a somewhat rare request. But it
      # could eventually be an option in config.list (and config.show, I guess).
      def clean_column_value(v)
        h(v)
      end

      ##
      ## Overrides
      ##
      def active_scaffold_column_text(column, record)
        clean_column_value(truncate(record.send(column.name), :length => column.options[:truncate] || 50))
      end

      def active_scaffold_column_checkbox(column, record)
        options = {:disabled => true, :id => nil, :object => record}
        options.delete(:disabled) if inplace_edit?(record, column)
        check_box(:record, column.name, options)
      end

      def column_override_name(column, class_prefix = false)
        "#{clean_class_name(column.active_record_class.name) + '_' if class_prefix}#{clean_column_name(column.name)}_column"
      end

      def column_override(column)
        method_with_class = column_override_name(column, true)
        return method_with_class if respond_to?(method_with_class)
        method = column_override_name(column)
        method if respond_to?(method)
      end
      alias_method :column_override?, :column_override

      def override_column_ui?(list_ui)
        respond_to?(override_column_ui(list_ui))
      end

      # the naming convention for overriding column types with helpers
      def override_column_ui(list_ui)
        "active_scaffold_column_#{list_ui}"
      end

      ##
      ## Formatting
      ##
      def format_column_value(record, column, value = nil)
        value ||= record.send(column.name) unless record.nil?
        if value && column.association # cache association size before calling column_empty?
          associated_size = value.size if column.plural_association? and column.associated_number? # get count before cache association
        end
        if column.association.nil? or column_empty?(value)
          if column.form_ui == :select && column.options[:options]
            text, val = column.options[:options].find {|text, val| (val.nil? ? text : val).to_s == value.to_s}
            value = active_scaffold_translated_option(column, text, val).first if text
          end
          if value.is_a? Numeric
            format_number_value(value, column.options)
          else
            format_value(value, column.options)
          end
        else
          format_association_value(value, column, associated_size)
        end
      end

      def format_number_value(value, options = {})
        value = case options[:format]
          when :size
            number_to_human_size(value, options[:i18n_options] || {})
          when :percentage
            number_to_percentage(value, options[:i18n_options] || {})
          when :currency
            number_to_currency(value, options[:i18n_options] || {})
          when :i18n_number
            number_with_delimiter(value, options[:i18n_options] || {})
          else
            value
        end
        clean_column_value(value)
      end

      def format_association_value(value, column, size)
        format_value case
          when column.singular_association?
            value.to_label
          when column.plural_association?
            if column.associated_limit.nil?
              firsts = value.collect { |v| v.to_label }
            else
              firsts = value.first(column.associated_limit)
              firsts.collect! { |v| v.to_label }
              firsts[column.associated_limit] = '…' if value.size > column.associated_limit
            end
            if column.associated_limit == 0
              size if column.associated_number?
            else
              joined_associated = firsts.join(active_scaffold_config.list.association_join_text)
              joined_associated << " (#{size})" if column.associated_number? and column.associated_limit and value.size > column.associated_limit
              joined_associated
            end
        end
      end

      def format_value(column_value, options = {})
        value = if column_empty?(column_value)
          active_scaffold_config.list.empty_field_text
        elsif column_value.is_a?(Time) || column_value.is_a?(Date)
          l(column_value, :format => options[:format] || :default)
        elsif [FalseClass, TrueClass].include?(column_value.class)
          as_(column_value.to_s.to_sym)
        else
          column_value.to_s
        end
        clean_column_value(value)
      end

      # ==========
      # = Inline Edit =
      # ==========

      def inplace_edit?(record, column)
        if column.inplace_edit
          editable = controller.send(:update_authorized?, record) if controller.respond_to?(:update_authorized?)
          editable = record.authorized_for?(:crud_type => :update, :column => column.name) if editable.nil? || editable == true
          editable
        end
      end

      def inplace_edit_cloning?(column)
         column.inplace_edit != :ajax and (override_form_field?(column) or column.form_ui or (column.column and override_input?(column.column[:type])))
      end

      def active_scaffold_inplace_edit(record, column, options = {})
        formatted_column = options[:formatted_column] || format_column_value(record, column)
        klass = (column.name == :marked ? 'mark_record_field' : 'in_place_editor_field')
        id_options = {:id => record.id.to_s, :action => 'update_column', :name => column.name.to_s}
        tag_options = {:id => element_cell_id(id_options), :class => klass,
                       :title => as_(:click_to_edit), 'data-ie_id' => record.id.to_s}

        content_tag(:span, formatted_column, tag_options)
      end

      def inplace_edit_control(column)
        if inplace_edit?(active_scaffold_config.model, column) and inplace_edit_cloning?(column)
          old_record, @record = @record, new_model
          column = column.clone
          column.options = column.options.clone
          column.form_ui = :select if (column.association && column.form_ui.nil?)
          content_tag(:div, active_scaffold_input_for(column), :style => "display:none;", :class => inplace_edit_control_css_class).tap do
            @record = old_record
          end
        end
      end

      def inplace_edit_control_css_class
        "as_inplace_pattern"
      end

      def inplace_edit_tag_attributes(column)
        tag_options = {}
        if column.name == :marked
          tag_options['data-ie_url'] = '#'
        else
          tag_options['data-ie_url'] = url_for({:controller => params_for[:controller], :action => 'update_column', :column => column.name, :id => '__id__'})
        end
        tag_options['data-ie_cancel_text'] = column.options[:cancel_text] || as_(:cancel)
        tag_options['data-ie_loading_text'] = column.options[:loading_text] || as_(:loading)
        tag_options['data-ie_save_text'] = column.options[:save_text] || as_(:update)
        tag_options['data-ie_saving_text'] = column.options[:saving_text] || as_(:saving)
        tag_options['data-ie_rows'] = column.options[:rows] || 5 if column.column.try(:type) == :text
        tag_options['data-ie_cols'] = column.options[:cols] if column.options[:cols]
        tag_options['data-ie_size'] = column.options[:size] if column.options[:size]

        if column.list_ui == :checkbox
          tag_options['data-ie_mode'] = :inline_checkbox
        elsif inplace_edit_cloning?(column)
          tag_options['data-ie_mode'] = :clone
        elsif column.inplace_edit == :ajax
          url = url_for(:controller => params_for[:controller], :action => 'render_field', :id => '__id__', :column => column.name, :update_column => column.name, :in_place_editing => true)
          plural = column.plural_association? && !override_form_field?(column) && [:select, :record_select].include?(column.form_ui)
          tag_options['data-ie_render_url'] = url
          tag_options['data-ie_mode'] = :ajax
          tag_options['data-ie_plural'] = plural
        end
        tag_options
      end

      def mark_column_heading
        tag_options = {:id => "#{controller_id}_mark_heading", :class => 'mark_heading', 'data-ie_url' => '#', 'data-tbody_id' => active_scaffold_tbody_id}
        content_tag(:span, check_box_tag("#{controller_id}_mark_heading_span_input", true, false), tag_options)
      end

      def render_column_heading(column, sorting, sort_direction)
        tag_options = {:id => active_scaffold_column_header_id(column), :class => column_heading_class(column, sorting), :title => column.description}
        tag_options.merge!(inplace_edit_tag_attributes(column)) if column.inplace_edit
        content_tag(:th, column_heading_value(column, sorting, sort_direction) + inplace_edit_control(column), tag_options)
      end

      def column_heading_value(column, sorting, sort_direction)
        if column.sortable?
          options = {:id => nil, :class => "as_sort",
                     'data-page-history' => controller_id,
                     :remote => true, :method => :get}
          url_options = params_for(:action => :index, :page => 1,
                           :sort => column.name, :sort_direction => sort_direction)
          link_to column.label, url_options, options
        else
          if column.name == :marked
            mark_column_heading
          else
            content_tag(:p, column.label)
          end
        end
      end
    end
  end
end
