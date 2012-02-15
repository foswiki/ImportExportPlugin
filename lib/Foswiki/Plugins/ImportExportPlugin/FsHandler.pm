# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImportExportPlugin::FsHandler

import/export from local filesystem handler

=cut

package Foswiki::Plugins::ImportExportPlugin::FsHandler;

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

---++ ClassMethod import(  ) -> $status text

=cut

my @webs;
my %files;

sub import {
    my $this = shift;

    my $fspath =
      Foswiki::Sandbox::untaintUnchecked( $this->{cgi}->{param}->{fspath}[0] );
    my $importFrom = Foswiki::Sandbox::untaintUnchecked(
        $this->{cgi}->{param}->{importFrom}[0] );
    my @output = ("import $importFrom from $fspath\n<hr>\n");

    if ( $importFrom eq 'wiki' ) {

        #TODO: what if the source wiki has a customised WebPrefs setting?
        #TODO: what if the data and pub dirs are different
        #TODO: solve all these by using the wiki's cfg file.

        my $data = $fspath . '/data';
        my $pub  = $fspath . '/pub';

        File::Find::find(
            { wanted => \&findWebPrefs, untaint => 1, no_chdir => 1 }, $data );
        @webs = map {

            #do this here as we don't know $data in the wanted
            s/$data\///;
            s/\/WebPreferences\.txt//;
            $_
        } @webs;

        foreach my $web (@webs) {
            print STDERR "$web \n";
            next unless ( $web eq 'Hsa' );

            #see if it exists - skip/merge
            if ( -e $Foswiki::cfg{DataDir} . '/' . $web ) {

                #maybe stop
            }
            else {
                Foswiki::Func::createWeb( $web, '_empty' );
            }

            #foreach topic, copy via filters
            %files = ();
            File::Find::find(
                {
                    wanted   => sub { findfiles($web) },
                    untaint  => 1,
                    no_chdir => 0
                },
                $data . "/$web"
            );
            File::Find::find(
                {
                    wanted   => sub { findAttachments($web) },
                    untaint  => 1,
                    no_chdir => 0
                },
                $pub . "/$web"
            );

            foreach my $topic ( keys(%files) ) {
                my $text;
                if ( $files{$topic}{type} eq 'topic' ) {
                    $text =
                      Foswiki::Sandbox::untaintUnchecked(
                        Foswiki::Func::readFile( $files{$topic}{from} ) );
                }

                #filters can return 'skip', text or 'nochange'
                my ( $result, $filteredweb, $filteredtopic, $filteredtext ) =
                  ( 'nochange', $web, $files{$topic}{topic}, $text );
                foreach my $filter ( @{ $this->{filters} } ) {
                    ( $result, $filteredweb, $filteredtopic, $filteredtext ) =
                      $filter->(
                        $result,        $filteredweb,
                        $filteredtopic, $filteredtext
                      );
                    goto SKIPTOPIC if ( $result eq 'skip' );
                }

#TODO: for eg, could grab _default version of WebHome if its just the twiki million rev release version
#TODO: if its a topic re-name, we need to use Func::moveTopic after everything is finished. else things get busted
#OR keep a list and then re-write all the topic text afterwards

                #TODO: what about twiki 'rcsDir' setting?
                my $destination;
                if ( $files{$topic}{type} eq 'topic' ) {
                    $destination =
                        $Foswiki::cfg{DataDir} . '/'
                      . $filteredweb . '/'
                      . $filteredtopic . '.'
                      . $files{$topic}{ext};
                }
                else {
                    $destination =
                        $Foswiki::cfg{PubDir} . '/'
                      . $filteredweb . '/'
                      . $filteredtopic . '/'
                      . $files{$topic}{filename};
                    mkdir( $Foswiki::cfg{PubDir} . '/' . $filteredweb );
                    mkdir(  $Foswiki::cfg{PubDir} . '/'
                          . $filteredweb . '/'
                          . $filteredtopic );
                }
                push( @output, $files{$topic}{from} . ' -> ' . $destination );

                copy( $files{$topic}{from}, $destination );
                if ( -e $files{$topic}{from} . ',v' ) {
                    copy( $files{$topic}{from} . ',v', $destination . ',v' );
                    `rcs -u -M $destination,v`;
                }
                if ( $result ne 'nochange' ) {
                    if ( $files{$topic}{type} eq 'topic' ) {

                        #commit the modified topic text
                        my $error = Foswiki::Func::saveTopicText(
                            $filteredweb, $filteredtopic,
                            $filteredtext, { forcenewrevision => 1 }
                        );
                        push( @output, $error ) if ($error);
                    }
                }
            }
          SKIPTOPIC:
        }
    }
    else {
        die "$importFrom not implemented yet";
    }

    return join( "<br>\n", ( @output, "\n<hr>\n" ) );

}

sub findWebPrefs {
    if ( $_ =~ /WebPreferences.txt$/ ) {
        push( @webs, Foswiki::Sandbox::untaintUnchecked($File::Find::name) );
    }
}

sub findfiles {

    #my $web = shift; #thought i needed this - can probly remove the crawfordin
    if ( $_ =~ /(.*)\.txt$/ ) {
        $files{ Foswiki::Sandbox::untaintUnchecked($1) } = {
            from     => Foswiki::Sandbox::untaintUnchecked($File::Find::name),
            type     => 'topic',
            topic    => $1,
            filename => Foswiki::Sandbox::untaintUnchecked($_),
            ext      => 'txt'
        };
    }
}

sub findAttachments {
    if ( -f $File::Find::name && not( $_ =~ /(.*),v$/ ) ) {

        $File::Find::dir =~ /\/([^\/]*)$/;

        $files{ Foswiki::Sandbox::untaintUnchecked($_) } = {
            from     => Foswiki::Sandbox::untaintUnchecked($File::Find::name),
            type     => 'attachment',
            topic    => $1,
            filename => Foswiki::Sandbox::untaintUnchecked($_),
        };
    }
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