package VBHMM_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.5;

use File::Spec::Functions qw(catdir);
use FindBin;

sub pipeline_wide_parameters {
    my ($self) = @_;

    return {
        %{$self->SUPER::pipeline_wide_parameters},
        'debug' => $self->o('debug'),
    };
}

sub default_options {
  my ($self) = @_;
  return {
    %{ $self->SUPER::default_options() },

    pipeline_name => 'vb_hmmbuilder',
    email => $ENV{USER} . '@ebi.ac.uk',
    
    align_dir => $self->o('align_dir'),
    domain => 'vb',

    debug => 0,
  };
}

sub hive_meta_table {
  my ($self) = @_;
  return {
    %{$self->SUPER::hive_meta_table},       # here we inherit anything from the base class
    'hive_use_param_stack'  => 1,           # switch on the new param_stack mechanism
  };
}

sub pipeline_analyses {
  my ($self) = @_;

  return
  [
    {
      -logic_name => 'Start',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids  => [{}],
      -flow_into  => {
        '1' => 'Alignment_factory',
      },
      -rc_name    => 'default',
      -meadow_type       => 'LOCAL',
    },

    {
      -logic_name => 'Alignment_factory',
      -module            => 'AlignmentFactory',
      -parameters => {
        registry => $self->o('reg_conf'),
        domain => $self->o('domain'),
      },
      -rc_name    => 'normal',
      -meadow_type       => 'LSF',
      -flow_into  => {
        '2' => 'Alignment_export',
      },
    },
    {
      -logic_name => 'Alignment_export',
      -module     => 'AlignmentExport',
      -parameters => {
        registry => $self->o('reg_conf'),
        dir => $self->o('align_dir'),
        domain => $self->o('domain'),
      },
      -flow_into  => {
        '2' => 'HMM_build',
      },
      -analysis_capacity => 100,
      -batch_size => 10,
      -rc_name    => 'normal',
      -meadow_type       => 'LSF',
    },

    {
      -logic_name => 'HMM_build',
      -module     => 'HMMBuild',
      -meadow_type       => 'LSF',
      -analysis_capacity => 100,
      -batch_size => 10,
      -rc_name    => 'normal',
    },

  ];
}

sub resource_classes {

  my ($self) = @_;
  
  my $reg_requirement = '--reg_conf ' . $self->o('reg_conf');

  return {
    'default'           => {
      'LOCAL' => ['', $reg_requirement],
    },
    'normal'            => {'LSF' => ['-q production-rh7 -M  1000 -R "rusage[mem=1000]"', $reg_requirement]},
    'bigmem'           => {'LSF' => ['-q production-rh7 -M  4000 -R "rusage[mem=4000]"', $reg_requirement]},
    'biggermem'           => {'LSF' => ['-q production-rh7 -M  16000 -R "rusage[mem=16000]"', $reg_requirement]},
  }
}

1;
