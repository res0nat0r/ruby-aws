# $Id: setup.rb,v 1.3 2008/06/22 11:50:23 ianmacd Exp $
#

# Attempt to load Ruby/AWS using RubyGems.
#
begin 
  require 'rubygems'
  gem 'ruby-aws'
rescue LoadError
  # Either we don't have RubyGems or we don't have a gem of Ruby/AWS.
end

# Require the essential library, be it via RubyGems or the default way.
#
require 'amazon/aws/search'

include Amazon::AWS
include Amazon::AWS::Search

class AWSTest < Test::Unit::TestCase

  def setup
    @rg = ResponseGroup.new( :Small )
    @req = Request.new
    @req.locale = 'uk'
    @req.cache = false
  end

  undef_method :default_test
 
end
