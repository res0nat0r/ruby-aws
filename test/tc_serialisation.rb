# $Id: tc_serialisation.rb,v 1.2 2008/06/22 21:18:50 ianmacd Exp $
#

require 'test/unit'
require './setup'
require 'yaml'
require 'tempfile'

class AWSSerialisationTest < AWSTest

  def test_yaml_load

    results_file = Tempfile.new( 'ruby_aws' )

    # Serialise some results.
    #
    is = ItemSearch.new( 'Music', { 'Artist' => 'Voice Of The Beehive' } )
    response = @req.search( is, @rg )
    results = response.kernel

    YAML.dump( results, results_file )
    results = nil

    # Remove knowledge of Amazon::AWS::AWSObject, so that YAML.load knows
    # nothing of its subclasses.
    #
    Amazon::AWS.module_eval( %Q( remove_const :AWSObject ) )

    # Silence warnings about redefined constants.
    #
    v = $VERBOSE
    $VERBOSE = nil

    # Reload Amazon::AWS and friends.
    #
    load 'amazon/aws.rb'

    # Reset warning status.
    #
    $VERBOSE = v

    # Demonstrate that normal YAML.load can't cope with instantiating objects
    # from classes it knows nothing about.
    #
    results_file.open
    results = YAML.load( results_file )
    assert_instance_of( YAML::Object, results[0] )

    # Ensure that AWSObject.yaml_load does the right thing.
    #
    results_file.open
    results = Amazon::AWS::AWSObject.yaml_load( results_file )
    assert_instance_of( Amazon::AWS::AWSObject::Item, results[0] )
  end


  def test_marshal_load

    results_file = Tempfile.new( 'ruby_aws' )

    # Serialise some results.
    #
    is = ItemSearch.new( 'Music', { 'Artist' => 'Voice Of The Beehive' } )
    response = @req.search( is, @rg )
    results = response.kernel

    results_file.puts Marshal.dump( results )
    results = nil

    # Remove knowledge of Amazon::AWS::AWSObject, so that Marshal.load knows
    # nothing of its subclasses.
    #
    Amazon::AWS.module_eval( %Q( remove_const :AWSObject ) )

    # Silence warnings about redefined constants.
    #
    v = $VERBOSE
    $VERBOSE = nil

    # Reload Amazon::AWS and friends.
    #
    load 'amazon/aws.rb'

    # Reset warning status.
    #
    $VERBOSE = v

    # Demonstrate that normal Marshal.load can't cope with instantiating
    # objects from classes it knows nothing about.
    #
    results_file.open

    assert_raise ArgumentError do
      Marshal.load( results_file )
    end

    # Ensure that Amazon::AWS::AWSObject.load does the right thing.
    #
    results_file.open
    results = Amazon::AWS::AWSObject.load( results_file )
    assert_instance_of( Amazon::AWS::AWSObject::Item, results[0] )
  end
end
