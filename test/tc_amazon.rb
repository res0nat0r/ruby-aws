# $Id: tc_amazon.rb,v 1.1 2008/05/19 10:17:26 ianmacd Exp $
#

require 'test/unit'
require './setup'

class TestAmazonBasics < AWSTest

  def test_uncamelise
    str = 'ALongStringWithACRONYM'
    uncamel_str = 'a_long_string_with_acronym'

    # Ensure uncamelisation of strings occurs properly.
    #
    assert_equal( uncamel_str, Amazon::uncamelise( str ) )
    assert_equal( 'asin', Amazon::uncamelise( 'ASIN' ) )

  end

end
