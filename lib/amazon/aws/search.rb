# $Id: search.rb,v 1.26 2008/09/21 22:17:32 ianmacd Exp $
#

module Amazon

  module AWS

    require 'amazon/aws'
    require 'net/http'
    require 'rexml/document'

    # Load this library with:
    #
    #  require 'amazon/aws/search'
    #
    module Search

      class Request

	include REXML

	# Exception class for bad access key ID.
	#
	class AccessKeyIdError < Amazon::AWS::Error::AWSError; end

	# Exception class for bad locales.
	#
	class LocaleError < Amazon::AWS::Error::AWSError; end

	attr_reader :conn, :locale, :user_agent
	attr_writer :cache

	# This method is used to generate an AWS search request object.
	#
	# _key_id_ is your AWS {access key
	# ID}[https://aws-portal.amazon.com/gp/aws/developer/registration/index.html],
	# _associate_ is your
	# Associates[http://docs.amazonwebservices.com/AWSECommerceService/2008-04-07/GSG/BecominganAssociate.html]
	# tag (if any), _locale_ is the locale in which you which to work
	# (*us* for amazon.com[http://www.amazon.com/], *uk* for
	# amazon.co.uk[http://www.amazon.co.uk], etc.), _cache_ is whether or
	# not you wish to utilise a response cache, and _user_agent_ is the
	# client name to pass when performing calls to AWS. By default,
	# _user_agent_ will be set to a string identifying the Ruby/AWS
	# library and its version number.
	#
	# _locale_ and _cache_ can also be set later, if you wish to change
	# the current behaviour.
	#
	# Example:
	#
	#  req = Request.new( '0Y44V8FAFNM119CX4TR2', 'calibanorg-20' )
	#
	def initialize(key_id=nil, associate=nil, locale=nil, cache=nil,
		       user_agent=USER_AGENT)

	  @config ||= Amazon::Config.new

	  def_locale = locale
	  locale = 'us' unless locale
	  locale.downcase!

	  key_id ||= @config['key_id']
	  cache = @config['cache'] if cache.nil?

	  # Take locale from config file if no locale was passed to method.
	  #
	  if @config.key?( 'locale' ) && ! def_locale
	    locale = @config['locale']
	  end
	  validate_locale( locale )

	  if key_id.nil?
	    raise AccessKeyIdError, 'key_id may not be nil'
	  end

	  @key_id     = key_id
	  @tag	      = associate || @config['associate'] || DEF_ASSOC[locale]
	  @user_agent = user_agent
	  @cache      = unless cache == 'false' || cache == false
			  Amazon::AWS::Cache.new( @config['cache_dir'] )
			else
			  nil
			end
	  self.locale = locale
	end


	# Assign a new locale. If the locale we're coming from is using the
	# default Associate ID for that locale, then we use the new locale's
	# default ID, too.
	#
	def locale=(l)  # :nodoc:
	  old_locale = @locale ||= nil
	  @locale = validate_locale( l )

	  # Use the new locale's default ID if the ID currently in use is the
	  # current locale's default ID.
	  #
	  if @tag == Amazon::AWS::DEF_ASSOC[old_locale]
	    @tag = Amazon::AWS::DEF_ASSOC[@locale]
	  end

	  # We must now set up a new HTTP connection to the correct server for
	  # this locale, unless the same server is used for both.
	  #
	  unless Amazon::AWS::ENDPOINT[@locale] ==
		 Amazon::AWS::ENDPOINT[old_locale]
	    #connect( @locale )
	    @conn = nil
	  end
	end


	# If @cache has simply been assigned *true* at some point in time,
	# assign a proper cache object to it when it is referenced. Otherwise,
	# just return its value.
	#
	def cache  # :nodoc:
	  if @cache == true
	    @cache = Amazon::AWS::Cache.new( @config['cache_dir'] )
	  else
	    @cache
	  end
	end


	# Verify the validity of a locale string. _l_ is the locale string.
	#
	def validate_locale(l)
	  unless Amazon::AWS::ENDPOINT.has_key? l
	    raise LocaleError, "invalid locale: #{l}"
	  end
	  l
	end
	private :validate_locale


	# Return an HTTP connection for the current _locale_.
	#
	def connect(locale)
	  if ENV.key? 'http_proxy'
	    uri = URI.parse( ENV['http_proxy'] )
	    proxy_user = proxy_pass = nil
	    proxy_user, proxy_pass = uri.userinfo.split( /:/ ) if uri.userinfo
	    @conn = Net::HTTP::Proxy( uri.host, uri.port, proxy_user,
				      proxy_pass ).start(
					Amazon::AWS::ENDPOINT[locale].host )
	  else
	    @conn = Net::HTTP::start( Amazon::AWS::ENDPOINT[locale].host )
	  end
	end
	private :connect


	# Reconnect to the server if our connection has been lost (due to a
	# time-out, etc.).
	#
	def reconnect  # :nodoc:
	  connect( self.locale )
	  self
	end


	# This method checks for errors in an XML response returned by AWS.
	# _xml_ is the XML node below which to search.
	#
	def error_check(xml)
	  if xml = xml.elements['Errors/Error']
	    raise Amazon::AWS::Error.exception( xml )
	  end
	end
	private :error_check


	# Perform a search of the AWS database. _operation_ is one of the
	# objects subclassed from _Operation_, such as _ItemSearch_,
	# _ItemLookup_, etc. It may also be a _MultipleOperation_ object.
	#
	# _response_group_ will apply to all both operations contained in
	# _operation_, if _operation_ is a _MultipleOperation_ object.
	#
	# _nr_pages_ is the number of results pages to return. It defaults to
	# <b>1</b>. If a higher number is given, pages 1 to _nr_pages_ will be
	# returned. If the special value <b>:ALL_PAGES</b> is given, all
	# results pages will be returned.
	#
	# The maximum page number that can be returned for each type of
	# operation is documented in the AWS Developer's Guide:
	#
	# http://docs.amazonwebservices.com/AWSECommerceService/2008-08-19/DG/index.html?CHAP_MakingRequestsandUnderstandingResponses.html#PagingThroughResults
	#
	# Note that _ItemLookup_ operations can use three separate pagination
	# parameters. Ruby/AWS, however, uses _OfferPage_ for the purposes of
	# returning multiple pages.
	#
	# If operation is of class _MultipleOperation_, the operations
	# combined within will return only the first page, regardless of
	# whether a higher number of pages is requested.
	#
	def search(operation, response_group, nr_pages=1)
	  q_params = Amazon::AWS::SERVICE.
		       merge( { 'AWSAccessKeyId' => @key_id,
				'AssociateTag'   => @tag } ).
		       merge( operation.params ).
		       merge( response_group.params )

	  query = Amazon::AWS.assemble_query( q_params )
	  page = Amazon::AWS.get_page( self, query )
	  doc = Document.new( page )

	  # Some errors occur at the very top level of the XML. For example,
	  # when no Operation parameter is given. This should not be possible
	  # with user code, but occurred during debugging of this library.
	  #
	  error_check( doc )

	  # Fundamental errors happen at the OperationRequest level. For
	  # example, if an invalid AWSAccessKeyId is used.
	  #
	  error_check( doc.elements['*/OperationRequest'] )

	  # Check for parameter and value errors deeper down, inside Request.
	  #
	  if operation.kind == 'MultipleOperation'

	    # Everything is a level deeper, because of the
	    # <MultiOperationResponse> container.
	    #
	    # Check for errors in the first operation.
	    #
	    error_check( doc.elements['*/*/*/Request'] )

	    # Check for errors in the second operation.
	    #
	    error_check( doc.elements['*/*[3]/*/Request'] )

	    # If second operation is batched, check for errors in its 2nd set
	    # of results.
	    #
	    if batched = doc.elements['*/*[3]/*[2]/Request']
	      error_check( batched )
	    end
	  else
	    error_check( doc.elements['*/*/Request'] )

	    # If operation is batched, check for errors in its 2nd set of
	    # results.
	    #
	    if batched = doc.elements['*/*[3]/Request']
	      error_check( batched )
	    end
	  end

	  # FIXME: This doesn't work if a MultipleOperation was used, because
	  # <TotalPages> will be nested one level deeper. It's therefore
	  # currently only possible to return the first page of results
	  # for operations combined in a MultipleOperation.
	  #
	  if doc.elements['*/*[2]/TotalPages']
	    total_pages = doc.elements['*/*[2]/TotalPages'].text.to_i
	  else
	    total_pages = 1
	  end

	  # Create a root AWS object and walk the XML response tree.
	  #
	  aws = AWS::AWSObject.new( operation )
	  aws.walk( doc )
	  result = aws

	  # If only one page has been requested or only one page is available,
	  # we can stop here. First yield to the block, if given.
	  #
	  if nr_pages == 1 || ( tp = total_pages ) == 1
	     yield result if block_given?
	     return result
	  end

	  # Limit the number of pages to the maximum number available.
	  #
	  nr_pages = tp.to_i if nr_pages == :ALL_PAGES || nr_pages > tp.to_i

	  if PAGINATION.key? operation.kind
	    page_parameter = PAGINATION[operation.kind]['parameter']
	    max_pages = PAGINATION[operation.kind]['max_page']
	  else
	    page_parameter = 'ItemPage'
	    max_pages = 400
	  end

	  # Iterate over pages 2 and higher, but go no higher than MAX_PAGES.
	  #
	  2.upto( nr_pages < max_pages ? nr_pages : max_pages ) do |page_nr|
	    query = Amazon::AWS.assemble_query(
		      q_params.merge( { page_parameter => page_nr } ) )
	    page = Amazon::AWS.get_page( self, query )
	    doc = Document.new( page )

	    # Check for errors.
	    #
	    error_check( doc.elements['*/OperationRequest'] )
	    error_check( doc.elements['*/*/Request'] )

	    # Create a new AWS object and walk the XML response tree.
	    #
	    aws = AWS::AWSObject.new
	    aws.walk( doc )

	    # When dealing with multiple pages, we return not just an
	    # AWSObject, but an array of them.
	    #
	    result = [ result ] unless result.is_a? Array

	    # Append the new object to the array.
	    #
	    result << aws
	  end

	  # Yield each object to the block, if given.
	  #
	  result.each { |r| yield r } if block_given?

	  result
	end

      end

    end

  end

end
