#!/usr/bin/env perl

use strict;
use File::Copy;
use File::Basename;
use Getopt::Long;
use IO::Compress::Gzip qw(gzip $GzipError);
use IO::Uncompress::Gunzip qw($GunzipError);
use Date::Calc qw(Today Days_in_Month Date_to_Time);

print ("\n\n");
my $data = get_options();

# ADD TABLESPACES TO A NEW FILE
# MODIFY CREATE.SQL.GZ to add tablespaces statement to CREATE TABLE/INDEX statementes.
# ADD CREATE FUNCTIONS TO A NEW FILE

create_tablespaces($data);
modify_createfile($data);
create_functions($data);

print ("\n\n");

exit(0);
##################################################################################
sub get_options (){

 my $part_index = "";
 my $part_data  = "";
 my $file       = "";

 GetOptions( "index=s" => \$part_index,
             "data=s"  => \$part_data,
             "file=s"  => \$file,
	           "help"    => sub { HelpMessage() }
 ) or die ("Error with input flags");

 if ( $file eq "" ){
    $file = "create.sql.gz";
 }

 if ( ! -f $file || ! -w $file ){
   die("Error, file [$file] doesn't exist of or it couldn't be readed or written");
 }

 if ( $part_data eq "" ){
   print "ERROR, you didn't specify a tablespace for data\n\n";
   HelpMessage();
   die();
 }

 if ( $part_index eq "" ){
   print "ERROR, you didn't specify a tablespace for indexes\n\n";
   HelpMessage();
   die();
 }

 return init_info( $file, $part_index, $part_data );
}

sub HelpMessage(){
  print "This program will help you to modify create.sql.gz zabbix instalation file\n";
  print "This program will help you to create a partitioned database for zabbix installation\n";
  print "creating a new file called create_tablespaces.sql containing tablespace definition\n";
  print "you have to execute this file before execution of file create.sql.gz as zabbix installation\n";
  print "manual says. This script will modify create.sql.gz file also to adapt all CREATE TABLE and\n";
  print "CREATE INDEX statements to use tablespaces\n";
  print "usage:\n";
  print "\t $0\n";
  print "\t\t --index=/path/to/index/directory/tablespace\n";
  print "\t\t --data=/path/to/data/directory/tablespace\n";
  print "\t\t [--file=/path/to/create.sql.gz]\n";
  print "\n";

  die();
}

sub init_info($$$){
   my $file          = $_[0];
   my $index_part    = $_[1];
   my $data_part     = $_[2];
   my $index_ts_name = "zabbix_index_ts";
   my $data_ts_name  = "zabbix_data_ts";
   my $reg           = {};
   my $path          = "";

  ( undef, $path, undef ) = fileparse($file, ());

  $path .= "/" if ( ! $file =~ /\/$/ );

  return $reg = {
        "ZABBIX_FILE"     => $file,
        "ZABBIX_FILE_OLD" => $file.".old",
        "INDEX_TS_NAME"   => $index_ts_name,
        "INDEX_TS_PATH"   => $index_part,
        "DATA_TS_NAME"    => $data_ts_name,
        "DATA_TS_PATH"    => $data_part,
        "ZABBIX_PATH"     => $path,
	      "ZABBIX_TMP_FILE" => "/tmp/zabbix.tmp",
        "ZABBIX_TS_FILE"  => "create_tablespaces.sql",
        "ZABBIX_FN_FILE"  => "create_functions.sql"
   };
}

sub create_tablespaces($){
  my $data       = $_[0];
  my $nlines     = 0;
  my $fd         = undef;
  my $out_file   = "$data->{'ZABBIX_PATH'}/$data->{'ZABBIX_TS_FILE'}";

  open($fd, '>', $out_file)
        or die ("Error, Couldn't open file [$out_file] for writting");

  print "- Adding tablespaces statements to file [$out_file] you have to execute this file with postgresql super-user before anything ... \n";
  print $fd "-- This statements will create tablespaces for your data and your indexes\n";
  print $fd "-- thus you have to execute this file before every thing else and  with\n";
  print $fd "-- PostgreSQL super user grants\n";
  print $fd "\n";
  print $fd "CREATE TABLESPACE $data->{'INDEX_TS_NAME'} LOCATION '$data->{'INDEX_TS_PATH'}';\n";
  print $fd "CREATE TABLESPACE $data->{'DATA_TS_NAME'} LOCATION '$data->{'DATA_TS_PATH'}';\n\n";
  print $fd "ALTER TABLESPACE $data->{'INDEX_TS_NAME'} OWNER TO zabbix;\n";
  print $fd "ALTER TABLESPACE $data->{'DATA_TS_NAME'} OWNER TO zabbix;\n";
  close($fd);
}

sub modify_createfile($){
  my $data       = $_[0];
  my $fd         = undef;
  my $nlines     = 0;
  my $uncompress = IO::Uncompress::Gunzip->new( $data->{"ZABBIX_FILE"} )
     or die("Error, file [$data->{'ZABBIX_FILE'}] could't be uncompressed");

  open($fd, '>', $data->{"ZABBIX_TMP_FILE"})
	     or die ("Error, Couldn't open file [$data->{'ZABBIX_TMP_FILE'}] for writting");

  $/ = ";";
  while(<$uncompress>){
     my $line = $_;
     $nlines++;

     next if ( $line =~ m/\s*COMMIT;\s*/g );

     if ( $line =~ m/CREATE\s+(?:\w+)?\s*INDEX/i ){
        $line =~ s/;$/ TABLESPACE $data->{"INDEX_TS_NAME"};/;
        $nlines++;
     }

     if ( $line =~ m/CREATE\s+TABLE/ ){
        $line =~ s/;$/ TABLESPACE $data->{"DATA_TS_NAME"};/;
        $nlines++;
     }
     print $fd $line;
  }

  my $tables = qq {
CREATE TABLE history_MM_YY (
   CONSTRAINT history_MM_YY_clock_check CHECK (((clock >= _EPOCH_INIT_) AND (clock <= _EPOCH_END_)))
) INHERITS (history) TABLESPACE _TABLESPACE_NAME_;
CREATE TABLE history_log_MM_YY (
   CONSTRAINT history_log_MM_YY_clock_check CHECK (((clock >= _EPOCH_INIT_) AND (clock <= _EPOCH_END_)))
) INHERITS (history_log) TABLESPACE _TABLESPACE_NAME_;
CREATE TABLE history_str_MM_YY (
  CONSTRAINT history_str_MM_YY_clock_check CHECK (((clock >= _EPOCH_INIT_) AND (clock <= _EPOCH_END_)))
) INHERITS (history_str) TABLESPACE _TABLESPACE_NAME_;
CREATE TABLE history_text_MM_YY (
  CONSTRAINT history_text_MM_YY_clock_check CHECK (((clock >= _EPOCH_INIT_) AND (clock <= _EPOCH_END_)))
) INHERITS (history_text) TABLESPACE _TABLESPACE_NAME_;
CREATE TABLE history_uint_MM_YY (
  CONSTRAINT history_uint_MM_YY_clock_check CHECK (((clock >= _EPOCH_INIT_) AND (clock <= _EPOCH_END_)))
) INHERITS (history_uint) TABLESPACE _TABLESPACE_NAME_;
  };

  my $indexes = qq {
CREATE INDEX indx_history_MM_YY ON history_MM_YY (itemid,clock) TABLESPACE _TABLESPACE_NAME_;
CREATE INDEX indx_history_log_MM_YY ON history_log_MM_YY (itemid,clock) TABLESPACE _TABLESPACE_NAME_;
CREATE INDEX indx_history_str_MM_YY ON history_str_MM_YY (itemid,clock) TABLESPACE _TABLESPACE_NAME_;
CREATE INDEX indx_history_text_MM_YY ON history_text_MM_YY (itemid,clock) TABLESPACE _TABLESPACE_NAME_;
CREATE INDEX indx_history_uint_MM_YY ON history_uint_MM_YY (itemid,clock) TABLESPACE _TABLESPACE_NAME_;
};

  $tables =~ s/_TABLESPACE_NAME_/$data->{"DATA_TS_NAME"}/g;
  $indexes =~ s/_TABLESPACE_NAME_/$data->{"INDEX_TS_NAME"}/g;

  print "- Adding every else statements, dated tables, functions, triggers ... \n";
  print $fd "\n";
  print $fd replace_dates($tables);
  print $fd replace_dates($indexes);
  print $fd "\n";

  print $fd "COMMIT;";

  close($uncompress);
  close($fd);  
  move_files($data);
}

sub create_functions($){
  my $data = $_[0];
  my $fd   = undef;

#        "ZABBIX_FILE"     => $file,
#        "ZABBIX_FILE_OLD" => $file.".old",
#        "INDEX_TS_NAME"   => $index_ts_name,
#        "INDEX_TS_PATH"   => $index_part,
#        "DATA_TS_NAME"    => $data_ts_name,
#        "DATA_TS_PATH"    => $data_part,
#        "ZABBIX_PATH"     => $path,
#	      "ZABBIX_TMP_FILE" => "/tmp/zabbix.tmp",
#        "ZABBIX_TS_FILE"  => "create_tablespaces.sql",
#        "ZABBIX_FN_FILE"  => "create_functions.sql"

  my $plpgsql = "
CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;
COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';
";

  my $functions = qq{
CREATE OR REPLACE FUNCTION func_insert_history() RETURNS TRIGGER
    LANGUAGE plpgsql
    AS \$\$

    DECLARE
      table_name varchar;

    BEGIN
      table_name := 'history_' || to_char(to_timestamp(NEW.clock),'MM_YYYY');
      EXECUTE format('INSERT INTO %I values  %s', table_name, NEW.*);
      RETURN NULL;
    END;
\$\$;

CREATE OR REPLACE FUNCTION func_insert_history_log() RETURNS TRIGGER
    LANGUAGE plpgsql
    AS \$_\$

    DECLARE
      table_name varchar;

    BEGIN
      table_name := 'history_log_' || to_char(to_timestamp(NEW.clock),'MM_YYYY');
      EXECUTE format('INSERT INTO %I (itemid, clock, timestamp, source, severity, value, logeventid, ns) '
      ' values (\$1,\$2,\$3,\$4,\$5,\$6,\$7,\$8)', table_name ) USING  NEW.itemid, NEW.clock, NEW.timestamp, NEW.source, NEW.severity, NEW.value, NEW.logeventid, NEW.ns;

      RETURN NULL;
    END;
\$_\$;

CREATE OR REPLACE FUNCTION func_insert_history_str() RETURNS TRIGGER
    LANGUAGE plpgsql
    AS \$_\$

    DECLARE
      table_name varchar;

    BEGIN
       table_name := 'history_str_' || to_char(to_timestamp(NEW.clock),'MM_YYYY');
       EXECUTE format('INSERT INTO %I (itemid,clock,value,ns) values  (\$1,\$2,\$3,\$4)', table_name) USING  NEW.itemid, NEW.clock, NEW.value, NEW.ns;
       RETURN NULL;
    END;
\$_\$;

CREATE OR REPLACE FUNCTION func_insert_history_text() RETURNS TRIGGER
    LANGUAGE plpgsql
    AS \$_\$

    DECLARE
      table_name varchar;

    BEGIN
      table_name := 'history_text_' || to_char(to_timestamp(NEW.clock),'MM_YYYY');
      EXECUTE format('INSERT INTO %I (itemid, clock, value, ns) values  (\$1,\$2,\$3,\$4)', table_name) USING  NEW.itemid, NEW.clock, NEW.value, NEW.ns;
      RETURN NULL;
    END;
\$_\$;

CREATE OR REPLACE FUNCTION func_insert_history_uint() RETURNS TRIGGER
    LANGUAGE plpgsql
    AS \$_\$

    DECLARE
      table_name varchar;

    BEGIN
      table_name := 'history_uint_' || to_char(to_timestamp(NEW.clock),'MM_YYYY');
      EXECUTE format('INSERT INTO %I (itemid,clock,value,ns) values (\$1,\$2,\$3,\$4)', table_name) USING  NEW.itemid, NEW.clock, NEW.value, NEW.ns;
      RETURN NULL;
    END;
\$_\$;
};

my $triggers = "
CREATE TRIGGER insert_history_log_trigger BEFORE INSERT ON history_log FOR EACH ROW EXECUTE PROCEDURE func_insert_history_log();
CREATE TRIGGER insert_history_str_trigger BEFORE INSERT ON history_str FOR EACH ROW EXECUTE PROCEDURE func_insert_history_str();
CREATE TRIGGER insert_history_text_trigger BEFORE INSERT ON history_text FOR EACH ROW EXECUTE PROCEDURE func_insert_history_text();
CREATE TRIGGER insert_history_trigger BEFORE INSERT ON history FOR EACH ROW EXECUTE PROCEDURE func_insert_history();
CREATE TRIGGER insert_history_uint_trigger BEFORE INSERT ON history_uint FOR EACH ROW EXECUTE PROCEDURE func_insert_history_uint();
";

  open($fd, '>', "$data->{'ZABBIX_PATH'}/$data->{'ZABBIX_FN_FILE'}")
        or die ("Error, Couldn't open file [$data->{'ZABBIX_PATH'}/$data->{'ZABBIX_FN_FILE'}] for reading");

  print $fd $plpgsql;
  print $fd $functions;
  print $fd $triggers;

  print $fd "COMMIT;";
  close($fd);
}

sub replace_dates($){
  my $string               = $_[0];
  my ($year, $month, $day) = Today();
  my $days_in_month        = Days_in_Month($year, $month);
  my $epoch_init           = Date_to_Time($year, $month, 1, 0, 0, 0);
  my $epoch_end            = Date_to_Time($year, $month, $days_in_month, 23, 59, 59);

  $string =~ s/_MM_YY/sprintf("_%02d_%d",$month,$year)/ge;
  $string =~ s/_EPOCH_INIT_/$epoch_init/g;
  $string =~ s/_EPOCH_END_/$epoch_end/g;

  return $string;
}

sub move_files($){
  my $data = $_[0];
  my $gzipped = $data->{"ZABBIX_TMP_FILE"};

  print "- Compressing and moving files ...\n";
  $gzipped =~ s/\.tmp/\.gz/;
  gzip $data->{"ZABBIX_TMP_FILE"} => $gzipped;

  if ( !move($data->{"ZABBIX_FILE"},$data->{"ZABBIX_FILE_OLD"}) ){
    die("ERROR: There was not possible rename $data->{'ZABBIX_FILE'} to $data->{'ZABBIX_FILE_OLD'}");
  }

  if ( !move($gzipped, $data->{"ZABBIX_FILE"}) ){
    die("ERROR: There was not possible move $gzipped to $data->{'ZABBIX_FILE'}");
  }
}
