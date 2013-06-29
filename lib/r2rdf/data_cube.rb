  #monkey patch to make rdf string w/ heredocs prettier ;)	
  class String
    def unindent
      gsub /^#{self[/\A\s*/]}/, ''
     # gsub(/^#{scan(/^\s*/).min_by{|l|l.length}}/, "")
    end

  end

module R2RDF
  # used to generate data cube observations, data structure definitions, etc
  module DataCube
    def defaults
      {
        type: :dataframe,
        dimensions: ["refRow"],
        codes: ["refRow"],
        measures: [:all],
      }
    end

		def prefixes(options={})
      # type = options[:type] || :dataframe
      options = defaults().merge(options)
			<<-EOF.unindent
			@prefix : <http://www.rqtl.org/ns/#> .
			@prefix qb: <http://purl.org/linked-data/cube#> .
			@prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
			@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
			@prefix prop: <http://www.rqtl.org/dc/properties/> .
			@prefix cs: <http://www.rqtl.org/dc/cs/> .
			@prefix code: <http://www.rqtl.org/dc/code/> .
			@prefix class: <http://www.rqtl.org/dc/class/> .
			@prefix owl: <http://www.w3.org/2002/07/owl#> .
			@prefix skos: <http://www.w3.org/2004/02/skos/core#> .

			EOF
		end

    def data_structure_definition(rexp,var,options={})
      # type = options[:type] || :dataframe
      options = defaults().merge(options)
			str = ":dsd-#{var} a qb:DataStructureDefinition;\n"
			if options[:type] == :dataframe
				str << "\tqb:component cs:refRow ,\n"
				#should eventually move these reusable map functions over to
				#the analyzer class
				rexp.payload.names.map{|n|
							str << "\t\tcs:#{n} ,\n"
				}
				str[-2]='.'
				str<<"\n"
			end
			str
			# Still needs: 
			# Recursiveness
			#	class and other attributes
    end

		def dataset(rexp,var,options={})
      # type = options[:type] || :dataframe
      options = defaults().merge(options)
			<<-EOF.unindent    
			:dataset-#{@var} a qb:DataSet ;
				rdfs:label "#{var}"@en ;
				qb:structure :dsd-#{@var} .

			EOF
		end

		def component_specifications(rexp,var,options={})
      # type = options[:type] || :dataframe
      options = defaults().merge(options)
			specs = []
			if options[:type] == :dataframe
				options[:dimensions].map{|d|
        specs << <<-EOF.unindent
					cs:#{d} a qb:ComponentSpecification ;
						rdfs:label "#{d} Component" ;
						qb:dimension prop:#{d} .

					EOF
        }
				#still needs method for distinguishing measure vs dimension
				if options[:measures].first == :all
          measures = rexp.payload.names - options[:dimensions]
        else
          measures = ((rexp.payload.names - options[:dimensions]) & options[:measures])
        end
        measures.map{|n|
					specs << <<-EOF.unindent
						cs:#{n} a qb:ComponentSpecification ;
							rdfs:label "#{n} Component" ;
							qb:measure prop:#{n} .

						EOF
				}
			end
			specs
		end

		def dimension_properties(rexp,var,options={})
      # type = options[:type] || :dataframe
      options = defaults().merge(options)
      props = []
      if options[:type] == :dataframe
  			if options[:dimensions].include? "refRow"
          props << <<-EOF.unindent
    			prop:refRow a rdf:Property, qb:DimensionProperty ;
    				rdfs:label "Row"@en .
    			
    			EOF
        else
        	#Keep row for now even if not specified. Maybe remove later to save space?
          props << <<-EOF.unindent
          prop:refRow a rdf:Property;
            rdfs:label "Row"@en .

          EOF
        end
        (options[:dimensions] - ["refRow"]).map{|d|
          
          if options[:codes].include?(d)
          	props << <<-EOF.unindent
          	prop:#{d} a rdf:Property, qb:DimensionProperty ;
          	  rdfs:label "#{d}"@en ;
          	  qb:codeList code:#{d.downcase} ;
          	  rdfs:range code:#{d.downcase.capitalize} .

          	EOF
          else
	          props << <<-EOF.unindent
	          prop:#{d} a rdf:Property, qb:DimensionProperty ;
	            rdfs:label "#{d}"@en .
	            
	          EOF
          end
        }
      end
      props
		end

		def measure_properties(rexp,var,options={})
      # type = options[:type] || :dataframe
      options = defaults().merge(options)
			props = []
			if options[:type] == :dataframe
        if options[:measures].first == :all
  				(rexp.payload.names - options[:dimensions]).map{|n|
  					props <<  <<-EOF.unindent
  					prop:#{n} a rdf:Property, qb:MeasureProperty ;
  						rdfs:label "#{n}"@en .
  				
  					EOF
          }
        else
          ((options[:measures] - options[:dimensions]) & rexp.payload.names).map{ |m|
            
            props <<  <<-EOF.unindent
            :#{m} a rdf:Property, qb:MeasureProperty ;
              rdfs:label "#{m}"@en .
          
            EOF
          }
        end
			end
			props
		end

		def rows(rexp, var, options={})
      # type = options[:type] || :dataframe
      options = defaults().merge(options)
			rows = []
			if options[:type] == :dataframe
        names = rexp.attr.payload["row.names"].to_ruby
        names = 1..rexp.payload.first.to_ruby.size unless names.first
				names.map{|r|
					rows << <<-EOF.unindent
					:#{r} a prop:refRow ;
						rdfs:label "#{r}" .

					EOF
				}
			end
			rows
		end
	
		def observations(rexp, var, options={})	
      # type = options[:type] || :dataframe
      options = defaults().merge(options)
			obs = []
			if options[:type] == :dataframe
        row_names = rexp.attr.payload["row.names"].to_ruby
        row_names = 1..rexp.payload.first.to_ruby.size unless row_names.first
				row_names.each_with_index.map{|r, i|
					str = <<-EOF.unindent 
						:obs#{r} a qb:Observation ;
							qb:dataSet :dataset-#{var} ;
							rdfs:label "#{r}" ;
						EOF
					str << "\tprop:refRow :r#{r} ;\n" if options[:dimensions].include? "refRow"
					#TODO proper naming for dimensions, hopefully using coded properties
					(options[:dimensions] - ["refRow"]).map{|d| str << "\tprop:#{d} :#{to_resource(rexp.payload[d].to_ruby[i])} ;\n"}
					if options[:measures].first == :all
						(rexp.payload.names - options[:dimensions]).map{|n| str << "\tprop:#{n} #{to_literal(rexp.payload[n].to_ruby[i])} ;\n"}
					else
						((options[:measures] - options[:dimensions]) & rexp.payload.names).map{|n| 
							str << "\tprop:#{n} #{to_literal(rexp.payload[n].to_ruby[i])} ;\n"
						}
					end
					str << "\t.\n\n"
					obs << str
				}
			end
			obs
		end

		def code_lists(rexp, var, options={})
			options = defaults().merge(options)
			codes = []
			if options[:type] == :dataframe
				row_names = rexp.attr.payload["row.names"].to_ruby
        row_names = 1..rexp.payload.first.to_ruby.size unless row_names.first
        code_rows = (options[:codes] & row_names) || row_names
        code_rows.map{|code|
        	# include skos:definition?
        	str = <<-EOF.unindent
        		code:#{code.downcase.capitalize} a rdfs:class, owl:Class;
        			rdfs:subClassOf skos:Concept ;
        			rdfs:label "Code list for #{code} - codelist class"@en;
        			rdfs:comment "Specifies the #{code} for each observation";
        			rdfs:seeAlso code:#{code.downcase}

        		code:#{code.downcase} a skos:ConceptScheme;
        			skos:prefLabel "Code list for #{code} - codelist scheme"@en;
        			rdfs:label "Code list for #{code} - codelist scheme"@en;
        			skos:notation "CL_#{code.upcase}";
        			skos:note "Specifies the #{code} for each observation";
        	EOF
        	rexp.payload[code].uniq.map{|value|
        		str << "\tskos:hasTopConcept code:#{code.downcase}_#{value} ;\n"
        	}
        	str <<"\t.\n"
        	codes << str
        }
			end

			codes
		end

		def concept_codes(rexp, var, options={})
			options = defaults().merge(options)
			codes = []
			if options[:type] == :dataframe
				row_names = rexp.attr.payload["row.names"].to_ruby
        row_names = 1..rexp.payload.first.to_ruby.size unless row_names.first
        code_rows = (options[:codes] & row_names) || row_names
        code_rows.map{|code|
        	rexp.payload[code].uniq.map{|value|
        	codes << <<-EOF.unindent
        		code:#{code.downcase}_#{value} a skos:Concept, code:#{code.downcase.capitalize};
        			skos:topConceptOf code:#{code.downcase} ;
        			skos:prefLabel "#{value}" ;
        			skos:inScheme code:#{code.downcase} .

        	EOF
        	}
        }
			end

			codes
		end

		def to_resource(obj)
			if obj.is_a? String
				#TODO decide the right way to handle missing values, since RDF has no null
				#probably throw an error here since a missing resource is a bigger problem
				obj = "null" if obj.empty?
				
				#TODO  remove special characters (faster) as well (eg '?')
				obj.gsub(' ','_').gsub('?','')
			elsif obj == nil
				"null"
			elsif obj.is_a? Numeric
				#resources cannot be referred to purely by integer (?)
				"n"+obj.to_s
			else
				obj
			end
		end

		def to_literal(obj)
			if obj.is_a? String
				'"'+obj+'"'
			elsif obj == nil
				#TODO decide the right way to handle missing values, since RDF has no null
				-1
			else
				obj
			end
		end
  end

	class Cube
		include R2RDF::DataCube
		
		def initialize(var)
			@var = var
		end

		def rexp
			#maybe create client here?
		end

		def generate_n3(rexp,options={})
			str = prefixes()
			str << data_structure_definition(rexp, @var, options)
			str << dataset(rexp, @var, options)
			component_specifications(rexp, @var, options).map{ |c| str << c }
			dimension_properties(rexp, @var, options).map{|p| str << p}
			measure_properties(rexp, @var, options).map{|p| str << p}
			code_lists(rexp, @var, options).map{|l| str << l}
			concept_codes(rexp, @var, options).map{|c| str << c}
			# rows(rexp, @var, options).map{|r| str << r}
			observations(rexp, @var, options).map{|o| str << o}
			str
		end
	end
end
