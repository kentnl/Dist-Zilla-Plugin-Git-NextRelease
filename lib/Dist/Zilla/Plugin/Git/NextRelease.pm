use strict;
use warnings;

package Dist::Zilla::Plugin::Git::NextRelease;

# ABSTRACT: Use time-stamp from Git instead of process start time.

use Moose;
extends 'Dist::Zilla::Plugin::NextRelease';

=head1 SYNOPSIS

This module acts as a moderately thin wrapper to L<< C<[NextRelease]>|Dist::Zilla::Plugin::NextRelease >>
so that the time-stamps produced are generated by asking C<git> for the time-stamp of the current branch.

If you always require a specific branch for generating time-stamps, it can be specified as a parameter.

    -[NextRelease]
    +[Git::NextRelease]

Optionally:

    +branch = master

This exists mostly because of my extensive use of L<< C<[Git::CommitBuild]>|Dist::Zilla::Plugin::Git::CommitBuild >>, to provide a commit series for both releases, and builds of all changes/commits in order to push them to Travis for testing. ( Mostly, because testing a build branch is substantially faster than testing a master that requires C<Dist::Zilla>, especially if you're doing "Fresh install" testing like I am. )

=cut

use Git::Wrapper::Plus;
use DateTime;

use String::Formatter 0.100680 stringf => {
  -as => '_format_version',

  input_processor => 'require_single_input',
  string_replacer => 'method_replace',
  codes           => {
    v => sub { $_[0]->zilla->version },
    d => sub {
      my $t = $_[0]->_git_timestamp;
      $t = $t->set_time_zone( $_[0]->time_zone );
      return $t->format_cldr( $_[1] ),;
    },
    t => sub { "\t" },
    n => sub { "\n" },
    E => sub { $_[0]->_user_info('email') },
    U => sub { $_[0]->_user_info('name') },
    T => sub {
      $_[0]->zilla->is_trial ? ( defined $_[1] ? $_[1] : '-TRIAL' ) : q[];
    },
    V => sub {
      $_[0]->zilla->version . ( $_[0]->zilla->is_trial ? ( defined $_[1] ? $_[1] : '-TRIAL' ) : q[] );
    },
  },
};

has 'branch' => (
  is         => ro =>,
  lazy_build => 1,
);
has _git_timestamp => (
  init_arg   => undef,
  is         => ro =>,
  lazy_build => 1,
);
has '_gwp' => (
  init_arg   => undef,
  is         => ro =>,
  lazy_build => 1,
);

sub _build__gwp {
  my ($self) = @_;
  return Git::Wrapper::Plus->new( q[] . $self->zilla->root );
}

sub _build_branch {
  my ($self) = @_;
  my $cb = $self->_gwp->branches->current_branch;
  if ( not $cb ) {
    $self->log_fatal(q[Cannot determine branch to get timestamp from when not on a branch]);
  }
  return $cb->name;
}

sub _build__git_timestamp {
  my ($self) = @_;
  my ( $branch, ) = $self->_gwp->branches->get_branch( $self->branch );
  if ( not $branch ) {
    $self->log_fatal( [ q[Branch %s does not exist], $self->branch ] );
  }
  my $sha1 = $branch->sha1;
  my ( $committer, ) = grep { $_ =~ /\Acommitter /msx } $self->_gwp->git->cat_file( 'commit', $sha1 );
  chomp $committer;
  if ( $committer =~ qr/\s+([0-9]+)\s+(\S+)$/ ) {
    return DateTime->from_epoch( epoch => $1, time_zone => $2 );
  }
  return $self->log_fatal( [ q[Could not parse timestamp and timezone from string <%s>], $committer ] );
}

sub section_header {
  my ($self) = @_;

  return _format_version( $self->format, $self );
}
__PACKAGE__->meta->make_immutable;
no Moose;

1;
