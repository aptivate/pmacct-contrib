#!/usr/bin/perl
#
# Module: quagga_gen_as_network.pl
# 
# **** License ****
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# A copy of the GNU General Public License is available as
# `/usr/share/common-licenses/GPL' in the Debian GNU/Linux distribution
# or on the World Wide Web at `http://www.gnu.org/copyleft/gpl.html'.
# You can also obtain it by writing to the Free Software Foundation,
# Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.
# 
# This code was originally developed by Vyatta, Inc.
# Portions created by Vyatta are Copyright (C) 2009 Vyatta, Inc.
# All Rights Reserved.
# 
# Author: Stig Thormodsrud
# Date: November 2009
# Description: Script generate as/network file from quagga
# 
# **** End License ****
#

# show ip bgp | quagga_gen_as_network.pl 

use POSIX;

use strict;
use warnings;

my $outfile = '/etc/pmacct/networks.lst';

my $line;
my $line_num = 0;
my $path_ndx = 0;
my %networks_hash;


sub get_line {
    my $line = <STDIN>;
    return if ! defined $line;
    chomp $line;
    $line_num++;
    $line = ' ' if $line eq '';
    return $line;
}


$outfile = $ARGV[0] if defined $ARGV[0];
open my $fd, '>', $outfile
	or die "Can not open file '$outfile': $!\n";

# pull off the header
while ($line = get_line()) {
    if ($line =~ /Path/) {
	$path_ndx = index($line, "Path");
	last;
    }
}
die "No 'show ip bgp' header file" if ! $path_ndx;

my $timestamp = strftime("%Y%m%d-%H:%M.%S", localtime);
print "Writing to [$outfile]\n";
print $fd "! generated by $0 at $timestamp\n";

while ($line = get_line()) {
    if ($line =~ /^\*/) {
	my ($status, $network, $nexthop);
	($status, $network, $nexthop) = split /\s+/, $line;
	if (! $network) {
	    print "unexpected error [$line] line $line_num\n";
	    next;
	}
	if ($network eq '0.0.0.0') {
	    print "skipping default route\n";
	    next;
	}
	my $path;
	# networks over 15 characters have the rest of the info
	# on the next line
	if (length($line) >= $path_ndx){
	    $path = substr($line, $path_ndx);
	} else {
	    $line = get_line();
	    $path = substr($line, $path_ndx);
	}
	if (! $path) {
	    print "unexpected error [$line] line $line_num\n";
	    next if ! $path;
	}
	my @as_list = split / /, $path;
	@as_list = grep /\d+/, @as_list;
	my $last_as = $as_list[-1];
	if ($last_as) {
	    my $dup_as = $networks_hash{$network};
	    if ($dup_as) {
		print "duplicate network [$network] = [$dup_as][$last_as]\n";
		print "\tline $line_num\n";
	    } 
	    $networks_hash{$network} = $last_as;
	    print $fd "$last_as,$network\n";
	}
    } 
}
close $fd;

my $count = scalar keys %networks_hash; 
print "$line_num lines parsed.\n";
print "$count unique as/networks written.\n";
exit 0;