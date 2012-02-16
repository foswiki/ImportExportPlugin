# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImportExportPlugin::FoswikiHandler

import/export from local filesystem handler

=cut

package Foswiki::Plugins::ImportExportPlugin::FoswikiHandler;

# Always use strict to enforce variable scoping
use strict;
use warnings;
use File::Copy;
use File::Find;
use Foswiki::Func;

=begin TML

---++ ClassMethod new( $class, $query, $filterlist ) -> $handler

=cut

sub new {
    my $class      = shift;
    my $query      = shift;
    my $filterlist = shift;

    my $this = bless( { cgi => $query, filters => $filterlist }, $class );
    return $this;
}

=begin TML

---++ ClassMethod check(  ) -> $status text

=cut

sub check {
    my $this = shift;

    my $webs =
      Foswiki::Sandbox::untaintUnchecked( $this->{cgi}->{param}->{webs}[0] );
    my @output = ("---++ checking $webs for broken or odd links \n<hr>\n");

    my @webs = split( /,\s*/, $webs );

    my %links;

    foreach my $web (@webs) {
        print STDERR "$web \n";

        next unless ( Foswiki::Func::webExists($web) );

        my $webObject = Foswiki::Meta->new( $Foswiki::Plugins::SESSION, $web );

        #TODO: ew! there's no iterator version in Func
        my $topicItr = $webObject->eachTopic();
        my $count;
        while ( $topicItr->hasNext() ) {
            my $topic = $topicItr->next();
#            next unless ( $count++ < 5 );
            my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

            #filters can return 'skip', text or 'nochange'
            my ( $result, $filteredweb, $filteredtopic, $filteredtext ) =
              ( 'nochange', $web, $topic, $text );
            foreach my $filter ( @{ $this->{filters} } ) {
                my $linksListRef;
                (
                    $result,       $filteredweb, $filteredtopic,
                    $filteredtext, $linksListRef
                  )
                  = $filter->(
                    $result, $filteredweb, $filteredtopic, $filteredtext
                  );
                if ( defined($linksListRef) && ref($linksListRef) eq 'ARRAY' ) {
                    map { push( @{ $links{$_} }, $web . '.' . $topic ); }
                      @$linksListRef;
                }
                goto SKIPTOPIC if ( $result eq 'skip' );
            }

            #list of links for each topic
            push(@output, "   1 $filteredweb.$filteredtopic: $result");

          SKIPTOPIC:
        }
    }

    #list of links and how often they are used in that web
    my $linkCount = scalar(keys(%links));
    #push( @output, map { $_ . ' : ' . join(' , ', @{$links{$_}}) } sort(keys(%links)) );

    return join( "<br>\n", ( @output, "\n<hr>\nnumber of broken links: $linkCount\n<hr>\n" ) );

}

=begin TML

---++ ClassMethod finish(  ) 

=cut

sub finish {
    return 'finishing local resources';

}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: SvenDowideit

Copyright (C) 2012 SvenDowideit@fosiki.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
