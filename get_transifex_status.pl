#!/volume/perl/bin/perl
# Author : andres-mancera (October 2014)
#---------------------------------------

use Getopt::Long;
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
my @config_file_info;
my @coursera_courses;
my @course_details;
my $file_name;
my $i;

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
  if ( /^(coursera-.*)$/ ) 
  {
    print ("  --> $1\n");
    push (@coursera_courses, $1);
  } 
}
print ("--Done!\n\n");

# Use Transifex's API to get information about the courses specified in the config file
print ("Getting course details from Transifex...\n");
for ( $i=0; $i<=$#coursera_courses; $i++ )
{ 
  print ("  --> $coursera_courses[$i]\n");
  @course_details = `curl -s -S -L -k --user '$user:$pwd' -X GET 'https://www.transifex.com/api/2/project/$coursera_courses[$i]/?details'`;
  $file_name = $coursera_courses[$i] . ".txt";
  open (COURSE_DETAILS, ">$file_name") || die "Can't open new file: $!\n";
  print COURSE_DETAILS @course_details;
}
print ("--Done!\n\n");
