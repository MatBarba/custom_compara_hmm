package HMMBuild;

use v5.14.00;
use strict;
use warnings;
use Carp;
use autodie qw(:all);

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use base qw/Bio::EnsEMBL::Hive::Process/;

sub run {
  my ($self) = @_;

  my $aln = $self->param('alignment_file');
  
  my $hmm = $aln;
  $hmm =~ s/\.st.$/.hmm/;

  my $cmd_output = `hmmbuild $hmm $aln`;
  unlink $aln;

  $self->dataflow_output_id({ hmm_file => $hmm }, 2);
}

1;
