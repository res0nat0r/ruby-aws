# $Id: tc_shopping_cart.rb,v 1.5 2008/07/05 14:18:03 ianmacd Exp $
#

require 'test/unit'
require './setup'
require 'amazon/aws/shoppingcart'

include Amazon::AWS::ShoppingCart

class TestShoppingCart < AWSTest

  def test_shopping_cart1
    cart = Cart.new
    cart.locale = 'uk'

    # Check that initial quantities are zero.
    #
    items = cart.items
    sfl_items = cart.saved_for_later_items
    assert_equal( 0, items.size )
    assert_equal( 0, sfl_items.size )

    # Create a cart with three items. The last two are given as multiple
    # single-element hashes. MergeCart is false.
    #
    cart.cart_create( :ASIN, 'B00151HZA6', 3, false,
		      { 'B000WC4AH0' => 2 },
		      { 'B0006L16N8' => 1 } )
    items = cart.items

    # Check that the quantities match what we expect.
    #
    assert_equal( 3, items.size )
    item = items.find { |item| item.asin == 'B00151HZA6'  }
    assert_equal( '3', item.quantity[0] )
    item = items.find { |item| item.asin == 'B000WC4AH0'  }
    assert_equal( '2', item.quantity[0] )
    item = items.find { |item| item.asin == 'B0006L16N8'  }
    assert_equal( '1', item.quantity[0] )

    # Check purchase URL.
    #

    # Check for correct Cart Id.
    #
    assert_match( /cart-id=#{cart.cart_id}/,
		  cart.purchase_url,
		  'Cart Id incorrect' )
 
    # Check for correct value of MergeCart.
    #
    assert_match( /MergeCart=False/,
		  cart.purchase_url,
		  'MergeCart is not False' )

    # Clear cart.
    #
    cart.cart_clear

    # Ensure that clearing the cart actually empties it.
    #
    assert_equal( 0, cart.cart_items.size )
  end

  def test_shopping_cart2
    cart = Cart.new
    cart.locale = 'uk'

    # Create a cart with three items. The last two are given in a single
    # hash. MergeCart is true. Cart#create is used as an alias of
    # Cart#cart_create.
    #
    cart.create( :ASIN, 'B00151HZA6', 1, true,
		 { 'B000WC4AH0' => 2,
		   'B0006L16N8' => 3 } )
    items = cart.items

    # Check that the quantities match what we expect.
    #
    assert_equal( 3, items.size )
    item = items.find { |item| item.asin == 'B00151HZA6'  }
    assert_equal( '1', item.quantity[0] )
    item = items.find { |item| item.asin == 'B000WC4AH0'  }
    assert_equal( '2', item.quantity[0] )
    item = items.find { |item| item.asin == 'B0006L16N8'  }
    assert_equal( '3', item.quantity[0] )

    # Check purchase URL.
    #

    # Check for correct Cart Id.
    #
    assert_match( /cart-id=#{cart.cart_id}/,
		  cart.purchase_url,
		  'Cart Id incorrect' )

    # Check for correct value of MergeCart.
    #
    assert_match( /MergeCart=True/,
		  cart.purchase_url,
		  'MergeCart is not True' )

    # Add some items.
    #
    cart.cart_add( :ASIN, 'B0014C2BL4', 1,
		   { 'B00006BCKL' => 1,
		     'B0001XLXYI' => 4 },
		   { 'B0013F2M52' => 3,
		     'B000HCPSR6' => 2 } )

    # Check that the quantities match what we expect.
    #
    items = cart.items
    assert_equal( 8, items.size )
    item = items.find { |item| item.asin == 'B0014C2BL4'  }
    assert_equal( '1', item.quantity[0] )
    item = items.find { |item| item.asin == 'B00006BCKL'  }
    assert_equal( '1', item.quantity[0] )
    item = items.find { |item| item.asin == 'B0001XLXYI'  }
    assert_equal( '4', item.quantity[0] )
    item = items.find { |item| item.asin == 'B0013F2M52'  }
    assert_equal( '3', item.quantity[0] )
    item = items.find { |item| item.asin == 'B000HCPSR6'  }
    assert_equal( '2', item.quantity[0] )

    # Modify an item quantity.
    #
    cart.cart_modify( :ASIN, 'B00151HZA6', 2 )
    items = cart.items
    assert_equal( 8, items.size )
    item = items.find { |item| item.asin == 'B00151HZA6'  }
    assert_equal( '2', item.quantity[0] )

    # Move item to 'Save For Later' area.
    #
    cart.cart_modify( :ASIN, 'B0014C2BL4', 1, true )
    sfl_items = cart.saved_for_later_items
    assert_equal( 1, sfl_items.size )
    item = sfl_items.find { |item| item.asin == 'B0014C2BL4'  }
    assert_equal( '1', item.quantity[0] )
    items = cart.items
    assert_equal( 7, items.size )
    assert( ! cart.active?( :ASIN, 'B0014C2BL4' ) )

    # Move item back to 'Active' area.
    #
    cart.cart_modify( :ASIN, 'B0014C2BL4', 1, false )
    items = cart.items
    assert_equal( 8, items.size )
    item = items.find { |item| item.asin == 'B0014C2BL4'  }
    assert_equal( '1', item.quantity[0] )
    sfl_items = cart.saved_for_later_items
    assert_equal( 0, sfl_items.size )
    assert( ! cart.saved_for_later?( :ASIN, 'B0014C2BL4' ) )

    # Remove an item.
    #
    cart.cart_modify( :ASIN, 'B0014C2BL4', 0 )

    # Check that the number of items in the cart has been reduced by one.
    #
    items = cart.items
    assert_equal( 7, items.size )

    # Check that the item is no longer in the cart.
    #
    assert( ! cart.include?( :ASIN, 'B0014C2BL4' ) )

    # Check that modifying non-existent item raises exception.
    #
    assert_raise( Amazon::AWS::ShoppingCart::CartError ) do
      cart.cart_modify( :ASIN, 'B0014C2BL4', 1 )
    end

    # Move another item to the 'Save For Later' area.
    #
    cart.cart_modify( :ASIN, 'B00151HZA6', 2, true )
    items = cart.items
    assert_equal( 6, items.size )
    sfl_items = cart.saved_for_later_items
    assert_equal( 1, sfl_items.size )

    # Now remove that item while it's still in the 'Save For Later' area.
    #
    cart.cart_modify( :ASIN, 'B00151HZA6', 0 )
    items = cart.items
    assert_equal( 6, items.size )
    sfl_items = cart.saved_for_later_items
    assert_equal( 0, sfl_items.size )

    # Ensure that the item is no longer in either area of the cart.
    #
    assert( ! cart.include?( :ASIN, 'B0014C2BL4' ) )
    assert( ! cart.active?( :ASIN, 'B0014C2BL4' ) )
    assert( ! cart.saved_for_later?( :ASIN, 'B0014C2BL4' ) )

    # Check that modifying non-existent item raises exception.
    #
    assert_raise( Amazon::AWS::ShoppingCart::CartError ) do
      cart.cart_modify( :ASIN, 'B00151HZA6', 1 )
    end

    # Check that retrieving the cart at a later time works properly.
    #
    old_cart = cart
    cart = Cart.new
    cart.locale = 'uk'
    cart.cart_get( old_cart.cart_id, old_cart.hmac )
    assert_equal( old_cart.cart_id, cart.cart_id )
    assert_equal( old_cart.hmac, cart.hmac )
    assert_equal( old_cart.items, cart.items )
  end

end
