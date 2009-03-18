module ActiveRecord
  module Acts
    module BucketOn
      def self.included(base)
        base.send :extend, ClassMethods
      end
      
      module ClassMethods
        
      end
      
    end
  end
end