# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImportExportPlugin


=cut

package Foswiki::Plugins::ImportExportPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package. This should always be in the format
# $Rev$ so that Foswiki can determine the checked-in status of the
# extension.
our $VERSION = '$Rev$';

# $RELEASE is used in the "Find More Extensions" automation in configure.
# It is a manually maintained string used to identify functionality steps.
# You can use any of the following formats:
# tuple   - a sequence of integers separated by . e.g. 1.2.3. The numbers
#           usually refer to major.minor.patch release or similar. You can
#           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
# isodate - a date in ISO8601 format e.g. 2009-08-07
# date    - a date in 1 Jun 2009 format. Three letter English month names only.
# Note: it's important that this string is exactly the same in the extension
# topic - if you use %$RELEASE% with BuildContrib this is done automatically.
our $RELEASE = '1.0.0';
our $SHORTDESCRIPTION = 'Import and export wiki data';
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Example code of how to get a preference value, register a macro
    # handler and register a RESTHandler (remove code you do not need)

    # Set your per-installation plugin configuration in LocalSite.cfg,
    # like this:
    # $Foswiki::cfg{Plugins}{ImportExportPlugin}{ExampleSetting} = 1;
    # See %SYSTEMWEB%.DevelopingPlugins#ConfigSpec for information
    # on integrating your plugin configuration with =configure=.

# Always provide a default in case the setting is not defined in
# LocalSite.cfg.
# my $setting = $Foswiki::cfg{Plugins}{ImportExportPlugin}{ExampleSetting} || 0;

    # Register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    #Foswiki::Func::registerTagHandler( 'EXAMPLETAG', \&_EXAMPLETAG );

    # Allow a sub to be called from the REST interface
    # using the provided alias
    Foswiki::Func::registerRESTHandler( 'import', \&doImport );
    #Foswiki::Func::registerRESTHandler( 'checklinks', \&doCheckLinks );

    # Plugin correctly initialized
    return 1;
}

=begin TML

---++ doImport($session) -> $text

This is an example of a sub to be called by the =rest= script. The parameter is:
   * =$session= - The Foswiki object associated to this session.

Additional parameters can be recovered via the query object in the $session, for example:

my $query = $session->{request};
my $web = $query->{param}->{web}[0];

If your rest handler adds or replaces equivalent functionality to a standard script
provided with Foswiki, it should set the appropriate context in its switchboard entry.
A list of contexts are defined in %SYSTEMWEB%.IfStatements#Context_identifiers.

For more information, check %SYSTEMWEB%.CommandAndCGIScripts#rest

For information about handling error returns from REST handlers, see
Foswiki:Support.Faq1

*Since:* Foswiki::Plugins::VERSION 2.0

=cut

sub doImport {
    my ( $session, $subject, $verb, $response ) = @_;

    my $query = $session->{request};
    my $filterlist =
      Foswiki::Sandbox::untaintUnchecked( $query->{param}->{filterlist}[0] );
    my @filter_funcs;

    foreach my $filter ( split( /[,\s]/, $filterlist ) ) {

        #parameters to filters: skip(Delete*) or similar
        my $f = getFilterFunc($filter);
        if ( defined($f) ) {
            print STDERR "adding filter\n";
            push( @filter_funcs, $f );
        }
    }

    my $type = lc(
        Foswiki::Sandbox::untaintUnchecked(
            $query->{param}->{fromtype}[0] || 'FS'
        )
    );

    my $handler = getFromHandler( $type, $query, \@filter_funcs );

#TODO: this will eventually be a multi-phase thing - show list of candidates to import, then doit
    my $output = $handler->import();
    $output .= "\n\n" . $handler->finish();
    return $output;

}

# filters are called with ($web, $topic, $text, $params) -> ($result, $web, $topic, $text)
# $result can be, nochange, skip or something else

sub getFilterFunc {
    my $filter = shift;

    my $params;
    if ( $filter =~ s/\((.*)\)$// ) {
        $params = $1;
    }

    #TODO: scary, i can call anything?
    $filter = "Foswiki::Plugins::ImportExportPlugin::Filters::$filter";
    eval "use Foswiki::Plugins::ImportExportPlugin::Filters";
    die "can't load Filters" if $@;
    my $funcRef = \&$filter;
    if ( defined($params) ) {
        $funcRef = sub { $funcRef->( @_, $params ) };
    }
    return $funcRef;
}

sub getFromHandler {
    my ( $type, $query, $filterlist ) = @_;

    $type = ucfirst($type);
    my $module = "Foswiki::Plugins::ImportExportPlugin::${type}Handler";

    eval "require $module";
    die "can't load $type handler" if $@;

    my $handler = $module->new( $query, $filterlist );

    return $handler;
}

# The function used to handle the %EXAMPLETAG{...}% macro
# You would have one of these for each macro you want to process.
#sub _EXAMPLETAG {
#    my($session, $params, $topic, $web, $topicObject) = @_;
#    # $session  - a reference to the Foswiki session object
#    #             (you probably won't need it, but documented in Foswiki.pm)
#    # $params=  - a reference to a Foswiki::Attrs object containing
#    #             parameters.
#    #             This can be used as a simple hash that maps parameter names
#    #             to values, with _DEFAULT being the name for the default
#    #             (unnamed) parameter.
#    # $topic    - name of the topic in the query
#    # $web      - name of the web in the query
#    # $topicObject - a reference to a Foswiki::Meta object containing the
#    #             topic the macro is being rendered in (new for foswiki 1.1.x)
#    # Return: the result of processing the macro. This will replace the
#    # macro call in the final text.
#
#    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
#    # $params->{_DEFAULT} will be 'hamburger'
#    # $params->{sideorder} will be 'onions'
#}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: SvenDowideit

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
