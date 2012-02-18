module ActiveScaffold::DataStructures
  # encapsulates the column sorting configuration for the List view
  class Sorting
    def initialize(columns)
      # a ActiveScaffold::DataStructures::Columns instance
      @columns = columns

      # @clauses is an array of pairs: [[column, params], ...]
      # where 'column' is a ActiveScaffold::DataStructures::Column instance and
      # 'params' is a hash with :table, :column, :descending keys
      @clauses = []

      # hash: 'column name'.to_sym => 'index to @clauses array'.to_i
      @cindex = {}

      # synchronize access to @cindex and @clauses
      @mutex = Mutex.new
    end
    
    def set_default_sorting(model)
      order_clauses = model.dataset.opts[:order]

      # If an ORDER BY clause is found set default sorting according to it, else
      # fallback to setting primary key ordering
      if order_clauses
        # we are going to return nil from 'self.clause', but the @clauses need to be set for determining the sorting properties for view
        set_sorting_from_order_clause(order_clauses, model.table_name)
        @default_sorting = true
      else
        set(model.primary_key) if model.primary_key
      end
    end

    def set_nested_sorting(table_name, order_clause)
      clear
      set_sorting_from_order_clause(order_clause, table_name)
    end
    
    # add a clause to the sorting, assuming the column is sortable
    def add(order, params = nil)
      params = extract_order_params(order) unless params
      column = get_column(params[:column])
      raise ArgumentError, "Could not find column #{params[:column]} for #{order.inspect}" if column.nil?
      if column.sortable?
        @mutex.synchronize do
          @clauses << [column, params]
          @cindex[params[:column]] = @clauses.count - 1
        end
      end
      raise ArgumentError, "Can't mix :method- and :sql-based sorting" if mixed_sorting?
    end

    def set(*args)
      clear
      args.each {|a| add(a)}
    end

    # clears the sorting
    def clear
      @mutex.synchronize do
        @default_sorting = false
        @clauses = []
        @cindex = {}
      end
    end

    # checks whether the given column (a Column object or a column name) is in the sorting
    def sorts_on?(column)
      !get_clause(column).nil?
    end

    def direction_of(column)
      c = @mutex.synchronize do
        i = @cindex[(column.respond_to?(:name) ? column.name : column)]
        @clauses[i] if i
      end
      if c
        c[1][:descending] ? 'DESC' : 'ASC'
      end
    end

    # checks whether any column is configured to sort by method (using a proc)
    def sorts_by_method?
      @clauses.any? { |sorting| sorting[0].sort.is_a? Hash and sorting[0].sort.has_key? :method }
    end

    def sorts_by_sql?
      @clauses.any? { |sorting| sorting[0].sort.is_a? Hash and sorting[0].sort.has_key? :sql }
    end

    # provides quick access to the first (and sometimes only) clause
    def first
      @clauses.first
    end

    # builds an order-by clause
    def clause
      return nil if sorts_by_method? || default_sorting?
      @clauses.collect do |column,params|
        if column.sort[:sql]
          order = *column.sort[:sql]
          order = order.collect {|o| o.respond_to?(:invert) ? o.invert : o.desc} if params[:descending]
          order
        end
      end.flatten.compact
    end

    protected

    # retrieves the sorting clause for the given column
    def get_clause(column)
      @mutex.synchronize do
        i = @cindex[(column.respond_to?(:name) ? column.name : column)]
        @clauses[i] if i
      end
    end

    # possibly converts the given argument into a column object from @columns (if it's not already)
    def get_column(name_or_column)
      # it's a column
      return name_or_column if name_or_column.is_a? ActiveScaffold::DataStructures::Column
      # it's a name
      return @columns[name_or_column]
    end

    def mixed_sorting?
      sorts_by_method? and sorts_by_sql?
    end
    
    def default_sorting?
      @default_sorting
    end

    def set_sorting_from_order_clause(order_clauses, model_table_name = nil)
      clear
      order_clauses.each do |criterion|
        params = extract_order_params(criterion)
        add(criterion, params) unless different_table?(model_table_name, params[:table])
      end
    end
    
    def get_table_column(tcol)
      table, column = tcol.to_s.split('__')
      if column
        [table.to_sym, column.to_sym]
      else
        [nil, table.to_sym]
      end
    end

    def extract_order_params(criterion)
      if criterion.respond_to?(:expression) and criterion.respond_to?(:descending)  # Sequel::SQL::OrderedExpression
        expression = criterion.expression
        if expression.respond_to?(:table) and expression.respond_to?(:column)  # Sequel::SQL::QualifiedIdentifier
          table = expression.table
          column = expression.column
        else
          table, column = get_table_column(expression)
        end
        descending = criterion.descending
      else
        table, column = get_table_column(criterion)
        descending = false
      end
      {:table => table, :column => column, :descending => descending}
    end
    
    def different_table?(model_table_name, order_table_name)
      model_table_name and order_table_name and model_table_name != order_table_name
    end
  end
end
