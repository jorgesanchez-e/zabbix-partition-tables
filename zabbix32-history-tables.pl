#!/usr/bin/perl

use strict;
use Getopt::Long;
use Date::Calc qw(Today Days_in_Month Date_to_Time);



sub get_options(){
  my $part_index = "";
  my $part_data  = "";
  my $year       = "";
  my $month      = "";

  GetOptions( "index=s" => \$part_index,
              "data=s"  => \$part_data,
              "month=s" => \$month,
              "year=s"  => \$year,
              "help"    => sub { HelpMessage() }
  ) or die ("Error: with input flags");

 if ( $index eq "" ){
    die ("Error: index path was no specified");
 } 



}
