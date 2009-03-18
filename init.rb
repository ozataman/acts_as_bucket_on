require 'acts_as_bucket_on'

ActiveRecord::Base.send :include, ActiveRecord::Acts::BucketOn

RAILS_DEFAULT_LOGGER.info "** acts_as_bucket_on: initialized properly."