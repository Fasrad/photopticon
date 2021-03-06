#!/usr/bin/perl -w

# usage: photopticon <configfile> <imagefile(s)>

# photopticon is designed to batch-process digital images of complete
# contact-sheets (or images of negative-pages sitting on a light-box).
# It will pre-process the images, then crop out each individual frame 
# (e.g) 36 frames from a roll of 35mm film) and save the resulting files 
# in a directory for browsing, reference, or archiving purposes. 

# limitations: 
# Photopticon uses "dead reckoning" to crop out images. No machine vision or edge detection..
# When processing multiple images with the same config file, each (composite) 
# image must be similar. This means you can't move the tripod between images 
# and all images in a batch must use the same PrintFile page format or contact printer.
# Negative strips must be posititioned roughly the same in each PrintFile slot or 
# contact printer. A configurable "slop" factor crops "extra" pixels around 
# each image to be "safe". 

# photopticon requires a correct config file. Refer to example 
# config file example.yml to get started 

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public
# License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
# 

use YAML::XS 'LoadFile';
use Data::Dumper;
use feature 'say';

# read configfile
$cfgfn=$ARGV[0] // die "USAGE: photopticon <config file> <image file(s)>\n";
die "expecting a config file ending with .yml or .yaml." unless $cfgfn=~/ya?ml$/;
$config=LoadFile("$cfgfn") || die "problem with config file...bad config file syntax?";
say "reading config file $cfgfn with options:";
say Dumper($config);
$pre_rotation   = $config->{pre_rotation} // print "undefined option:pre_rotation\n";
$rows           = $config->{rows} // print "undefined option:rows\n";
$right_crop     = $config->{right_crop} // print "undefined option:right_crop\n";
$pre_scale      = $config->{pre_scale} // print "undefined option:pre_scale\n";
$annotate       = $config->{annotate} // print "undefined option:annotate\n";
$columns        = $config->{columns} // print "undefined option:images_per_row\n";
$normalize      = $config->{normalize} // print "undefined option:normalize\n";
$monochrome     = $config->{monochrome} // print "undefined option:monochrome\n";
$top_crop       = $config->{top_crop} // print "undefined option:top_crop\n";
$sharpen        = $config->{sharpen} // print "undefined option:sharpen\n";
$xslop          = $config->{xslop} // print "undefined option:slop\n";
$yslop          = $config->{yslop} // print "undefined option:slop\n";
$bottom_crop    = $config->{bottom_crop} // print "undefined option:bottom_crop\n";
$left_crop      = $config->{left_crop} // print "undefined option:left_crop\n";

splice(@ARGV,0,1); #shift config file name off 

foreach $infile (@ARGV){         # this does not handle filenames with spaces. 
    say "processing $infile";

    $infile=~/(.*)\.[a-zA-Z]+$/ || die "basename";
    $basename=$1;
    say "basename: $basename";

    # identify infile. Example output of identify:
    # chaz1.jpg JPEG 209x256 209x256+0+0 8-bit PseudoClass 256c 30.6KB 0.000u 0:00.010
    $idstring=qx(identify $infile); print "idstring: $idstring";
    @id=split /\s/, $idstring;
    @geo=split /x/, $id[2];
    $x=$geo[0]; $y=$geo[1];
    say "input file x=$x, y=$y";

    # monochromify
    qx(mogrify -type Grayscale $infile) if $monochrome;#

    # pre-scale
    qx(mogrify -scale $pre_scale% $infile);#

    # pre-rotate
    qx(mogrify -rotate $pre_rotation $infile);# || die "couldn't rotate $infile";

    # pre-crop
    $x-=($left_crop+$right_crop);
    $y-=($top_crop+$bottom_crop);
    say "cropping to x=$x, y=$y with offsets $left_crop and $top_crop";
    $command="mogrify -crop $x"."x$y+$left_crop+$top_crop +repage $infile";
    say "command: $command";
    qx($command);

    # multi-crop

    #use a perl loop here to "manually" calculate offsets and crop out images, or take
    #advantage of mogrify bulk-crop easiness and then process the resulting
    #small images individually. Unsure which is better at this time.

    #mogrify allows this:
    # convert $infile +gravity -crop XxY $infile\_%d.jpg 
    #requires calculating X and Y; will not evenly divide most of the time

    # N by M images auto-crop. Is adaptive when not evenly divisible. What's with the ":"?
    # the +20 is overlap.  Can by negative. I think this is what we want. 
    $command=
        "convert $infile -crop $columns" .
        "x$rows"."$xslop"."$yslop"."@ +repage +adjoin $basename"."_%00d.gif";
    say "command: $command";
    system($command);
}

say "done. Check output.";

