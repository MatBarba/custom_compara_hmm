package SQLCounter;

use v5.14.00;
use strict;
use warnings;
use Carp;
use autodie qw(:all);
use Log::Log4perl qw( :easy ); 
Log::Log4perl->easy_init($INFO); 
my $logger = get_logger(); 
use JSON;
use List::Util qw( uniq first );

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use base qw/Bio::EnsEMBL::Hive::Process/;

sub run {
    my ($self) = @_;
  
    my $species   = $self->param('species');
    my $query     = $self->param('query');
    my $query_key = $self->param('query_key');
    my $name      = $self->param('name');
    
    my $registry_file = $self->param('registry');
    my $registry = 'Bio::EnsEMBL::Registry';
    $registry->load_all($registry_file);
    my $va = $registry->get_adaptor($species, 'variation', 'variation');
    my $dbc = $va->dbc;
   
    # Actual work
    my $counts;
    if ($self->param('debug')) {
      $counts = { VBP_source => 10 };
    }  else {
      $counts = $self->count_db($dbc, $query, $query_key);
    }
    $self->param('counts', $counts);
}

sub write_output {
  my ($self) = @_;

  my $counts = $self->param('counts');
  for my $source (keys %$counts) {
    my $counted = {
      species => $self->param('species'),
      name    => $self->param('name'),
      source  => $source,
      count   => $counts->{$source},
    };
    $self->dataflow_output_id($counted, 1);
  }
}

###############################################################################
sub count_db {
  my ($self, $dbc, $query, $key) = @_;
  
  my $sth = $dbc->prepare($query);
  $sth->execute();
  my $res = $sth->fetchall_hashref($key);
  $dbc->disconnect_if_idle();
  my %simpler_res = map { $_ => $res->{$_}->{count} } keys %$res;
  return \%simpler_res;
}

1;
