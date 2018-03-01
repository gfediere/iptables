module IPTables
  class Tables
    def initialize(table)
      @table = table
    end

    def filter
      # Delete *filter
      table = @table.delete_if{ |r| /^\*(\S+)$/.match(r) }
      # Delete comments
      table = @table.delete_if{ |r| /^#/.match(r) }
      # Delete everything starting with :
      table = @table.delete_if{ |r| /^:/.match(r) }
      table.map! {|r| r.chomp }
      
      # Return Array with only rules
      table
    end
  end
end
