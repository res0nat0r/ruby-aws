# $Id: aws.rb,v 1.72 2008/10/03 09:37:25 ianmacd Exp $
#
#:include: ../../README.rdoc

module Amazon

  module AWS

    require 'uri'
    require 'amazon'
    require 'amazon/aws/cache'
    require 'rexml/document'

    NAME = '%s/%s' % [ Amazon::NAME, 'AWS' ]
    VERSION = '0.4.4'
    USER_AGENT = '%s %s' % [ NAME, VERSION ]

    # Default Associate tags to use per locale.
    #
    DEF_ASSOC  = {
      'ca' => 'caliban-20',
      'de' => 'calibanorg0a-21',
      'fr' => 'caliban08-21',
      'jp' => 'calibanorg-20',
      'uk' => 'caliban-21',
      'us' => 'calibanorg-20'
    }

    # Service name and version for AWS.
    #
    SERVICE = { 'Service' => 'AWSECommerceService',
		'Version' => '2008-08-19'
    }

    # Maximum number of 301 and 302 HTTP responses to follow, should Amazon
    # later decide to change the location of the service.
    #
    MAX_REDIRECTS = 3

    # Maximum number of results pages that can be retrieved for a given
    # search operation, using whichever pagination parameter is relevant to
    # that type of operation.
    #
    PAGINATION = {
      'ItemSearch'	      => { 'parameter' => 'ItemPage',
						  'max_page' => 400 },
      'ItemLookup'	      => { 'paraneter' => 'OfferPage',
						  'max_page' => 100 },
      'ListLookup'	      => { 'parameter' => 'ProductPage',
						  'max_page' =>  30 },
      'ListSearch'	      => { 'parameter' => 'ListPage',
						  'max_page' =>  20 },
      'CustomerContentLookup' => { 'parameter' => 'ReviewPage',
						  'max_page' =>  10 },
      'CustomerContentSearch' => { 'parameter' => 'CustomerPage',
						  'max_page' =>  20 }
    }
    # N.B. ItemLookup can also use the following two pagination parameters
    #
    #		      max. page
    #		      ---------
    # VariationPage   150
    # ReviewPage       20
	  
    # Exception class for HTTP errors.
    #
    class HTTPError < AmazonError; end

    class Endpoint

      attr_reader :host, :path

      def initialize(endpoint)
	uri = URI.parse( endpoint )
	@host = uri.host
	@path = uri.path
      end
    end

    ENDPOINT = {
      'ca' => Endpoint.new( 'http://ecs.amazonaws.ca/onca/xml' ),
      'de' => Endpoint.new( 'http://ecs.amazonaws.de/onca/xml' ),
      'fr' => Endpoint.new( 'http://ecs.amazonaws.fr/onca/xml' ),
      'jp' => Endpoint.new( 'http://ecs.amazonaws.jp/onca/xml' ),
      'uk' => Endpoint.new( 'http://ecs.amazonaws.co.uk/onca/xml' ),
      'us' => Endpoint.new( 'http://ecs.amazonaws.com/onca/xml' )
    }

    # Fetch a page, either from the cache or by HTTP. This is used internally.
    #
    def AWS.get_page(request, query)  # :nodoc:

      url = ENDPOINT[request.locale].path + query
      cache_url = ENDPOINT[request.locale].host + url

      # Check for cached page and return that if it's there.
      #
      if request.cache && request.cache.cached?( cache_url )
	body = request.cache.fetch( cache_url )
	return body if body
      end

      # Get the existing connection. If there isn't one, force a new one.
      #
      conn = request.conn || request.reconnect.conn
      user_agent = request.user_agent

      Amazon.dprintf( 'Fetching http://%s%s ...', conn.address, url )

      begin
	response = conn.get( url, { 'user-agent' => user_agent } )

      # If we've pulled and processed a lot of pages from the cache (or
      # just not passed by here recently), the HTTP connection to the server
      # will probably have timed out.
      #
      rescue Errno::ECONNRESET
	conn = request.reconnect.conn
	retry
      end

      redirects = 0
      while response.key? 'location'
	if ( redirects += 1 ) > MAX_REDIRECTS
	  raise HTTPError, "More than #{MAX_REDIRECTS} redirections"
	end

	old_url = url
	url = URI.parse( response['location'] )
	url.scheme = old_url.scheme unless url.scheme
	url.host = old_url.host unless url.host
	Amazon.dprintf( 'Following HTTP %s to %s ...', response.code, url )
	response = Net::HTTP::start( url.host ).
		     get( url.path, { 'user-agent' => user_agent } )
      end

      if response.code != '200'
	raise HTTPError, "HTTP response code #{response.code}"
      end

      # Cache the page if we're using a cache.
      #
      if request.cache
	request.cache.store( cache_url, response.body )
      end

      response.body
    end


    def AWS.assemble_query(items)  # :nodoc:
      query = ''

      # We must sort the items into an array to get reproducible ordering
      # of the query parameters. Otherwise, URL caching would not work. We
      # must also convert the keys to strings, in case Symbols have been used
      # as the keys.
      #
      items.sort { |a,b| a.to_s <=> b.to_s }.each do |k, v|
	query << '&%s=%s' % [ k, Amazon.url_encode( v.to_s ) ]
      end

      # Replace initial ampersand with question-mark.
      #
      query[0] = '?'

      query
    end


    # Everything returned by AWS is an AWSObject.
    #
    class AWSObject

      include REXML

      # This method can be used to load AWSObject data previously serialised
      # by Marshal.dump.
      #
      # Example:
      #
      #  File.open( 'aws.dat' ) { |f| Amazon::AWS::AWSObject.load( f ) }
      #
      # Marshal.load cannot be used directly, because subclasses of AWSObject
      # are dynamically defined as needed when AWS XML responses are parsed.
      #
      # Later attempts to load objects instantiated from these classes cause a
      # problem for Marshal, because it knows nothing of classes that were
      # dynamically defined by a separate process.
      #
      def AWSObject.load(io)
	begin
	  Marshal.load( io )
	rescue ArgumentError => ex
	  m = ex.to_s.match( /Amazon::AWS::AWSObject::([^ ]+)/ )
	  const_set( m[1], Class.new( AWSObject ) )

	  io.rewind
	  retry
	end
      end
 

      # This method can be used to load AWSObject data previously serialised
      # by YAML.dump.
      #
      # Example:
      #
      #  File.open( 'aws.yaml' ) { |f| Amazon::AWS::AWSObject.yaml_load( f ) }
      #
      # The standard YAML.load cannot be used directly, because subclasses of
      # AWSObject are dynamically defined as needed when AWS XML responses are
      # parsed.
      #
      # Later attempts to load objects instantiated from these classes cause a
      # problem for YAML, because it knows nothing of classes that were
      # dynamically defined by a separate process.
      #
      def AWSObject.yaml_load(io)
        io.each do |line|
    
	  # File data is external, so it's deemed unsafe when $SAFE > 0, which
	  # is the case with mod_ruby, for example, where $SAFE == 1.
	  #
	  # YAML data isn't eval'ed or anything dangerous like that, so we
	  # consider it safe to untaint it. If we don't, mod_ruby will complain
	  # when Module#const_defined? is invoked a few lines down from here.
	  #
	  line.untaint
	  
	  m = line.match( /Amazon::AWS::AWSObject::([^ ]+)/ )
	  if m
	    cl_name = [ m[1] ]
	  
	    # Module#const_defined? takes 2 parameters in Ruby 1.9.
	    #
	    cl_name << false if Object.method( :const_defined? ).arity == -1
	  
	    unless AWSObject.const_defined?( *cl_name )
	      AWSObject.const_set( m[1], Class.new( AWSObject ) )
	    end
	  
	  end
	end
    
	io.rewind
	YAML.load( io )
      end


      def initialize(op=nil)
	# The name of this instance variable must never clash with the
	# uncamelised name of an Amazon tag.
	#
	# This is used to store the REXML::Text value of an element, which
	# exists only when the element contains no children.
	#
	@__val__ = nil
	@__op__ = op if op
      end


      def method_missing(method, *params)
	iv = '@' + method.id2name

	if instance_variables.include?( iv )
	  instance_variable_get( iv )
	elsif instance_variables.include?( iv.to_sym )

	  # Ruby 1.9 Object#instance_variables method returns Array of Symbol,
	  # not String.
	  #
	  instance_variable_get( iv.to_sym )
	else
	  nil
	end
      end
      private :method_missing
 

      def remove_val
	remove_instance_variable( :@__val__ )
      end
      private :remove_val


      # Iterator method for cycling through an object's properties and values.
      #
      def each  # :yields: property, value
	self.properties.each do |iv|
	  yield iv, instance_variable_get( "@#{iv}" )
	end
      end

      alias :each_property :each


      def inspect  # :nodoc:
	remove_val if instance_variable_defined?( :@__val__ ) && @__val__.nil?
	str = super
	str.sub( /@__val__=/, 'value=' ) if str
      end


      def to_s	# :nodoc:
	if instance_variable_defined?( :@__val__ )
	  return @__val__ if @__val__.is_a?( String )
	  remove_val
	end

	string = ''

	# Assemble the object's details.
	#
	each { |iv, value| string << "%s = %s\n" % [ iv, value ] }

	string
      end

      alias :to_str :to_s


      def to_i	# :nodoc:
	@__val__.to_i
      end


      def ==(other)  # :nodoc:
        @__val__.to_s == other
      end


      def =~(other)  # :nodoc:
	@__val__.to_s =~ other
      end


      # This alias makes the ability to determine an AWSObject's properties a
      # little more intuitive. It's pretty much just an alias for the
      # inherited <em>Object#instance_variables</em> method, with a little
      # tidying.
      #
      def properties
	# Make sure we remove the leading @.
	#
	iv = instance_variables.collect { |v| v = v[1..-1] }
	iv.delete( '__val__' )
	iv
      end


      # Provide a shortcut down to the data likely to be of most interest.
      # This method is experimental and may be removed.
      #
      def kernel  # :nodoc: 
	# E.g. Amazon::AWS::SellerListingLookup -> seller_listing_lookup
	#
	stub = Amazon.uncamelise( @__op__.class.to_s.sub( /^.+::/, '' ) )

	# E.g. seller_listing_response
	#
	level1 = stub + '_response'

	# E.g. seller_listing
	#
	level3 = stub.sub( /_[^_]+$/, '' )

	# E.g. seller_listings
	#
	level2 = level3 + 's'

	# E.g.
	# seller_listing_search_response[0].seller_listings[0].seller_listing
	#
	self.instance_variable_get( "@#{level1}" )[0].
	     instance_variable_get( "@#{level2}" )[0].
	     instance_variable_get( "@#{level3}" )
      end


      # Convert an AWSObject to a Hash.
      #
      def to_h
	hash = {}

	each do |iv, value|
	  if value.is_a? AWSObject
	    hash[iv] = value.to_h
	  elsif value.is_a?( AWSArray ) && value.size == 1
	    hash[iv] = value[0]
	  else
	    hash[iv] = value
	  end
	end

	hash
      end


      # Fake the appearance of an AWSObject as a hash. _key_ should be any
      # attribute of the object and can be a String, Symbol or anything else
      # that can be converted to a String with to_s.
      #
      def [](key)
	instance_variable_get( "@#{key}" )
      end


      # Recursively walk through an XML tree, starting from _node_. This is
      # called internally and is not intended for user code.
      #
      def walk(node)  # :nodoc:
    
	if node.instance_of?( REXML::Document )
	  walk( node.root )
    
	elsif node.instance_of?( REXML::Element )
	  name = Amazon.uncamelise( node.name )
    
	  cl_name = [ node.name ]

	  # Module#const_defined? takes 2 parameters in Ruby 1.9.
	  #
	  cl_name << false if Object.method( :const_defined? ).arity == -1

	  # Create a class for the new element type unless it already exists.
	  #
	  unless AWS::AWSObject.const_defined?( *cl_name )
	    cl = AWS::AWSObject.const_set( node.name, Class.new( AWSObject ) )

	    # Give it an accessor for @attrib.
	    #
	    cl.send( :attr_accessor, :attrib )
	  end
    
	  # Instantiate an object in the newly created class.
	  #
	  obj = AWS::AWSObject.const_get( node.name ).new

	  sym_name = "@#{name}".to_sym
    
	  if instance_variable_defined?( sym_name)
    	    instance_variable_set( sym_name,
    	      instance_variable_get( sym_name ) << obj )
	  else
	    instance_variable_set( sym_name, AWSArray.new( [ obj ] ) )
	  end
    
	  if node.has_attributes?
	    obj.attrib = {}
	    node.attributes.each_pair do |a_name, a_value|
	      obj.attrib[a_name.downcase] =
		a_value.to_s.sub( /^#{a_name}=/, '' )
	    end
	  end

	  node.children.each { |child| obj.walk( child ) }
    
	else # REXML::Text
	  @__val__ = node.to_s
	end
      end


      # For objects of class AWSObject::.*Image, fetch the image in question,
      # optionally overlaying a discount icon for the percentage amount of
      # _discount_ to the image.
      #
      def get(discount=nil)
	if self.class.to_s =~ /Image$/ && @url
          url = URI.parse( @url[0] )
          url.path.sub!( /(\.\d\d\._)/, "\\1PE#{discount}" ) if discount

	  # FIXME: All HTTP in Ruby/AWS should go through the same method.
	  #
          Net::HTTP.start( url.host, url.port ) do |http|
	    http.get( url.path )
	  end.body

	else
	  nil
	end
      end

    end


    # Everything we get back from AWS is transformed into an array. Many of
    # these, however, have only one element, because the corresponding XML
    # consists of a parent element containing only a single child element.
    #
    # This class consists solely to allow single element arrays to pass a
    # method call down to their one element, thus obviating the need for lots
    # of references to <tt>foo[0]</tt> in user code.
    #
    # For example, the following:
    #
    #  items = resp.item_search_response[0].items[0].item
    #
    # can be reduced to:
    #
    #  items = resp.item_search_response.items.item
    #
    class AWSArray < Array

      def method_missing(method, *params)
	self.size == 1 ? self[0].send( method, *params ) : super
      end
      private :method_missing


      # In the case of a single-element array, return the first element,
      # converted to a String.
      #
      def to_s  # :nodoc:
	self.size == 1 ? self[0].to_s : super
      end

      alias :to_str :to_s


      # In the case of a single-element array, return the first element,
      # converted to an Integer.
      #
      def to_i  # :nodoc:
	self.size == 1 ? self[0].to_i : super
      end


      # In the case of a single-element array, compare the first element with
      # _other_.
      #
      def ==(other)  # :nodoc:
	self.size == 1 ? self[0].to_s == other : super
      end


      # In the case of a single-element array, perform a pattern match on the
      # first element against _other_.
      #
      def =~(other)  # :nodoc:
	self.size == 1 ? self[0].to_s =~ other : super
      end

    end

 
    # This is the base class of all AWS operations.
    #
    class Operation

      # These are the types of AWS operation currently implemented by Ruby/AWS.
      #
      OPERATIONS = %w[
	BrowseNodeLookup      CustomerContentLookup   CustomerContentSearch
	Help		      ItemLookup	      ItemSearch
	ListLookup	      ListSearch	      SellerListingLookup
	SellerListingSearch   SellerLookup	      SimilarityLookup
	TagLookup	      TransactionLookup

	CartAdd		      CartClear		      CartCreate
	CartGet		      CartModify
      ]

      # These are the valid search parameters that can be used with
      # ItemSearch.
      #
      PARAMETERS = %w[
	Actor		Artist	      AudienceRating	Author
	Brand		BrowseNode    City Composer	Conductor
	Director	Keywords      Manufacturer	MusicLabel
	Neighborhood	Orchestra     Power		Publisher
	TextStream	Title
      ]

      OPT_PARAMETERS = %w[
	Availability	Condition     MaximumPrice	MerchantId
	MinimumPrice	OfferStatus   Sort
      ]

      ALL_PARAMETERS = PARAMETERS + OPT_PARAMETERS

      attr_reader :kind
      attr_accessor :params

      def initialize(parameters)

	op_kind = self.class.to_s.sub( /^.*::/, '' )
	unless OPERATIONS.include?( op_kind ) || op_kind == 'MultipleOperation'
	  raise "Bad operation: #{op_kind}"
	end
	#raise 'Too many parameters' if parameters.size > 10

	@kind = op_kind
	@params = { 'Operation' => op_kind }.merge( parameters )
      end


      # Convert parameters to batch format, e.g. ItemSearch.1.Title.
      #
      def batch_parameters(params, *b_params)  # :nodoc:

	@index ||= 1

	unless b_params.empty?
	  op_str = self.class.to_s.sub( /^.+::/, '' )

	  # Fudge the operation string if we're dealing with a shopping cart.
	  #
	  op_str = 'Item' if op_str =~ /^Cart/

	  all_parameters = [ params ].concat( b_params )
	  params = {}

	  all_parameters.each_with_index do |hash, index|

	    # Don't batch an already batched hash.
	    #
	    if ! hash.empty? && hash.to_a[0][0] =~ /^.+\..+\..+$/
	      params = hash
	      next
	    end

	    hash.each do |tag, val|
	      shared_param = '%s.%d.%s' % [ op_str, @index + index, tag ]
	      params[shared_param] = val
	    end
	  end

	  @index += b_params.size

	end

	params
      end


      def parameter_check(parameters)
	parameters.each_key do |key|
	  raise "Bad parameter: #{key}" unless ALL_PARAMETERS.include? key.to_s
	end
      end
      private :parameter_check

    end


    # This class can be used to merge operations into a single operation.
    # AWS currently supports combining two operations, 
    #
    class MultipleOperation < Operation

      # This will allow you to take two Operation objects and combine them to
      # form a single object, which can then be used to perform searches. AWS
      # itself imposes the maximum of two combined operations.
      #
      # <em>operation1</em> and <em>operation2</em> are both objects from a
      # subclass of Operation, such as ItemSearch, ItemLookup, etc.
      #
      # There are currently a few restrictions in the Ruby/AWS implementation
      # of multiple operations:
      #
      # - ResponseGroup objects used when calling AWS::Search::Request#search
      #   apply to both operations. You cannot have a separate ResponseGroup
      #   set per operation.
      #
      # - One or both operations may have multiple results pages available,
      #   but only the first page can be returned. If you need the other
      #   pages, perform the operations separately, not as part of a
      #   MultipleOperation.
      #
      # Example:
      #
      #  is = ItemSearch.new( 'Books', { 'Title' => 'Ruby' } )
      #  il = ItemLookup.new( 'ASIN', { 'ItemId' => 'B0013DZAYO',
      #					'MerchantId' => 'Amazon' } )
      #	 mo = MultipleOperation.new( is, il )
      #
      #	In the above example, we compose a multiple operation consisting of an
      #	ItemSearch and an ItemLookup.
      # 
      def initialize(operation1, operation2)

	# Safeguard against changing original Operation objects in place. This
	# is to protect me, not for user code.
	#
	operation1.freeze
	operation2.freeze

	op_kind = '%s,%s' % [ operation1.kind, operation2.kind ]

	# Duplicate Operation objects and remove their Operation parameter.
	# 
	op1 = operation1.dup
	op1.params = op1.params.dup
	op1.params.delete( 'Operation' )

	op2 = operation2.dup
	op2.params = op2.params.dup
	op2.params.delete( 'Operation' )

	if op1.class == op2.class

	  # If both operations are of the same type, we combine the parameters
	  # of both.
	  #
	  b_params = op1.batch_parameters( op1.params, op2.params )
	else

	  # We have to convert the parameters to batch format.
	  #
	  bp1 = op1.batch_parameters( op1.params, {} )
	  bp2 = op2.batch_parameters( op2.params, {} )
	  b_params = bp1.merge( bp2 )
	end

	params = { 'Operation' => op_kind }.merge( b_params )
	super( params )

      end
      
    end


    # This class of operation aids in finding out about AWS operations and
    # response groups.
    #
    class Help < Operation

      # Return information on AWS operations and response groups.
      #
      # For operations, required and optional parameters are returned, along
      # with information about which response groups the operation can use.
      #
      # For response groups, The list of operations that can use that group is
      # returned, as well as the list of response tags returned by the group.
      #
      # _help_type_ is the type of object for which help is being sought, such
      # as *Operation* or *ResponseGroup*. _about_ is the name of the
      # operation or response group you need help with, and _parameters_ is a
      # hash of parameters that serve to further refine the request for help.
      #
      def initialize(help_type, about, parameters={})
	super( { 'HelpType' => help_type,
		 'About'    => about
	       }.merge( parameters ) )
      end

    end


    # This is the class for the most common type of AWS look-up, an
    # ItemSearch. This allows you to search for items that match a set of
    # broad criteria. It returns items for sale by Amazon merchants and most
    # types of seller.
    #
    class ItemSearch < Operation

      # Not all search indices work in all locales. It is the user's
      # responsibility to ensure that a given index is valid within a given
      # locale.
      #
      # According to the AWS documentation:
      #
      # - *All* searches through all indices (but currently exists only in the
      #   *US* locale).
      # - *Blended* combines DVD, Electronics, Toys, VideoGames, PCHardware,
      #   Tools, SportingGoods, Books, Software, Music, GourmetFood, Kitchen
      #   and Apparel.
      # - *Merchants* combines all search indices for a merchant given with
      #   MerchantId.
      # - *Music* combines the Classical, DigitalMusic, and MusicTracks
      #   indices.
      # - *Video* combines the DVD and VHS search indices.
      #
      SEARCH_INDICES = %w[
	    All
	    Apparel		Hobbies		    PetSupplies
	    Automotive		HomeGarden	    Photo
	    Baby		Jewelry		    Software
	    Beauty		Kitchen		    SoftwareVideoGames
	    Blended		Magazines	    SportingGoods
	    Books		Merchants	    Tools
	    Classical		Miscellaneous	    Toys
	    DigitalMusic	Music		    VHS
	    DVD			MusicalInstruments  Video
	    Electronics		MusicTracks	    VideoGames
	    ForeignBooks	OfficeProducts      Wireless
	    GourmetFood		OutdoorLiving	    WirelessAccessories
	    HealthPersonalCare  PCHardware
	]


      # Search AWS for items. _search_index_ must be one of _SEARCH_INDICES_
      # and _parameters_ is a hash of relevant search parameters.
      #
      # Example:
      #
      #  is = ItemSearch.new( 'Books', { 'Title' => 'ruby programming' } )
      #
      # In the above example, we search for books with <b>Ruby Programming</b>
      # in the title.
      #
      def initialize(search_index, parameters)
	unless SEARCH_INDICES.include? search_index.to_s
	  raise "Invalid search index: #{search_index}"
	end

	parameter_check( parameters )
	super( { 'SearchIndex' => search_index }.merge( parameters ) )
      end

    end


    # This class of look-up deals with searching for *specific* items by some
    # uniquely identifying attribute, such as the ASIN (*A*mazon *S*tandard
    # *I*tem *N*umber).
    #
    class ItemLookup < Operation

      # Look up a specific item in the AWS catalogue. _id_type_ is the type of
      # identifier, _parameters_ is a hash that identifies the item to be
      # located and narrows the scope of the search, and _b_parameters_ is an
      # optional hash of further items to be located. Use of _b_parameters_
      # effectively results in a batch operation being sent to AWS.
      #
      # Example:
      #
      #  il = ItemLookup.new( 'ASIN', { 'ItemId' => 'B000AE4QEC'
      #					'MerchantId' => 'Amazon' },
      #				      { 'ItemId' => 'B000051WBE',
      #					'MerchantId' => 'Amazon' } )
      #
      # In the above example, we search for two items, based on their ASIN.
      # The use of _MerchantId_ restricts the offers returned to those for
      # sale by Amazon (as opposed to third-party sellers).
      #
      def initialize(id_type, parameters, *b_parameters)

	id_type_str = 'IdType'

	unless b_parameters.empty?
	  class_str = self.class.to_s.sub( /^.+::/, '' )
	  id_type_str = '%s.Shared.IdType' % [ class_str ]
	  parameters = batch_parameters( parameters, *b_parameters )
	end

	super( { id_type_str => id_type }.merge( parameters ) )
      end

    end


    # Search for items for sale by a particular seller.
    #
    class SellerListingSearch < Operation

      # Search for items for sale by a particular seller. _seller_id_ is the
      # Amazon seller ID and _parameters_ is a hash of parameters that narrows
      # the scope of the search.
      #
      # Example:
      #
      #  sls = SellerListingSearch.new( 'A33J388YD2MWJZ',
      #					{ 'Keywords' => 'Killing Joke' } )
      #
      # In the above example, we search seller <b>A33J388YD2MWJ</b>'s listings
      # for items with the keywords <b>Killing Joke</b>.
      #
      def initialize(seller_id, parameters)
	super( { 'SellerId' => seller_id }.merge( parameters ) )
      end

    end


    # Return specified items in a seller's store.
    #
    class SellerListingLookup < ItemLookup

      # Look up a specific item for sale by a specific seller. _id_type_ is
      # the type of identifier, _parameters_ is a hash that identifies the
      # item to be located and narrows the scope of the search, and
      # _b_parameters_ is an optional hash of further items to be located. Use
      # of _b_parameters_ effectively results in a batch operation being sent
      # to AWS.
      #
      # Example:
      #
      #  sll = SellerListingLookup.new( 'AP8U6Y3PYQ9VO', 'ASIN',
      #					{ 'Id' => 'B0009RRRC8' } )
      #
      # In the above example, we search seller <b>AP8U6Y3PYQ9VO</b>'s listings
      # to find items for sale with the ASIN <b>B0009RRRC8</b>.
      #
      def initialize(seller_id, id_type, parameters, *b_parameters)
	super( id_type, { 'SellerId' => seller_id }.merge( parameters ),
	       b_parameters )
      end

    end


    # Return information about a specific seller.
    #
    class SellerLookup < Operation

      # Search for the details of a specific seller. _seller_id_ is the Amazon
      # ID of the seller in question and _parameters_ is a hash of parameters
      # that serve to further refine the search.
      #
      # Example:
      #
      #  sl = SellerLookup.new( 'A3QFR0K2KCB7EG' )
      #
      # In the above example, we look up the details of the seller with ID
      # <b>A3QFR0K2KCB7EG</b>.
      #
      def initialize(seller_id, parameters={})
	super( { 'SellerId' => seller_id }.merge( parameters ) )
      end

    end


    # Obtain the information an Amazon customer has made public about
    # themselves.
    #
    class CustomerContentLookup < Operation

      # Search for public customer data. _customer_id_ is the unique ID
      # identifying the customer on Amazon and _parameters_ is a hash of
      # parameters that serve to further refine the search.
      #
      # Example:
      #
      #  ccl = CustomerContentLookup.new( 'AJDWXANG1SYZP' )
      #
      # In the above example, we look up public data about the customer with
      # the ID <b>AJDWXANG1SYZP</b>.
      #
      def initialize(customer_id, parameters={})
	super( { 'CustomerId' => customer_id }.merge( parameters ) )
      end

    end


    # Retrieve basic Amazon customer data.
    #
    class CustomerContentSearch < Operation

      # Retrieve customer information, using an e-mail address or name.
      #
      # If _customer_id_ contains an '@' sign, it is assumed to be an e-mail
      # address. Otherwise, it is assumed to be the customer's name.
      #
      # Example:
      #
      #  ccs = CustomerContentSearch.new( 'ian@caliban.org' )
      #
      # In the above example, we look up customer information about
      # <b>ian@caliban.org</b>. The *CustomerInfo* response group will return,
      # amongst other things, a _customer_id_ property, which can then be
      # plugged into CustomerContentLookup to retrieve more detailed customer
      # information.
      #
      def initialize(customer_id)
	id = customer_id =~ /@/ ? 'Email' : 'Name'
	super( { id => customer_id } )
      end

    end


    # Find wishlists, registry lists, etc. created by users and placed on
    # Amazon. These are items that customers would like to receive as
    # presnets.
    #
    class ListSearch < Operation

      # Search for Amazon lists. _list_type_ is the type of list to search for
      # and _parameters_ is a hash of parameters that narrows the scope of the
      # search.
      #
      # Example:
      #
      #  ls = ListSearch.new( 'WishList', { 'Name' => 'Peter Duff' }
      #
      # In the above example, we retrieve the wishlist for the Amazon user,
      # <b>Peter Duff</b>.
      #
      def initialize(list_type, parameters)
	super( { 'ListType' => list_type }.merge( parameters ) )
      end

    end


    # Find the details of specific wishlists, registries, etc.
    #
    class ListLookup < Operation

      # Look up and return details about a specific list. _list_id_ is the
      # Amazon list ID, _list_type_ is the type of list and _parameters_ is a
      # hash of parameters that narrows the scope of the search.
      #
      # Example:
      #
      #  ll = ListLookup.new( '3P722DU4KUPCP', 'Listmania' )
      #
      # In the above example, a *Listmania* list with the ID
      # <b>3P722DU4KUPCP</b> is retrieved from AWS.
      #
      def initialize(list_id, list_type, parameters={})
        super( { 'ListId'   => list_id,
	         'ListType' => list_type
	       }.merge( parameters ) )
      end

    end


    # Amazon use browse nodes as a means of organising the millions of items
    # in their inventory. An example might be *Carving Knives*. Looking up a
    # browse node enables you to determine that group's ancestors and
    # descendants.
    #
    class BrowseNodeLookup < Operation

      # Look up and return the details of an Amazon browse node. _node_ is the
      # browse node to look up and _parameters_ is a hash of parameters that
      # serves to further define the search. _parameters_ is currently unused.
      #
      # Example:
      #
      #  bnl = BrowseNodeLookup.new( '11232', {} )
      #
      # In the above example, we look up the browse node with the ID
      # <b>11232</b>. This is the <b>Social Sciences</b> browse node.
      #
      def initialize(node, parameters={})
	super( { 'BrowseNodeId' => node }.merge( parameters ) )
      end

    end


    # Similarity look-up is for items similar to others.
    #
    class SimilarityLookup < Operation

      # Look up items similar to _asin_, which can be a single item or an
      # array. _parameters_ is a hash of parameters that serve to further
      # refine the search.
      #
      # Example:
      #
      #  sl = SimilarityLookup.new( 'B000051WBE' )
      #
      # In the above example, we search for items similar to the one with ASIN
      # <b>B000051WBE</b>.
      #
      def initialize(asin, parameters={})
	super( { 'ItemId' => asin.to_a.join( ',' ) }.merge( parameters ) )
      end

    end


    # Search for entities based on user-defined tags. A tag is a descriptive
    # word that a customer uses to label entities on Amazon's Web site.
    # Entities can be items for sale, Listmania lists, guides, etc.
    #
    class TagLookup < Operation

      # Look up entities based on user-defined tags. _tag_name_ is the tag to
      # search on and _parameters_ is a hash of parameters that serve to
      # further refine the search.
      #
      # Example:
      #
      #  tl = TagLookup.new( 'Awful' )
      #
      # In the example above, we search for entities tagged by users with the
      # word *Awful*.
      #
      def initialize(tag_name, parameters={})
	super( { 'TagName' => tag_name }.merge( parameters ) )
      end

    end


    # Search for information on previously completed purchases.
    #
    class TransactionLookup < Operation

      # Return information on an already completed purchase. _transaction_id_
      # is actually the order number that is created when you place an order
      # on Amazon.
      #
      # Example:
      #
      #  tl = TransactionLookup.new( '103-5663398-5028241' )
      #
      # In the above example, we retrieve the details of order number
      # <b>103-5663398-5028241</b>.
      #
      def initialize(transaction_id)
	super( { 'TransactionId' => transaction_id } )
      end

    end


    # Response groups determine which data pertaining to the item(s) being
    # sought is returned. They can strongly influence the amount of data
    # returned, so you should always use the smallest response group(s)
    # containing the data of interest to you, to avoid masses of unnecessary
    # data being returned.
    #
    class ResponseGroup

      attr_reader :list, :params

      # Define a set of one or more response groups to be applied to items
      # retrieved by an AWS operation.
      #
      # If no response groups are given in _rg_ when instantiating an object,
      # *Small* will be used by default.
      #
      # Example:
      #
      #  rg = ResponseGroup.new( 'Medium', 'Offers', 'Reviews' )
      #
      def initialize(*rg)
	rg << 'Small' if rg.empty?
	@list = rg
	@params = { 'ResponseGroup' => @list.join( ',' ) }
      end

    end


    # All dynamically generated exceptions occur within this namespace.
    #
    module Error

      # The base exception class for errors that result from AWS operations.
      # Classes for these are dynamically generated as subclasses of this one.
      #
      class AWSError < AmazonError; end

      def Error.exception(xml)
        err_class = xml.elements['Code'].text.sub( /^AWS.*\./, '' )
        err_msg = xml.elements['Message'].text

	# Dynamically define a new exception class for this class of error,
	# unless it already exists.
	#
	unless Amazon::AWS::Error.const_defined?( err_class )
	  Amazon::AWS::Error.const_set( err_class, Class.new( AWSError ) )
	end

	# Generate and return a new exception from the relevant class.
	#
	Amazon::AWS::Error.const_get( err_class ).new( err_msg )
      end

    end

  end

end
