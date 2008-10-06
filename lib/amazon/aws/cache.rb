# $Id: cache.rb,v 1.8 2008/06/10 06:33:46 ianmacd Exp $
#

module Amazon

  module AWS

    # This class provides a simple results caching system for operations
    # performed by AWS.
    #
    # To use it, set _cache_ to *true* in either <tt>/etc/amazonrc</tt> or
    # <tt>~/.amazonrc</tt>.
    #
    # By default, the cache directory used is <tt>/tmp/amazon</tt>, but this
    # can be changed by defining _cache_dir_ in either <tt>/etc/amazonrc</tt>
    # or <tt>~/.amazonrc</tt>.
    #
    # When a cache is used, Ruby/AWS will check the cache directory for a
    # recent copy of a response to the exact operation that you are
    # performing. If found, the cached response will be returned instead of
    # the request being forwarded to the AWS servers for processing. If no
    # (recent) copy is found, the request will be forwarded to the AWS servers
    # as usual. Recency is defined here as less than 24 hours old.
    #
    class Cache

      require 'fileutils'

      begin
        require 'md5'
      rescue LoadError
	# Ruby 1.9 has moved MD5.
	#
	require 'digest/md5'
      end

      # Exception class for bad cache paths.
      #
      class PathError < StandardError; end

      # Length of one day in seconds
      #
      ONE_DAY = 86400	# :nodoc:

      # Age in days below which to consider cache files valid.
      #
      MAX_AGE = 1.0

      # Default cache location.
      #
      DEFAULT_CACHE_DIR = '/tmp/amazon'

      attr_reader :path

      def initialize(path=DEFAULT_CACHE_DIR)
	path ||= DEFAULT_CACHE_DIR

	::FileUtils::mkdir_p( path ) unless File.exists? path

	unless File.directory? path 
	  raise PathError, "cache path #{path} is not a directory"
	end

	unless File.readable? path 
	  raise PathError, "cache path #{path} is not readable"
	end

	unless File.writable? path
	  raise PathError, "cache path #{path} is not writable"
	end

	@path = path
      end


      # Determine whether or not the the response to a given URL is cached.
      # Returns *true* or *false*.
      #
      def cached?(url)
	digest = Digest::MD5.hexdigest( url )

	cache_files = Dir.glob( File.join( @path, '*' ) ).map do |d|
	  File.basename( d )
	end

	return cache_files.include?( digest ) &&
	  ( Time.now - File.mtime( File.join( @path, digest ) ) ) /
	  ONE_DAY <= MAX_AGE
      end


      # Retrieve the cached response associated with _url_.
      #
      def fetch(url)
	digest = Digest::MD5.hexdigest( url )
	cache_file = File.join( @path, digest )

	return nil unless File.exist? cache_file

	Amazon.dprintf( 'Fetching %s from cache...', digest )
	File.open( File.join( cache_file ) ).readlines.to_s
      end


      # Cache the data from _contents_ and associate it with _url_.
      #
      def store(url, contents)
	digest = Digest::MD5.hexdigest( url )
	cache_file = File.join( @path, digest )

	Amazon.dprintf( 'Caching %s...', digest )
	File.open( cache_file, 'w' ) { |f| f.puts contents }
      end


      # This method flushes all files from the cache directory specified
      # in the object's <i>@path</i> variable.
      #
      def flush_all
	FileUtils.rm Dir.glob( File.join( @path, '*' ) )
      end


      # This method flushes expired files from the cache directory specified
      # in the object's <i>@path</i> variable.
      #
      def flush_expired
	now = Time.now

	expired_files = Dir.glob( File.join( @path, '*' ) ).find_all do |f|
	  ( now - File.mtime( f ) ) / ONE_DAY > MAX_AGE
	end

	FileUtils.rm expired_files
      end

    end

  end

end
