#!/volume/perl/bin/perl
# Author : andres-mancera (October 2014)
#---------------------------------------

use Getopt::Long;
use LWP::Simple;
use JSON qw( decode_json );
use Data::Dumper; 
use strict;
use warnings;

my %options;
GetOptions(
            'user=s'    => \$options{user},
            'pwd=s'     => \$options{pwd},
            'cfg=s'     => \$options{cfg_file}
);

if ( !defined $options{user} || !defined $options{pwd} ||  !defined $options{cfg_file} )
{
  print qq{
Please specify your Transifex username and password along with the confg file.
  $0 -user USER -pwd PWD -cfg CFG_FILE
};
  exit 0;
}

my $user        = $options{user};
my $pwd         = $options{pwd};
my $config_file = $options{cfg_file};
my (@config_file_info, @coursera_courses, @slugs);
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
my ($course_details, $file_name, $i, $decoded_course_json, $decoded_resource_json);
my ($slug_id, $resource_details, $translated_sum, $reviewed_sum, $untranslated_sum);
my ($reviewed_strings, $translated_strings, $untranslated_strings);
my ($translated, $reviewed, $course_name);

# Open the configuration file and read all the information about the courses
if ( open CONFIG_FILE, "$config_file" )
{
  print ("Opening configuration file :: $config_file\n\n");
}
else
{
  die ("Error while opening configuration file : $config_file!\n");
}
@config_file_info = <CONFIG_FILE>;
close (CONFIG_FILE);
print ("Parsing configuration file...\n");
foreach ( @config_file_info )
{
  if ( /^(coursera-.+)$/ ) 
  {
    print ("  --> $1\n");
    push (@coursera_courses, $1);
  }
}
print ("--Done!\n\n");

# Open the report file and append a timestamp
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$mday = sprintf("%02d", $mday);
$mon = $mon + 1;  #$mon is in the range 0..11
$mon = sprintf("%02d", $mon);
$year += 1900; # $year is the number of years since 1900
$file_name   = $year . "-" . $mon . "-" . $mday . "_status_report.txt";
open (REPORT, ">$file_name") || die "Can't open new report file: $!\n";

# Use Transifex's API to get information about the courses specified in the config file
print ("Getting course details from Transifex...\n");
for ( $i=0; $i<=$#coursera_courses; $i++ )
{ 
  $translated       = 0;
  $reviewed         = 0;
  $translated_sum   = 0;
  $reviewed_sum     = 0;
  $untranslated_sum = 0;
  print ("  --> $coursera_courses[$i]\n");
  $course_details = 
    `curl -s -S -L -k --user '$user:$pwd' -X GET 'https://www.transifex.com/api/2/project/$coursera_courses[$i]/?details'`;
  $decoded_course_json = decode_json( $course_details );
  #print Dumper $decoded_course_json->{'resources'};    # DEBUG only!
  @slugs = @{ $decoded_course_json->{'resources'} };
  foreach ( @slugs )
  {
    $slug_id        = $_->{'slug'};
    $resource_details = 
      `curl -s -S -L -k --user '$user:$pwd' -X GET 'https://www.transifex.com/api/2/project/$coursera_courses[$i]/resource/$slug_id/stats/es'`;
    $decoded_resource_json = decode_json( $resource_details );
    #print Dumper $decoded_resource_json;               # DEBUG only!
    $reviewed_strings       = $decoded_resource_json->{'reviewed'};
    $translated_strings     = $decoded_resource_json->{'translated_entities'};
    $untranslated_strings   = $decoded_resource_json->{'untranslated_entities'};
    $reviewed_sum           = $reviewed_sum + $reviewed_strings;
    $translated_sum         = $translated_sum + $translated_strings;
    $untranslated_sum       = $untranslated_sum + $untranslated_strings;
    print ("    --> slug_id=$slug_id :: translated=$translated_strings :: untranslated=$untranslated_strings :: reviewed=$reviewed_strings\n");
  }
  $translated   = int(100*$translated_sum/($translated_sum+$untranslated_sum));
  $reviewed     = int(100*$reviewed_sum/($translated_sum+$untranslated_sum));
  print ("    --> Course Total :: translated=$translated :: reviewed=$reviewed\n");
  $course_name  = $decoded_course_json->{'name'};
  print REPORT "COURSE NAME : $course_name\n";
  print REPORT "\tTRANSLATED : $translated%\n";
  print REPORT "\tREVIEWED   : $reviewed%\n\n";
}
print ("--Done!\n\n");

print ("Generating status report : $file_name\n");
close REPORT;
print ("--Done!\n\n");
