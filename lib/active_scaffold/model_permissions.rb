# This module attempts to create permissions conventions for your models. It supports english-based
# methods that let you restrict access per-model, per-record, per-column, per-action, and per-user. All at once.
#
# You may define instance methods in the following formats:
#  def #{column}_authorized_for_#{action}?
#  def #{column}_authorized?
#  def authorized_for_#{action}?

module ActiveScaffold
  module ModelPermissions
    # Whether the default permission is permissive or not
    # If set to true, then everything's allowed until configured otherwise
    def self.default_permission=(v); @@default_permission = v; end
    def self.default_permission; @@default_permission; end
    @@default_permission = true

    module Permissions
      def self.included(base)
        base.extend SecurityMethods
        base.send :include, SecurityMethods
      end

      module SecurityMethods
        # A generic authorization query. This is what will be called programatically, since
        # the actual permission methods can't be guaranteed to exist. And because we want to
        # intelligently combine multiple applicable methods.
        #
        # options[:crud_type] should be a CRUD verb (:create, :read, :update, :destroy)
        # options[:column] should be the name of a model attribute
        # options[:action] is the name of a method
        def authorized_for?(options = {})
          raise ArgumentError, "unknown crud type #{options[:crud_type]}" if options[:crud_type] and ![:create, :read, :update, :delete].include?(options[:crud_type])

          # column_authorized_for_crud_type? has the highest priority over other methods,
          # you can disable a crud verb and enable that verb for a column
          # (for example, disable update and enable inplace_edit in a column)
          method = column_and_crud_type_security_method(options[:column], options[:crud_type])
          return send(method) if method and respond_to?(method)

          # authorized_for_action? has higher priority than other methods,
          # you can disable a crud verb and enable an action with that crud verb
          # (for example, disable update and enable an action with update as crud type)
          method = action_security_method(options[:action])
          return send(method) if method and respond_to?(method)

          # collect other possibly-related methods that actually exist
          methods = [
            column_security_method(options[:column]),
            crud_type_security_method(options[:crud_type]),
          ].compact.select {|m| respond_to?(m)}

          # if any method returns false, then return false
          return false if methods.any? {|m| !send(m)}

          # if any method actually exists then it must've returned true, so return true
          return true unless methods.empty?

          # if no method exists, return the default permission
          return ModelPermissions.default_permission
        end

        private

        def column_security_method(column)
          "#{column}_authorized?" if column
        end

        def crud_type_security_method(crud_type)
          "authorized_for_#{crud_type}?" if crud_type
        end

        def action_security_method(action)
          "authorized_for_#{action}?" if action
        end

        def column_and_crud_type_security_method(column, crud_type)
          "#{column}_authorized_for_#{crud_type}?" if column and crud_type
        end
      end
    end
  end
end
