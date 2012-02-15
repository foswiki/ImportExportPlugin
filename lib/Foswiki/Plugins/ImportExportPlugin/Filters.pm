# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::ImportExportPlugin::Filters

filters for importing

=cut

package Foswiki::Plugins::ImportExportPlugin::Filters;

# Always use strict to enforce variable scoping
use strict;
use warnings;

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
