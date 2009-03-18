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
        
        def acts_as_bucket_on(name, bucket = {})
          bucket.assert_valid_keys([:conditions])
          
          condition_code = build_bucketing_condition(bucket.delete(:conditions))
          bucket_name = name.to_s
          
          if bucket_name.blank?
            raise InvalidBucketName, "bucket name #{bucket_name} is not valid."
          end
          
          self.class_eval <<-HERE
            def self.bucket_on_#{name}(objects)
              raise InvalidObjectArray, "Bucket input must be an array of ActiveRecord::Base objects" unless objects.is_a?(Array)
            
              buckets = {}
              objects.each do |obj|
                unless obj.class.base_class && obj.class.base_class.descends_from_active_record?
                  raise InvalidObject, "only ActiveRecord::Base descendants are allowed" 
                end                  
                  
                key = obj.instance_eval(%q(#{condition_code})).to_s || 'nil'
                buckets[key] = obj
              end
              buckets
            end
                      
          HERE
          
        end
        
        private
        
        # Build the qualities that bucketing will be based on
        # Accepts String, Symbol and Array objects
        def build_bucketing_condition(condition)
          if condition.is_a?(String) 
            condition
          elsif condition.is_a?(Symbol)
            "send(:#{condition.to_s})"
          elsif condition.is_a?(Array)
            str = condition.map {|c| build_bucketing_condition(c) }.join(" + ")
          else
            raise InvalidConditions, "invalid condition given to acts_as_bucket_on"
          end
          
        end
      end
      
    end
  end
end