use strict;
use warnings;

use Test::More;
use Git::Wrapper::Plus::Tester;
use Git::Wrapper::Plus::Support;

use Test::Fatal;
use Test::DZil qw( simple_ini );
use Dist::Zilla::Util::Test::KENTNL 1.003001 qw( dztest );

my $test = dztest();
$test->add_file( 'Changes', <<'EOF');
Example changes file

{{$NEXT}}
  First release
EOF
$test->add_file( 'dist.ini',
  simple_ini( { version => '0.01' }, ['GatherDir'], [ 'Git::NextRelease', { time_zone => 'UTC', default_branch => 'master' } ] )
);
$test->add_file( 'lib/E.pm', q[] );

my $t = Git::Wrapper::Plus::Tester->new( repo_dir => $test->tempdir );
my $s = Git::Wrapper::Plus::Support->new( git => $t->git );

$t->run_env(
  sub {

    my $git = $t->git;

    if ( not $s->supports_behavior('can-checkout-detached') ) {
      plan skip_all => 'This version of Git cannot checkout detached heads';
      return;
    }
    if ( not $s->supports_command('init-db') ) {
      plan skip_all => 'This version of Git cannot init-db';
      return;
    }
    if ( not $s->supports_command('update-index') ) {
      plan skip_all => 'This version of Git cannot update-index';
      return;
    }

    my $excp = exception {
      $git->init_db();
      $git->add('Changes');
      $git->add('dist.ini');
      $git->add('lib/E.pm');
      local $ENV{'GIT_COMMITTER_DATE'} = '1388534400 +1300';
      $git->commit( '-m', 'First Commit' );
      $test->tempdir->child('Changes')->spew_raw('Sample modification');
      $git->update_index('Changes');
      local $ENV{'GIT_COMMITTER_DATE'} = '1388534500 +1300';
      $git->commit( '-m', 'Second commit' );
      $git->checkout('HEAD^1');
    };
    is( $excp, undef, 'Git::Wrapper test preparation did not fail' )
      or diag $excp;

    $test->build_ok;
    for my $file ( @{ $test->builder->files } ) {
      next if $file->name ne 'Changes';
      like( $file->encoded_content, qr/0.01\s+2014-01-01\s+00:01:40/, "Specified commit timestamp in changelog" );
    }
    note explain $test->builder->log_messages;
  }
);
done_testing;
