# $Id: shoppingcart.rb,v 1.19 2008/09/21 22:17:32 ianmacd Exp $
#

require 'amazon/aws/search'

module Amazon

  module AWS

    # Load this library with:
    #
    #  require 'amazon/aws/shoppingcart'
    #
    module ShoppingCart

      # Attempts to remove non-existent items from a shopping-cart will raise
      # this exception.
      #
      class CartError < Amazon::AWS::Error::AWSError; end

      class Cart < Amazon::AWS::Search::Request

	# _cart_id_ is an alphanumeric token that uniquely identifies a
	# remote shopping-cart. _hmac_ is a <b>H</b>ash <b>M</b>essage
	# <b>A</b>uthentication <b>C</b>ode. This is an encrypted alphanumeric
	# token used to authenticate requests. _purchase_url_ is the URL to
	# follow in order to complete the purchase of the items in the
	# shopping-cart. _cart_items_ is an Array of items in the active area
	# of the cart and _saved_for_later_items_ is an Array of items in the
	# <i>Save For Later</i> area of the cart.
	#
	attr_reader :cart_id, :hmac, :purchase_url, :cart_items,
		    :saved_for_later_items
	alias :items :cart_items
	alias :saved_items :saved_for_later_items
	alias :saved :saved_for_later_items


	# Create a new instance of a remote shopping-cart. See
	# Amazon::AWS::Search::Request.new for details of the parameters.
	#
	# Example:
	#
	#  cart = Cart.new
	#
        def initialize(key_id=nil, associate=nil, locale=nil,
		       user_agent=USER_AGENT)

	  @cart_items = []
	  @saved_for_later_items = []

	  # Note the *false* as the fourth parameter to _super_, because we
	  # never want to cache shopping-cart transactions.
	  #
          super( key_id, associate, locale, false, user_agent )
	end


	# Prepare the remote shopping-cart for use and place one or more items
	# in it.
	#
	# _id_type_ is a String, either *ASIN* or *OfferListingId*. _item_id_
	# is the actual ASIN or offer listing ID in question, _quantity_ is
	# the quantity of the item to add to the cart, and _merge_cart_ is
	# whether or not the remote shopping-cart should be merged with the
	# local cart on the Amazon retail site upon check-out.
	#
	# _more_items_ is an optional list of Hash objects describing
	# additional items to place in the cart.
	#
	# Example:
	#
	#  cart.cart_create( :ASIN, 'B00151HZA6', 1,
	#		     { 'B000WC4AH0' => 2 },
	#		     { 'B000PY32OM' => 3 } )
	#
	# or:
	#
	#  cart.cart_create( :ASIN, 'B00151HZA6', 1,
	#		     { 'B000WC4AH0' => 2,
	#		       'B000PY32OM' => 3 } )
	#
	# Please note that it's not yet possible to update a wishlist at
	# purchase time by referring to the item's *ListItemId* when adding
	# that item to the cart.
	#
        def cart_create(id_type, item_id, quantity=1, merge_cart=false,
		        *more_items)
	  cc = CartCreate.new( id_type, item_id, quantity, merge_cart, nil,
			       *more_items )

	  @rg = ResponseGroup.new( 'Cart' )
          cart = search( cc, @rg ).cart_create_response.cart

	  @cart_id = cart.cart_id
	  @hmac = cart.hmac
	  @purchase_url = cart.purchase_url
	  @cart_items = cart.cart_items.cart_item
	end

	alias :create :cart_create


	# Add one or more new items to the remote shopping-cart. This can not
	# be used to update quantities of items *already* in the cart. For
	# that, you must use Cart#cart_modify instead.
	#
	# _id_type_ is a String, either *ASIN* or *OfferListingId*. _item_id_
	# is the actual ASIN or offer listing ID in question, and _quantity_
	# is the quantity of the item to add to the cart.
	#
	# _more_items_ is an optional list of Hash objects describing
	# additional items to add to the cart.
	#
	# Example:
	#
	#  cart.cart_add( :ASIN, 'B0014C2BL4', 3,
	#		  { 'B00006BCKL' => 2 },
	#		  { 'B000VVE2UW' => 1 } )
	#
	# or:
	#
	#  cart.cart_add( :ASIN, 'B0014C2BL4', 3,
	#		  { 'B00006BCKL' => 2,
	#		    'B000VVE2UW' => 1 } )
	#
	def cart_add(id_type, item_id, quantity=1, *more_items)
	  ca = CartAdd.new( id_type, item_id, quantity, *more_items )
	  ca.params.merge!( { 'CartId' => @cart_id, 'HMAC' => @hmac } )
	  cart = search( ca, @rg ).cart_add_response.cart
	  @cart_items = cart.cart_items.cart_item
	end

	alias :add :cart_add


	# Returns whether or not an item is present in the cart, be it in the
	# active or <i>Save For Later</i> area.
	#
	# _item_id_type_ is the name of the attribute that uniquely identifies
	# an item, such as *ASIN* or *CartItemId*. _item_id_ is the value of
	# the _item_id_type_ for the item whose presence in the cart is being
	# determined.
	#
	# If the item is present in the cart, its _CartItemId_ is returned as a
	# String. Otherwise, *false* is returned.
	#
	# Example:
	#
	#  cart.include?( :ASIN, 'B00151HZA6' )
	#
	def include?(item_id_type, item_id)
	  active?( item_id_type, item_id ) ||
	  saved_for_later?( item_id_type, item_id )
	end

	alias :contain? :include?


	# Returns whether or not an item is present in an area of the cart.
	#
	# _area_ is an array of cart items, _item_id_type_ is the name of the
	# attribute that uniquely identifies an item, such as *ASIN* or
	# *CartItemId* and _item_id_ is the value of the _item_id_type_ for
	# the item whose presence in the cart is being determined.
	#
	# If the item is present in the cart, its _CartItemId_ is returned as a
	# String. Otherwise, *false* is returned.
	#
	# Example:
	#
	#  cart.in_area?( @cart_items, :ASIN, 'B00151HZA6' )
	#
	# or:
	#
	#  cart.in_area?( @saved_for_later_items, :ASIN, 'B00151HZA6' )
	#
	def in_area?(area, item_id_type, item_id)
	  found = area.find do |item|
	    item.send( Amazon.uncamelise( item_id_type.to_s ) ).to_s == item_id
	  end

	  found ? found.cart_item_id.to_s : false
	end
	private :in_area?


	# Returns whether or not an item is present in the active area of the
	# cart.
	#
	# _item_id_type_ is the name of the attribute that uniquely identifies
	# an item, such as *ASIN* or *CartItemId*. _item_id_ is the value of
	# the _item_id_type_ for the item whose presence in the cart is being
	# determined.
	#
	# If the item is present in the cart, its _CartItemId_ is returned as a
	# String. Otherwise, *false* is returned.
	#
	# Example:
	#
	#  cart.active?( :ASIN, 'B00151HZA6' )
	#
	def active?(item_id_type, item_id)
	  in_area?( @cart_items, item_id_type, item_id )
	end


	# Returns whether or not an item is present in the <i>Save For
	# Later</i> area of the cart.
	#
	# _item_id_type_ is the name of the attribute that uniquely identifies
	# an item, such as *ASIN* or *CartItemId*. _item_id_ is the value of
	# the _item_id_type_ for the item whose presence in the cart is being
	# determined.
	#
	# If the item is present in the cart, its _CartItemId_ is returned as a
	# String. Otherwise, *false* is returned.
	#
	# Example:
	#
	#  cart.saved_for_later?( :ASIN, 'B00151HZA6' )
	#
	def saved_for_later?(item_id_type, item_id)
	  in_area?( @saved_for_later_items, item_id_type, item_id )
	end

	alias :saved? :saved_for_later?


	# Modify the quantities of one or more products already in the cart.
	# Changing the quantity of an item to <b>0</b> effectively removes it
	# from the cart.
	#
	# _item_id_type_ is the name of the attribute that uniquely identifies
	# an item in the cart, such as *ASIN* or *CartItemId*. _item_id_ is
	# the value of the _item_id_type_ of the item to be modified, and
	# _quantity_ is its new quantity.
	#
	# _save_for_later_ should be set to *true* if the items in question
	# should be moved to the <i>Save For Later</i> area of the
	# shopping-cart, or *false* if they should be moved to the active
	# area. _save_for_later_ therefore applies to every item specified by
	# _item_id_ and _more_items_. Use *nil* when the location of the items
	# should not be changed.
	#
	# Current Amazon AWS documentation claims that specifying partial
	# quantities can be used to move some copies of an item from one area
	# of the cart to another, whilst leaving the rest in place. In
	# practice, however, this causes an AWS error that explains that a
	# quantity may not be specified in combination with an instruction to
	# move copies from one area of the cart to another. For this reason,
	# when _save_for_later_ is not *nil*, item quantities are currently
	# ignored.
	#
	# _more_items_ is an optional list of Hash objects describing
	# additional items whose quantity should be modified.
	#
	# Example:
	#
	#  cart.cart_modify( :ASIN, 'B00151HZA6', 2, false,
	#		     { 'B0013F2M52' => 1 },
	#		     { 'B000HCPSR6' => 3 } )
	#
	# or:
	#
	#  cart.cart_modify( :ASIN, 'B00151HZA6', 2, true,
	#		     { 'B0013F2M52' => 1,
	#		       'B000HCPSR6' => 3 } )
	#
	def cart_modify(item_id_type, item_id, quantity, save_for_later=nil,
			*more_items)
	  item_quantity1 = quantity

	  unless cart_item_id1 = self.include?( item_id_type, item_id )
	    raise CartError,
	      "Can't find item with '#{item_id_type}' of '#{item_id}' in cart."
	  end

	  more_items.collect! do |extra_item|
	    items = []

	    extra_item.each do |item|
	      item_id, quantity = item
	      unless cart_item_id = self.include?( item_id_type, item_id )
	        raise CartError,
	          "Can't find item with '#{item_id_type}' of '#{item_id}' in cart."
	      end

	      items << { cart_item_id => quantity }
	    end

	    items
	  end

	  more_items.flatten!

	  cm = CartModify.new( cart_item_id1, item_quantity1, save_for_later,
			       *more_items )
	  cm.params.merge!( { 'CartId' => @cart_id, 'HMAC' => @hmac } )
	  cart = search( cm, @rg ).cart_modify_response.cart

	  if ci = cart.cart_items
	    @cart_items = ci.cart_item
	  else
	    @cart_items = []
	  end

	  if sfl = cart.saved_for_later_items
	    @saved_for_later_items = sfl.saved_for_later_item
	  else
	    @saved_for_later_items = []
	  end
	end

	alias :modify :cart_modify


	# Retrieve a remote shopping-cart. This is especially useful when
	# needing to resurrect a cart at a later time, when the Cart object
	# containing the original data no longer exists.
	#
	# _cart_id_ is the unique ID of the cart to be retrieved and _hmac_ is
	# the cart's hash message authentication code. These details can
	# be obtained from an existing cart using the <i>@cart_id</i> and
	# <i>@hmac</i> instance variables.
	#
	# Example:
	#
	#  old_cart = Cart.new
	#  old_cart.get_cart( '203-4219703-7532717',
	#		      'o98sn9Z16JOEF/9eo6OcD8zOZA4=' )
	#
	def cart_get(cart_id, hmac)
	  cg = CartGet.new
	  cg.params.merge!( { 'CartId' => cart_id, 'HMAC' => hmac } )

	  @rg = ResponseGroup.new( 'Cart' )
	  cart = search( cg, @rg ).cart_get_response.cart

	  @cart_id = cart.cart_id
	  @hmac = cart.hmac
	  @purchase_url = cart.purchase_url

	  if ci = cart.cart_items
	    @cart_items = ci.cart_item
	  else
	    @cart_items = []
	  end

	  if sfl = cart.saved_for_later_items
	    @saved_for_later_items = sfl.saved_for_later_item
	  else
	    @saved_for_later_items = []
	  end

	  self
	end

	alias :get :cart_get


	# Remove all items from the shopping-cart.
	#
	# Example:
	#
	#  cart.cart_clear
	#
	def cart_clear
	  cc = CartClear.new
	  cc.params.merge!( { 'CartId' => @cart_id, 'HMAC' => @hmac } )
	  cart = search( cc, @rg ).cart_clear_response.cart
	  @cart_items = []
	  @saved_for_later_items = []
	end

	alias :clear :cart_clear


	include Enumerable

	# Iterator for each item in the cart.
	#
	def each
	  @cart_items.each { |item| yield item }
	end

	alias :each_item :each

      end


      # Worker class used by Cart#cart_create.
      #
      class CartCreate < Operation  # :nodoc:

        # Create a shopping-cart and add item(s) to it.
        #
        def initialize(id_type, item_id, quantity, merge_cart=false,
		       save_for_later=nil, *more_items)

	  # FIXME: Need to deal with ListItemId, too.

	  # Prepend first item to more_items array (which may be empty).
	  #
	  more_items.unshift( { item_id => quantity } )

	  mc = merge_cart ? 'True' : 'False'

	  more_items.collect! do |extra_item|
	    items = []

	    extra_item.each do |item|
	      item_id, quantity = item
	      case save_for_later
	      when true
	        items << { id_type    => item_id,
			   'Action'   => 'SaveForLater' }
	      when false
	        items << { id_type    => item_id,
			   'Action'   => 'MoveToCart' }
	      when nil
	        items << { id_type    => item_id,
			   'Quantity' => quantity }
	      else
		raise CartError,
		  "save_for_later must be true, false or nil, but was #{save_for_later}"
	      end
	    end

	    items
	  end

	  more_items.flatten!

	  # Force batch syntax if only a single item is being put in cart.
	  #
	  params = batch_parameters( {}, *more_items )
	  params.merge!( { 'MergeCart' => mc } ) if merge_cart

          super( params )
        end

      end


      # Worker class used by Cart#cart_add.
      #
      class CartAdd < CartCreate  # :nodoc:

	# Add new item(s) to a cart.
	#
	def initialize(id_type, item_id, quantity, *more_items)
	  super( id_type, item_id, quantity, false, nil, *more_items )
	end

      end


      # Worker class used by Cart#cart_modify.
      #
      class CartModify < CartCreate  # :nodoc:

	# Modify the quantity of item(s) in a cart.
	#
	def initialize(cart_item_id, quantity, save_for_later=false,
		       *more_items)

	  super( 'CartItemId', cart_item_id, quantity, false, save_for_later,
		 *more_items )
	end

      end


      # Worker class used by Cart#cart_clear.
      #
      class CartClear < Operation  # :nodoc:

	# Remove all items from a cart.
	#
	def initialize
	  super( {} )
	end
      
      end


      # Worker class used by Cart#cart_get.
      #
      class CartGet < Operation  # :nodoc:

	# Fetch a cart.
	#
	def initialize
	  super( {} )
	end
      
      end

     end
      
  end
  
end
