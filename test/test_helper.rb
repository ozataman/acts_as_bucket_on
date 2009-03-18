require 'rubygems'
# require File.dirname(__FILE__) + "/../../../../config/environment.rb"
require 'active_record'
require 'active_support'
require 'active_support/test_case'
require File.dirname(__FILE__) + '/../init'

class BucketableModel < ActiveRecord::Base
  acts_as_bucket_on :horizon, :conditions => "self.due_at.strftime('%y%m%d')"
end