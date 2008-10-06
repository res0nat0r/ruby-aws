# $Id: ruby-aws.spec,v 1.16 2008/10/03 12:00:57 ianmacd Exp $

%{!?ruby_sitelib:	%define ruby_sitelib	%(ruby -rrbconfig -e "puts Config::CONFIG['sitelibdir']")}
%{!?ruby_rdoc_sitepath:	%define ruby_rdoc_sitepath %(ruby -rrdoc/ri/ri_paths -e "puts RI::Paths::PATH[1]")}
%define		rubyabi		1.8

Name:		ruby-aws
Version:	0.4.4
Release:	1%{?dist}
Summary:	Ruby library interface to Amazon Associates Web Services
Group:		Development/Languages

License:	GPL+
URL:		http://www.caliban.org/ruby/ruby-aws/
Source0:	http://www.caliban.org/files/ruby/%{name}-%{version}.tar.gz
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildArch:	noarch
BuildRequires:	ruby, ruby-rdoc
#BuildRequires:	ruby-devel
Requires:	ruby >= 1.8.6
Provides:	ruby(aws) = %{version}-%{release}
# Obsoletes but not Provides, because Ruby/Amazon API is obsolete.
Obsoletes:	ruby-amazon

%description
Ruby/AWS is a Ruby language library that allows the programmer to retrieve
information from Amazon via the Associate Web Service. In addition to the
original amazon.com site, amazon.co.uk, amazon.de, amazon.fr, amazon.ca and
amazon.co.jp are also supported.

In addition to wrapping the AWS API, Ruby/AWS provides geolocation of clients,
transparent fetching of all hits for a given search (not just the first 10)
and a host of other features.

Ruby/AWS supersedes Ruby/Amazon.


%package	doc
Summary:	Documentation for %{name}
Group:		Documentation

%description	doc
This package contains documentation for %{name}.


%prep
%setup -q

%build
ruby setup.rb config \
	--prefix=%{_prefix} \
	--site-ruby=%{ruby_sitelib}
ruby setup.rb setup

%install
%{__rm} -rf $RPM_BUILD_ROOT

ruby setup.rb install \
	--prefix=$RPM_BUILD_ROOT

%{__chmod} ugo-x example/*

rdoc -r -o $RPM_BUILD_ROOT%{ruby_rdoc_sitepath} -x CVS lib
%{__rm} $RPM_BUILD_ROOT%{ruby_rdoc_sitepath}/created.rid

%clean
%{__rm} -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc COPYING
%doc NEWS
%doc README*

%{ruby_sitelib}/amazon.rb
%{ruby_sitelib}/amazon/

%files doc
%defattr(-,root,root,-)
%doc example/
%doc test/
%doc %{ruby_rdoc_sitepath}/

%changelog
* Fri Oct  3 2008 Ian Macdonald <ian@caliban.org> 0.4.4-1
- 0.4.4
- $AMAZONRCFILE may now be defined with an alternative to .amazonrc.
- $AMAZONRCDIR and typical Windows paths were not being used as alternatives
  to $HOME.

* Wed Sep 11 2008 Ian Macdonald <ian@caliban.org> 0.4.2-1
- 0.4.2
- AWS API revision 2008-08-19 now used for all calls.
- Exception class Amazon::Config::ConfigError was not defined.
- Config file lines may now contain leading whitespace.
- ALL_PAGES now takes into account the type of search operation being
  performed.

* Mon Aug 18 2008 Ian Macdonald <ian@caliban.org> 0.4.1-1
- 0.4.1
- Exception class Amazon::AWS::HTTPError was not defined.
- Scan extra locations besides $HOME for .amazonrc (for Windows users).

* Sat Jul  5 2008 Ian Macdonald <ian@caliban.org> 0.4.0-1
- 0.4.0
- AWS API revision 2008-04-07 now used for all calls.
- Remote shopping-cart operation, CartGet, is now implemented.
- A bug in Cart#modify was fixed.

* Mon Jun 23 2008 Ian Macdonald <ian@caliban.org> 0.3.3-1
- 0.3.3
- Minor code clean-up.
- Rakefile added for packaging Ruby/AWS as a RubyGems gem.

* Tue Jun 17 2008 Ian Macdonald <ian@caliban.org> 0.3.2-1
- 0.3.2
- Solved Marshal and YAML deserialisation issues, which occur because objects
  dumped from dynamically defined classes can't be reinstantiated at
  load-time, when those classes no longer exist.

* Tue Jun 10 2008 Ian Macdonald <ian@caliban.org> 0.3.1-1
- 0.3.1
- The 'Save For Later' area of remote shopping-carts is now implemented. See
  Cart#cart_modify and the @saved_for_later_items attribute of Cart objects.
- New methods, Cart#active? and Cart#saved_for_later?
- Cart#include? now also takes the Save For Later area of the cart into
  account.
- Numerous bug fixes.

* Mon May 19 2008 Ian Macdonald <ian@caliban.org> 0.3.0-1
- 0.3.0
- Remote shopping-carts are now implemented. Newly supported operations are
  CartCreate, CartAdd, CartModify and CartClear.
- New iterator method, AWSObject#each, yields each |property, value| of the
  AWSObject.
- AWS API revision 2008-04-07 now used for all calls.
- Error-checking improved.
- Minor bug fixes.
- RDoc documentation for ri is now part of the doc subpackage.
- test/ added to doc subpackage.
- BuildRequires ruby-rdoc.

* Mon Apr 28 2008 Ian Macdonald <ian@caliban.org> 0.2.0-1
- 0.2.0
- Removed BuildRequires and Requires for ruby(abi).
- New operations supported: CustomerContentLookup, CustomerContentSearch,
  Help, ListLookup, SellerListingSearch, SellerLookup, SimilarityLookup,
  TagLookup, TransactionLookup.
- Symbols can now be used instead of Strings as parameters when instantiating
  operation and response group objects.
- Image objects can now retrieve their images and optionally overlay them with
  percentage discount icons.
- Compatibility fixes for Ruby 1.9.
- Dozens of other fixes and minor improvements.

* Sat Apr 11 2008 Ian Macdonald <ian@caliban.org> 0.1.0-1
- 0.1.0
- Completely rewritten XML parser.
- Multiple operations are now implemented.
- Numerous fixes and improvements.
- Large scale code clean-up.
- Much more documentation added.
- Use Fedora spec file by Mamoru Tasaka <mtasaka@ioa.s.u-tokyo.ac.jp>.

* Fri Mar 28 2008 Ian Macdonald <ian@caliban.org> 0.0.2-1
- 0.0.2
- Allow multiple response groups to be passed to ResponseGroup.new.
- Minor bug fixes.

* Mon Mar 24 2008 Ian Macdonald <ian@caliban.org> 0.0.1-2
- 0.0.1
- First public (alpha) release.

* Sun Mar 23 2008 Ian Macdonald <ian@caliban.org> 0.0.1-1
- Private test release only.

