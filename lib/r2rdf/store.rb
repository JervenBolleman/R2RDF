module R2RDF
  # handles connection and messaging to/from the triple store
  class Store
    def defaults
	    {
	      type: :fourstore,
	      url: "http://localhost:8080" #TODO port etc should eventually be extracted from URI if given
	    }
	  end

	  def add(file,graph)
	  	`curl --data-urlencode data@#{file} -d 'graph=http%3A%2F%2Frqtl.org%2F#{graph}' -d 'mime-type=application/x-turtle' #{@options[:url]}/data/`
	  end

    def initialize(options={})
      @options = defaults.merge(options)
    end

    def connection
      @connection ||= new_connection
    end

    def new_connection
      case @options[:type]
      when :fourstore
        @repo = RDF::FourStore::Repository.new("#{@options[:url]}/")
      end
    end

    #TODO any place these case statements exist should have a check on if the
    #repo conforms to the RDF::Repository interface, instead of calling insert
    #for each one.
    def load_statement(statement)
      case options[:type]
      when :fourstore
        repo.insert(s)
      end
    end

    def clear
    	@repo.clear_statements
    end

    def load_string
      case options[:type]
      when :fourstore

      end
    end

    def load(object, include_prefixes=true)
      if object.is_a? RDF::Statement
      	load_statement(object)
      # elsif object.is_a? String
        
      else
        puts "Don't know how to load objects of type #{object.class}"
      end
    end
  end
end