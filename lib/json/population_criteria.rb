module JSON
  # Represents an HQMF population criteria, also supports all the same methods as
  # HQMF::Precondition
  class PopulationCriteria
  
    include HQMF::Utilities
  
    attr_reader :preconditions, :id
    
    # Create a new population criteria
    # @param [String] id
    # @param [Array#Precondition] preconditions 
    def initialize(id, preconditions)
      @id = id
      @preconditions = preconditions 
    end
    
    # Create a new population criteria from a JSON hash keyed off symbols
    def self.from_json(id, json)
      preconditions = json[:preconditions].map {|preciondition| JSON::Precondition.from_json(preciondition)} 
      JSON::PopulationCriteria.new(id, preconditions)
    end
    
    def to_json
      x = nil
      json = build_hash(self, [:conjunction?])
      json[:preconditions] = x if x = json_array(@preconditions)
      {self.id.to_sym => json}
    end
    
    
    # Return true of this precondition represents a conjunction with nested preconditions
    # or false of this precondition is a reference to a data criteria
    def conjunction?
      true
    end

    # Get the conjunction code, e.g. allTrue, allFalse
    # @return [String] conjunction code
    def conjunction_code
      case id
      when 'IPP', 'DENOM', 'NUMER'
        'allTrue'
      when 'DENEXCEP'
        'atLeastOneTrue'
      else
        raise "Unknown population type [#{id}]"
      end
    end
    
  end
  
end