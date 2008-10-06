# $Id: tc_item_search.rb,v 1.1 2008/05/19 10:17:26 ianmacd Exp $
#

require 'test/unit'
require './setup'

class TestItemSearch < AWSTest

  def test_item_search
    is = ItemSearch.new( 'Books', { 'Title' => 'Ruby' } )
    response = @req.search( is, @rg )

    results = response.kernel

    # Ensure we got some actual results back.
    #
    assert( results.size > 0 )

  end

end
