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

my %species_groups = (
  aedes => [
    qw(
    aedes_aegypti_lvpagwg
    aedes_albopictus
    ),
  ],
  culicinae => [
    qw(
    aedes_aegypti_lvpagwg
    aedes_albopictus
    culex_quinquefasciatus
    ),
  ],
  anopheles => [
    qw(
    anopheles_albimanus
    anopheles_arabiensis
    anopheles_atroparvus
    anopheles_christyi
    anopheles_coluzzii
    anopheles_culicifacies
    anopheles_darlingi
    anopheles_dirus
    anopheles_epiroticus
    anopheles_farauti
    anopheles_funestus
    anopheles_gambiae
    anopheles_maculatus
    anopheles_melas
    anopheles_merus
    anopheles_minimus
    anopheles_quadriannulatus
    anopheles_sinensis
    anopheles_stephensi
    )],
  culicidae => [
    qw(
    aedes_aegypti_lvpagwg
    aedes_albopictus
    culex_quinquefasciatus
    anopheles_albimanus
    anopheles_arabiensis
    anopheles_atroparvus
    anopheles_christyi
    anopheles_coluzzii
    anopheles_culicifacies
    anopheles_darlingi
    anopheles_dirus
    anopheles_epiroticus
    anopheles_farauti
    anopheles_funestus
    anopheles_gambiae
    anopheles_maculatus
    anopheles_melas
    anopheles_merus
    anopheles_minimus
    anopheles_quadriannulatus
    anopheles_sinensis
    anopheles_stephensi
    ),
  ],
  glossina => [
    qw(
    glossina_austeni
    glossina_brevipalpis
    glossina_fuscipes
    glossina_morsitans
    glossina_pallidipes
    glossina_palpalis
    ),
  ],
  
);

my $species_list = join(", ", sort keys %species_groups);

###############################################################################
# MAIN
# Get command line args
my %opt = %{ opt_check() };

$logger->info("Load registry");
Bio::EnsEMBL::Registry->load_all($opt{registry}, 1);
my $ads = Bio::EnsEMBL::Registry->get_all_adaptors();
die scalar(@$ads) . " adaptors loaded" if scalar(@$ads) == 0;

my $species = $species_groups{ $opt{species_group} };
die "Sorry, there is no species group defined for $opt{species_group}" if not $species;

# Get the correspondence via compara
$logger->info("Extract data");
my $trees_stats = compara_stats($species);
print_counts($trees_stats);

sub compara_stats {
  my ($species) = @_;

  my $genomedba = Bio::EnsEMBL::Registry->get_adaptor('vb', 'compara', 'GenomeDB');
  my $genea = Bio::EnsEMBL::Registry->get_adaptor('vb', 'compara', 'GeneMember');
  my $homoa = Bio::EnsEMBL::Registry->get_adaptor('vb', 'compara', 'Homology');
  
  my %dbs;
  $logger->info("Get genome_db data");
  for my $sp (@$species) {
    my ($genomedb) = @{ $genomedba->fetch_all_by_name($sp) };
    die("I can't find $sp in genome_db!") if not $genomedb;
    $dbs{$sp} = $genomedb;
  }

  my %counts;
  $logger->info("Count trees");
  for my $sp (@$species) {
    $logger->info("Count for $sp...");
    $counts{$sp} = {};

    my @genes = @{ $genea->fetch_all_by_GenomeDB($dbs{$sp}) };
    $logger->info(scalar(@genes) . " gene members to analyze");

    my $n = 0;
    for my $member (@genes) {
      print STDERR "." if ++$n % 10 == 0;
#      last if $n >= 5;
      my $n_homolog_genes = 0;
      my %homolog_species;

      my @homologies = @{ $homoa->fetch_all_by_Member($member) };
      for my $hom (@homologies) {
        for my $sp2 (@$species) {
          my @matcheds = @{ $hom->get_Member_by_GenomeDB($dbs{$sp2}) };
          for my $matched (@matcheds) {
            my $matched_species = $matched->genome_db->name;
            $homolog_species{$matched_species}++;
            $n_homolog_genes++;
          }
        }
      }
      next if $n_homolog_genes == 0;

      $counts{$sp}{$member->stable_id} = {
        genes => $n_homolog_genes,
        species => scalar(keys %homolog_species),
      };
    }
    say STDERR "";
  }

  return \%counts;
}

sub print_counts {
  my ($counts) = @_;

  for my $sp (sort keys %$counts) {
    for my $gene (keys %{ $counts->{$sp} }) {
      my @line = ($sp);
      push @line, $counts->{$sp}->{$gene}->{genes};
      push @line, $counts->{$sp}->{$gene}->{species};
      say join("\t", @line);
    }
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
    COMPARA STATS

    --registry <path> : path to the registry including compara
    --species_group <str> : Predefined species group (among $species_list)
    
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
    "species_group=s",
    "help",
    "verbose",
    "debug",
  );

  usage()                if $opt{help};

  usage("Species group needed") unless $opt{species_group};
  usage("Registry file needed") unless $opt{registry};

  Log::Log4perl->easy_init($INFO) if $opt{verbose};
  Log::Log4perl->easy_init($DEBUG) if $opt{debug};
  return \%opt;
}

__END__

