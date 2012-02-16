# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImportExportPlugin::Filters

filters for importing

=cut

package Foswiki::Plugins::ImportExportPlugin::Filters;

# Always use strict to enforce variable scoping
use strict;
use warnings;

our %switchboard = (
    selectwebs => \&selectwebs,
    skiptopics => \&skiptopics,
    twiki => \&twiki,
    chklinks => \&chkLinks
);

=begin TML

---++ ClassMethod TODO( $web, $topic, $text, $params ) -> ( $result, $web, $topic, $text )

TODO: need to add the following filters
   * html - convert a set of html files to foswiki format, need a remove_prefix, remove_postfix, html2tml, 
   * rename webs - list of from -> to conversions, including some mechanism to merge webs together (drop dups, merge dupes, rename second dup..)
   * skipdistrotopics - work out what topics are unmodified by wiki users (ie, shipped in the release) and skip those that were from the old (or twiki) release

=cut


=begin TML

---++ ClassMethod nothing( $web, $topic, $text, $params ) -> ( $result, $web, $topic, $text )

does nothing - copy to create a new filter.

=cut

sub nothing {
    my ( $result, $web, $topic, $text, $params ) = @_;
    
    return ( $result, $web, $topic, $text );
}


=begin TML

---++ ClassMethod chkLinks( $web, $topic, $text, $params ) -> ( $result, $web, $topic, $text )

   * chkLinks - check for URLs and wiki links, report on them with frequency, broken link, missing topic, html links to in-wiki topics
      * plus a 'fixup' option :)

=cut

my %testedLinkCache;

sub chkLinks {
    my ( $result, $web, $topic, $text, $params ) = @_;
    
    #TODO: search url  links to topics (and add fixup)
    #TODO: does not do plurals, even thought Foswiki core does
    
    $Foswiki::Plugins::ImportExportPlugin::checkingLinks = 1;
    %Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered = ();
    #test for bad links in rendered html
    my $expandedTML = Foswiki::Func::expandCommonVariables( $text, $web, $topic );
    my $html = Foswiki::Func::renderText( $expandedTML, $web, $topic );
    my %links;
    $html =~ s/href=['"](.*?)['"]/$links{$1}++/gem;
    
    #remove links to things that exist
    foreach my $link (keys(%Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered)) {
        if (not exists $testedLinkCache{$link}) {
            my $webtopic = $link;
            $webtopic =~ s/(INCLUDINGWEB)\.//;
            my ($lweb, $ltopic) = Foswiki::Func::normalizeWebTopicName($web, $webtopic);
            $testedLinkCache{$link} = Foswiki::Func::topicExists($lweb, $ltopic);
        }
        
        #should not delete things that are not wikiwords unless the user selects it
        
        if ($testedLinkCache{$link}) {
            delete $Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered{$link};
        }
    }

    my $restBase = Foswiki::Func::getScriptUrl(undef, undef, 'rest');
    my $restBasePath = Foswiki::Func::getScriptUrlPath(undef, undef, 'rest');
    my $viewBase = Foswiki::Func::getScriptUrl(undef, undef, 'view');
    my $viewBasePath = Foswiki::Func::getScriptUrlPath(undef, undef, 'view');
    my $editBase = Foswiki::Func::getScriptUrl(undef, undef, 'edit');
    my $editBasePath = Foswiki::Func::getScriptUrlPath(undef, undef, 'edit');
    foreach my $link (keys(%links)) {
        if (not exists $testedLinkCache{$link}) {
            if ($link =~ /($restBase|$restBasePath)/) {
                #the text rendering is using this rest handler as the basurl for tableedit and stuff.
                $testedLinkCache{$link} = 'rest';    #fake it being OK
            } else {
                my $webtopic = $link;
                $webtopic =~ s/[#?].*$//;
                if ($webtopic =~ s/($editBase|$editBasePath)(.*?)/$2/g) {
#                    my ($web, $topic) = Foswiki::Func::normalizeWebTopicName('', $webtopic);
#                   if (exists $testedLinkCache{"$web.$topic"}) {
                        #this is an edit link to a topic thats listed in a WikiWord link so we don't want to list it twice
                        $testedLinkCache{$link} = 'duplicate';
#                   }
                } elsif ($webtopic =~ /($viewBase|$viewBasePath)(.*)/) {
                    my ($web, $topic) = Foswiki::Func::normalizeWebTopicName('', $2);
                    $testedLinkCache{$link} = Foswiki::Func::topicExists($web, $topic);
                }
            }
        }
        if ($testedLinkCache{$link}) {
            delete $links{$link};
        }
    }
    
    $result = "\n      * ".join("\n      * ", keys(%links)) if (scalar(keys(%links)) > 0);
    $result .= "\n      * WW: ".join("\n      * WW: ", keys(%Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered)) if (scalar(keys(%Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered)) > 0);
    
    my @links = (keys(%links), keys(%Foswiki::Plugins::ImportExportPlugin::wikiWordsRendered));
    return ( $result, $web, $topic, $text, \@links );
}


=begin TML

---++ ClassMethod skiptopics( $web, $topic, $text, $params ) -> ( $result, $web, $topic, $text )

   * skiptopics - Skip topics named in list - used to skip this plugin's check reports when checking

=cut

sub skiptopics {
    my ( $result, $web, $topic, $text, $params ) = @_;
    
    my @skiptopics = split(/;\s*/, $params);
    if (grep(/$topic/, @skiptopics)) {
        $result = 'skip';
    }
    
    return ( $result, $web, $topic, $text );
}


=begin TML

---++ ClassMethod selectwebs( $web, $topic, $text, $params ) -> ( $result, $web, $topic, $text )

   * selectwebs - only import a specified list of webs (csv in $params), skip the others.

=cut

sub selectwebs {
    my ( $result, $web, $topic, $text, $params ) = @_;
    
    my @selectedwebs = split(/;\s*/, $params);
    if (grep(/$web/, @selectedwebs)) {
        #in
    } else {
        $result = 'skip';
    }
    
    return ( $result, $web, $topic, $text );
}


=begin TML

---++ ClassMethod twiki( $web, $topic, $text, $params ) -> ( $result, $web, $topic, $text )

   1 convert topics with names containting 'TWiki' to 'Wiki'
   2 work out what topics in the Main web are edited by users and xfer / merge them
        * that essentially means loading the txt into a Meta obj and seeing what the author is? (regex good)
   3 scan topic texts for links to TWiki or renamed topics or attachments and update them
   4 scan for URL based links to wiki items and replace where possible.

report on everything that you did!
   


=cut

#extract into filter classes
sub twiki {
    my ( $result, $web, $topic, $text, $params ) = @_;

    print STDERR " twiki($web, $topic)";

    #TODO: apply conversions from TCP..

    #rename user topics that contain 'TWiki'
    if ( $topic =~ /TWiki/ ) {
        $topic =~ s/^TWiki/Wiki/g;
        $result .= ', convert topic name from TWiki to Wiki';
    }
    my $oldtopics = '('
      . join(
        '|',
        (
            keys(
                %{
                    $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
                      {TWikiWebTopicNameConversion}
                  }
            )
        )
      ) . ')';
    $text =~ s/$oldtopics/replace('TWiki', $1, \$result)/gem;

    $oldtopics = '('
      . join(
        '|',
        (
            keys(
                %{
                    $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
                      {MainWebTopicNameConversion}
                  }
            )
        )
      ) . ')';
    $text =~ s/$oldtopics/replace('Main', $1, \$result)/gem;

    #not sure how to pick Main and TWiki web names to convert..

    return ( $result, $web, $topic, $text );
}

sub replace {
    my $web       = shift;
    my $topic     = shift;
    my $resultRef = shift;

    $$resultRef .= " replace($topic)";
    return $Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}
      { $web . 'WebTopicNameConversion' }{$topic};
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
