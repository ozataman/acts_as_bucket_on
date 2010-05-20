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
          params.assert_valid_keys([:conditions, :bucket_order, :max_buckets, :bucket_limit, :include_other])
          raise InvalidObjectArray, "Input must respond to each (Enumerable)" unless collection.respond_to?(:each)
          
          condition_code = build_bucketing_condition(params[:conditions])
          bucket_ordering_code = build_bucket_ordering(params[:bucket_order])
          
          buckets = {}
          human_key_mappings = {}
          collection.each do |obj|
            unless obj.class.respond_to?(:base_class) && obj.class.base_class.descends_from_active_record?
              raise InvalidObject, "only ActiveRecord::Base descendants are allowed" 
            end                  
              
            begin
              key, human_key = obj.instance_eval(condition_code) || ['nil', 'nil']
              
            # if the given eval code raises an error for any reason
            # put the record in the unprocessed 'nil' bucket
            rescue
              key, human_key = ['nil', 'nil']
            end
            
            human_key_mappings[key] = human_key
            
            buckets[key] ||= []
            
            buckets[key] << obj
          end
          
          # order the keys and make sure each ordered key is actually present in the resulting dataset
          ordered_keys = buckets.instance_eval(bucket_ordering_code).map {|ok| human_key_mappings.keys.include?(ok) ? ok : nil}.compact
                    
          # return ordered bucket keys and the buckets Hash
          [ordered_keys, human_key_mappings, buckets]        
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
        
        # Once the buckets are generated, the string defined here will be evaluated against
        # the buckets hash.
        # Once evaluated, the ordering function should 
        # return the sorted bucket keys as an Array.
        # Once ported to Ruby 1.9, we can simply return an ordered Hash.
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