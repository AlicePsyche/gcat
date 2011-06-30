#!/usr/bin/env perl
# Toolkit for Evolutionary Analysis.
#
# An expandable toolkit written in the Perl programming language.
# TEA utilizes the BioPerl and EnsEMBL Perl API libraries for
# evolutionary comparative genomics analysis.
#
# Part of a PhD thesis entitled "Evolutionary Genomics of Organismal Diversity".
# 
# Created by Steve Moss
# gawbul@gmail.com
# 
# C/o Dr David Lunt and Dr Domino Joyce,
# Evolutionary Biology Group,
# The University of Hull.

# make life easier
use warnings;
use strict;

# add includes
use Parallel::ForkManager;
use Time::HiRes qw(gettimeofday);
use TEA::Interface::Logging qw(logger);
use TEA::Data::Parsing;
use TEA::Data::Output;
use TEA::Analysis::Descriptive;
use TEA::Stats::RStats;
use Cwd;
use File::Spec;

# first get the arguments
my $num_args = $#ARGV + 1;
my @inputs = @ARGV;
chomp(@inputs);

# check arguments list is sufficient
unless ($num_args >= 4) {
	print("This script requires at least four input arguments, for the feature, start and end range and organism(s) you wish to download the information for.\n");
	exit;
}

# set start time
my $start_time = gettimeofday;

# split inputs
my $feature = shift(@inputs);
my $start_range = shift(@inputs);
my $end_range = shift(@inputs);
my @organisms = @inputs;

# setup fork manager
my $pm = new Parallel::ForkManager(8);

# traverse each organism and parse the fasta
foreach my $org (@organisms) {
	# start fork manager
	my $pid = $pm->start and next;

	print "Going to retrieve gene IDs and intron sequence for given range for $org...\n";
	
	my @data = &TEA::Data::Parsing::get_Gene_IDs_from_Feature($feature, $org, $start_range, $end_range);
	
	my @sorted_data = sort( {$a->[1] <=> $b->[1];} @data);

	# get root directory and setup data path
	my $dir = getcwd();

	# setup file path
	my $filename = File::Spec->catfile($dir, "data", $org, "gids_for_range.csv");

	# setup CSV
	my $csv = Text::CSV_XS->new ({ binary => 1, eol => $/ });
  	
  	# open file
  	open my $fh, ">", "$filename" or die "$filename: $!";
 	
 	# add the header line
 	$csv->print ($fh, [$org . '.gid', $org . '.intron_size', $org . '.intron_seq']); 	
	
	# iterate through data and print to file 		
	for my $gdat (@sorted_data) {
	 	$csv->print ($fh, [$gdat->[0], $gdat->[1], $gdat->[2]]); 	
	}
	
	# close the CSV
	close $fh or die "$filename: $!";
	print "Outputted gene IDs for given range to $filename\n"; 	
		
	# finish fork
	$pm->finish;
}

# wait for all processes to finish
$pm->wait_all_children;

# set end time and calculate time elapsed
my $end_time = gettimeofday;
my $elapsed = $end_time - $start_time;

# let user know we have finished
printf "Finished in %0.3f!\n", $elapsed;