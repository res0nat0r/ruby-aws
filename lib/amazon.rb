# $Id: amazon.rb,v 1.25 2008/10/03 09:35:37 ianmacd Exp $
#

module Amazon

  # A top-level exception container class.
  #
  class AmazonError < StandardError; end

  NAME = 'Ruby/Amazon'
  @@config = {}

  # Prints debugging messages and works like printf, except that it prints
  # only when Ruby is run with the -d switch.
  #
  def Amazon.dprintf(format='', *args)
    $stderr.printf( format + "\n", *args ) if $DEBUG
  end


  # Encode a string, such that it is suitable for HTTP transmission.
  #
  def Amazon.url_encode(string)

    # Shamelessly plagiarised from Wakou Aoyama's cgi.rb.
    #
    string.gsub( /([^ a-zA-Z0-9_.-]+)/n ) do
      '%' + $1.unpack( 'H2' * $1.size ).join( '%' ).upcase
    end.tr( ' ', '+' )
  end


  # Convert a string from CamelCase to ruby_case.
  #
  def Amazon.uncamelise(str)
    # Avoid modifying by reference.
    #
    str = str.dup

    # Don't mess with string if all caps.
    #
    str.gsub!( /(.+?)(([A-Z][a-z]|[A-Z]+$))/, "\\1_\\2" ) if str =~ /[a-z]/

    # Convert to lower case.
    #
    str.downcase
  end


  # A Class for dealing with configuration files, such as
  # <tt>/etc/amazonrc</tt> and <tt>~/.amazonrc</tt>.
  #
  class Config < Hash

    require 'stringio'

    # Exception class for configuration file errors.
    #
    class ConfigError < AmazonError; end

    # A configuration may be passed in as a string. Otherwise, the files
    # <tt>/etc/amazonrc</tt> and <tt>~/.amazonrc</tt> are read if they exist
    # and are readable.
    #
    def initialize(config_str=nil)

      if config_str

	# We have been passed a config file as a string.
	#
        config_files = [ config_str ]
	config_class = StringIO

      else

	# Perform the usual search for the system and user config files.
	#
	config_files = [ File.join( '', 'etc', 'amazonrc' ) ]

	# Figure out where home is. The locations after HOME are for Windows.
	# [ruby-core:12347]
	#
	home = ENV['AMAZONRCDIR'] ||
	       ENV['HOME'] || ENV['HOMEDRIVE'] + ENV['HOMEPATH'] ||
	       ENV['USERPROFILE']
	user_rcfile = ENV['AMAZONRCFILE'] || '.amazonrc'

	if home
	  config_files << File.expand_path( File.join( home, user_rcfile ) )
	end

	config_class = File
      end

      config_files.each do |cf|

	if config_class == StringIO
	  readable = true
	else
	  # We must determine whether the file is readable.
	  #
	  readable = File.exists?( cf ) && File.readable?( cf )
	end

	if readable

	  Amazon.dprintf( 'Opening %s ...', cf ) if config_class == File
    
	  config_class.open( cf ) { |f| lines = f.readlines }.each do |line|
	    line.chomp!
    
	    # Skip comments and blank lines.
	    #
	    next if line =~ /^(#|$)/
    
	    Amazon.dprintf( 'Read: %s', line )
    
	    # Store these, because we'll probably find a use for these later.
	    #
	    begin
      	      match = line.match( /^\s*(\S+)\s*=\s*(['"]?)([^'"]+)(['"]?)/ )
	      key, begin_quote, val, end_quote = match[1, 4]
	      raise ConfigError if begin_quote != end_quote

	    rescue NoMethodError, ConfigError
	      raise ConfigError, "bad config line: #{line}"
	    end
    
	    self[key] = val
    
	  end
	end

      end

    end
  end

end
