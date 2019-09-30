package AlignmentExport;

use v5.14.00;
use strict;
use warnings;
use Carp;
use autodie qw(:all);

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use base qw/Bio::EnsEMBL::Hive::Process/;

sub run {
  my ($self) = @_;

  my $registry_file = $self->param('registry');
  my $domain = $self->param('domain');
  my $dir = $self->param('dir');
  my $root_id = $self->param('root_id');
  my $name = $self->param('name');

  my $registry = 'Bio::EnsEMBL::Registry';
  $registry->load_all($registry_file);

  my $aln_dir = "$dir/$name";
  my $aln_file = "$aln_dir/hmmer.sto";

  mkdir $aln_dir if not -s $aln_dir;

  my $gtreea = $registry->get_adaptor($domain, 'compara', 'GeneTree');
  my $tree = $gtreea->fetch_by_root_id($root_id);
  $tree->print_alignment_to_file($aln_file, 'stockholm', 1);

  $self->dataflow_output_id({alignment_file => $aln_file}, 2);
}

1;
