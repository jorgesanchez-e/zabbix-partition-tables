#!/usr/bin/perl

use strict;
use Getopt::Long;
use Date::Calc qw(Today Days_in_Month Date_to_Time Mktime);

my $data = "";
my $host = "";
my $port = "";

GetOptions ( "hosts=s" => \$host,
	     "port=s"  => \$port
	   );

if ( !$host eq "" ){
 $host = "--host $host"; 
}

if ( !$port eq "" ){
  $port = "--port $port";
}

$data = get_initdata();
generate_statements($data);
die();

###############################################################################
sub HelpMessage(){
  print "This program is designed to build CREATE TABLE and CREATE INDEX statements\n";
  print "needed by zabbix database in order to continuty store monitoring data from\n";
  print "from zabbix agents\n\n";
  print "Usage:\n";
  print "\tzabbix32-history-tables.pl --data=/path/to/data --index=/path/to/index\n\n";
  die();
}

sub get_initdata(){
  my $data       = {};

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  $year += 1900;
  $mon  = sprintf("%02d", $mon + 1);

 my $reg = {
   "YEAR"       => $year,
   "MONTH"      => $mon,
   "INDEX_TS"   => "index_tablespace",
   "DATA_TS"    => "data_tablespace"
 };

 return $reg;
}

sub generate_statements(){
  my $data       = $_[0];
  my $month      = $data->{"MONTH"};
  my $year       = $data->{"YEAR"};
  my $days       = Days_in_Month($year,$month);
  my $tables     = ["history", "history_log", "history_str", "history_text", "history_uint"];
  my $indexes    = ["history_1", "history_log_1","history_str_1", "history_text_1", "history_uint_1"];
  my $tablespaces = {
    "INDEX" => "zabbix_index_ts",
    "DATA"  => "zabbix_data_ts"
  };
  my $statements = ();

  if ( $month == 12 ){
    $month = "01";
    $year++;
  }
  else {
    $month++;
  }

  foreach my $table ( @{$tables} ){
    my $name = $table . "_" . $month  . "_" . $year;
    my $iname = "indx_" . $name;
    my $init = Mktime($year,$month,1,0,0,0);
    my $end  = Mktime($year,$month,$days,23,59,59);
    my $str = sprintf( "CREATE TABLE %s ( CONSTRAINT %s_clock_check CHECK (((clock >= %s) AND (clock <= %s))) ) INHERITS (%s) TABLESPACE %s;", $name, $name, $init, $end, $table, $tablespaces->{"DATA"});
    push(@{$statements}, $str); 
    $str = "ALTER TABLE $name OWNER TO zabbix;";
    push(@{$statements}, $str);
    $str = sprintf("CREATE INDEX %s ON %s (itemid,clock) TABLESPACE %s;",$iname, $name, $tablespaces->{"INDEX"});
    push(@{$statements}, $str);
  }

  foreach my $stt ( @{$statements} ){
    open CMD, "echo \'$stt\' | psql zabbix $host $port |";
    #print $stt . "\n";
  }

}
