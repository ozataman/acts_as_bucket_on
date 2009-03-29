module ActiveRecord
  module Acts
    module BucketOn
      def self.included(base)
        base.send :extend, ClassMethods
      end
      
      module ClassMethods
        class InvalidBucketName < StandardError; end
        class InvalidConditions < StandardError; end
        class InvalidObjectArray < StandardError; end
        class InvalidObject < StandardError; end
        
        # Dynamic bucketing function
        def bucket(collection, params = {})
          params.assert_valid_keys([:conditions, :bucket_order])
          raise InvalidObjectArray, "Bucket input must be an array of ActiveRecord::Base objects" unless collection.is_a?(Array)
          
          condition_code = build_bucketing_condition(params.delete(:conditions))
          bucket_ordering_code = build_bucket_ordering(params.delete(:bucket_order))
          
          buckets = {}
          collection.each do |obj|
            unless obj.class.base_class && obj.class.base_class.descends_from_active_record?
              raise InvalidObject, "only ActiveRecord::Base descendants are allowed" 
            end                  
              
            begin
              key = obj.instance_eval(condition_code).try(:to_s) || 'nil'
              
            # if the given eval code raises an error for any reason
            # put the record in the unprocessed 'nil' bucket
            rescue
              key = 'nil'
            end
            
            buckets[key] ||= []
            buckets[key] << obj
          end
          
          # return ordered bucket keys and the buckets Hash
          [buckets.instance_eval(bucket_ordering_code), buckets]        
        end
        
        def acts_as_bucket_on(name, params = {})      
          bucket_name = name.to_s
          
          if bucket_name.blank?
            raise InvalidBucketName, "bucket name #{bucket_name} is not valid."
          end
          
          # save the given parameters to a class bucket parameters store
          write_inheritable_hash(:bucket_parameters, {bucket_name => params})
          
          # define a method that will call the dynamic bucketer with 
          # the previously saved bucketing parameters
          self.class_eval <<-HERE 
            def self.bucket_on_#{bucket_name}(collection)
              bucket(collection, read_inheritable_attribute(:bucket_parameters)['#{bucket_name}'])
            end
          HERE
                    
        end
        
        private
        
        # Build the qualities that bucketing will be based on
        # Accepts String, Symbol and Array objects
        def build_bucketing_condition(condition)
          if condition.nil?
            return nil
          elsif condition.is_a?(String) 
            condition
          elsif condition.is_a?(Symbol)
            "send(:#{condition.to_s})"
          elsif condition.is_a?(Array)
            str = condition.map {|c| build_bucketing_condition(c) }.join(" && ")
          else
            raise InvalidConditions, "invalid condition given to acts_as_bucket_on"
          end
        end
        
        # Once the buckets are generated, order the buckets and return that as an Array
        # Once ported to Ruby 1.9, we can simply return an ordered Hash
        def build_bucket_ordering(ordering)
          if ordering.nil?
            "keys"
          elsif ordering.is_a?(String)
            ordering
          elsif ordering.is_a?(Array) # methods to be applied as a chain to the resulting buckets.keys array.
            str = ordering.inject("keys") {|str, m| str + ".#{m}"}
          else
            raise InvalidConditions, "invalid bucket ordering given to acts_as_bucket_on"
          end
        end
        
      end
      
    end
  end
end