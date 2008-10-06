# $Id: locale.rb,v 1.3 2008/06/07 17:28:51 ianmacd Exp $
#

catch :done do

  begin
    require 'net/geoip'
  rescue LoadError
    throw :done
  end

  module Amazon

    # Use of this module requires the use of the GeoIP library from
    # MaxMind[http://www.maxmind.com/]. It also requires the
    # net-geoip[http://rubyforge.org/scm/?group_id=947] Ruby module to
    # interface with it.
    #
    # Load this library as follows:
    #
    #  require 'amazon/locale'
    #
    module Locale

      # These country lists are obviously not complete.

      # ISO 3166[http://www.iso.ch/iso/en/prods-services/iso3166ma/02iso-3166-code-lists/iso_3166-1_decoding_table.html]
      # codes of countries likely to want to shop in the *CA* locale.
      #
      CA = %w[ ca ]

      # ISO 3166 codes of countries likely to want to shop in the *DE* locale.
      #
      DE = %w[ at ch de ]

      # ISO 3166 codes of countries likely to want to shop in the *FR* locale.
      #
      FR = %w[ fr ]

      # ISO 3166 codes of countries likely to want to shop in the *JP* locale.
      #
      JP = %w[ jp ]

      # ISO 3166 codes of countries likely to want to shop in the *UK* locale.
      #
      UK = %w[ ad al ba be cy cz dk ee es fi fo gg gi gr gl hu ie im is it je
	       li lt lu lv mk mt nl no pl pt ro se si sk sm uk ]

      # ISO 3166 codes of countries likely to want to shop in the *US* locale.
      # Any countries not explicitly listed above default to the *US* locale. 
      #
      US = %w[ mx us ]

      # Exception class for geolocation errors.
      #
      class GeoError < StandardError; end

      def Locale.localise(code)
	code.downcase!

	return 'ca' if CA.include? code
	return 'de' if DE.include? code
	return 'fr' if FR.include? code
	return 'jp' if JP.include? code
	return 'uk' if UK.include? code

	'us'
      end
      private_class_method :localise


      # This will attempt to return a reasonable locale (*ca*, *de*, *fr*,
      # *jp*, *uk* or *us*) to use for _host_.
      #
      # Example:
      #
      #  get_locale_by_name( 'xs1.xs4all.nl' ) => "uk"
      #
      def Locale.get_locale_by_name(host)
	cc = Net::GeoIP.new.country_code_by_name( host )
	raise GeoError, "invalid host: #{host}" unless cc
	localise( cc )
      end

      # This will attempt to return a reasonable locale (*ca*, *de*, *fr*,
      # *jp*, *uk* or *us*) to use for the IP address _address_.
      #
      # Example:
      #
      #  get_locale_by_addr( '217.110.207.55' ) => "de"
      #
      def Locale.get_locale_by_addr(address)
	cc = Net::GeoIP.new.country_code_by_addr( address )
	raise GeoError, "invalid address: #{address}" unless cc
	localise( cc )
      end

    end

  end

end
