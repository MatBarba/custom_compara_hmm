#!/usr/env perl
use v5.14.00;
use strict;
use warnings;
use Carp;
use autodie qw(:all);
use Readonly;
use Getopt::Long qw(:config no_ignore_case);
use Log::Log4perl qw( :easy ); 
Log::Log4perl->easy_init($WARN); 
my $logger = get_logger(); 

use Bio::EnsEMBL::Registry;
use DBI;

###############################################################################
# MAIN
# Get command line args
my %opt = %{ opt_check() };

$logger->info("Load registry");
Bio::EnsEMBL::Registry->load_all($opt{registry}, 1);
my $ads = Bio::EnsEMBL::Registry->get_all_adaptors();
die scalar(@$ads) . " adaptors loaded" if scalar(@$ads) == 0;

print_alignments($opt{books});

sub print_alignments {
  my ($books_dir) = @_;

  my $gtreea = Bio::EnsEMBL::Registry->get_adaptor('vb', 'compara', 'GeneTree');
  my @trees = @{ $gtreea->fetch_all(-tree_type => 'tree') };
  my $total_trees = scalar(@trees);
  $logger->info( "$total_trees trees to export");

  my $n_trees = 0;
  for my $gt (@trees) {
    $n_trees++;
    $logger->info("$n_trees/$total_trees") if $n_trees % 1000 == 0;
    my $name = $gt->stable_id;
    if (not $name) {
#      $logger->warn("No name for tree " . $gt->toString);
      next;
    }
    my $aln_dir = "$books_dir/$name";
    my $aln_file = "$aln_dir/hmmer.sto";
    next if -s $aln_file;
    mkdir $aln_dir if not -s $aln_dir;
    $gt->print_alignment_to_file($aln_file, 'stockholm', 1);
  }
}

###############################################################################
# Parameters and usage
sub usage {
  my $error = shift;
  my $help = '';
  if ($error) {
    $help = "[ $error ]\n";
  }
  $help .= <<"EOF";
    Print all alignments from a compara db in stockholm format

    --registry <path> : path to the registry including compara
    --books <path     : path where the alignments will be printed
    
    --help            : show this help message
    --verbose         : show detailed progress
    --debug           : show even more information (for debugging purposes)
EOF
  print STDERR "$help\n";
  exit(1);
}

sub opt_check {
  my %opt = ();
  GetOptions(\%opt,
    "registry=s",
    "books=s",
    "help",
    "verbose",
    "debug",
  );

  usage()                if $opt{help};

  usage("Registry file needed") unless $opt{registry};
  usage("Books path needed") unless $opt{books};

  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

