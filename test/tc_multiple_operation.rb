# $Id: tc_multiple_operation.rb,v 1.1 2008/05/19 10:17:26 ianmacd Exp $
#

require 'test/unit'
require './setup'

class TestMultipleOperation < AWSTest

  def test_item_search
    il = ItemLookup.new( 'ASIN', { 'ItemId' => 'B000AE4QEC',
				   'MerchantId' => 'Amazon' },
				 { 'ItemId' => 'B000051WBE',
				   'MerchantId' => 'Amazon' } )
    is = ItemSearch.new( 'Books', { 'Title' => 'Ruby' } )
    
    mo = MultipleOperation.new( is, il )
    
    response = @req.search( mo, @rg )

    mor = response.multi_operation_response[0]

    # Ensure we received a MultiOperationResponse.
    #
    assert_instance_of( Amazon::AWS::AWSObject::MultiOperationResponse, mor )
    
    # Ensure response contains an ItemSearchResponse.
    #
    assert_instance_of( Amazon::AWS::AWSObject::ItemSearchResponse,
		        mor.item_search_response[0] )

    # Ensure response also contains an ItemLookupResponse.
    #
    assert_instance_of( Amazon::AWS::AWSObject::ItemLookupResponse,
		        mor.item_lookup_response[0] )
 
    is_set = response.multi_operation_response.item_search_response[0].items
    il_set = response.multi_operation_response.item_lookup_response[0].items
    is_arr = is_set.item
    il_arr1 = il_set[0].item
    il_arr2 = il_set[1].item

    # Ensure that there's one <ItemSet> for the ItemSearch.
    #
    assert_equal( 1, is_set.size )

    # Ensure that there are two <ItemSet>s for the ItemLookup, because it was
    # a batched operation.
    #
    assert_equal( 2, il_set.size )

    # Assure that all item sets have some results.
    #
    assert( is_arr.size > 0 )
    assert( il_arr1.size > 0 )
    assert( il_arr2.size > 0 )
  end

end
