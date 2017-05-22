use strict;
use warnings;
use utf8;
use Test::More;
use Test::Requires 'Version::Next', 'CPAN::Uploader';
use lib "t/lib";
use Util;
use Minilla::Profile::ModuleBuild;
use Minilla::CLI::Release;
use Test::Output;

my $repo = tempdir();
{
    my $guard = pushd($repo);
    cmd('git', 'init', '--bare');
}

my $guard = pushd(tempdir());

Minilla::Profile::ModuleBuild->new(
    author => 'hoge',
    dist => 'Acme-Foo',
    module => 'Acme::Foo',
    path => 'Acme/Foo.pm',
    version => '0.01',
)->generate();
write_minil_toml('Acme-Foo');
git_init_add_commit();
git_remote('add', 'origin', "file://$repo");

{
    local $ENV{PERL_MM_USE_DEFAULT} = 1;
    local $ENV{PERL_MINILLA_SKIP_CHECK_CHANGE_LOG} = 1;
    local $ENV{FAKE_RELEASE} = 1;
    stdout_unlike {
        Minilla::CLI::Release->run(qw/--notest/);
    } qr/All tests successful/, 'notest option';
    pass 'released.';
}

done_testing;

