package AlignmentFactory;

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

  my $registry = 'Bio::EnsEMBL::Registry';
  $registry->load_all($registry_file);

  my $gtreea = $registry->get_adaptor($domain, 'compara', 'GeneTree');
  my @trees = @{ $gtreea->fetch_all(-tree_type => 'tree') };

  for my $gt (@trees) {
    my $name = $gt->stable_id;
    next if not $name;
    my $input = {
      name => $name,
      root_id => $gt->root_id,
    };
    $self->dataflow_output_id($input, 2);
  }
}

1;
