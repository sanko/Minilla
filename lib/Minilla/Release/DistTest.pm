package Minilla::Release::DistTest;
use strict;
use warnings;
use utf8;

sub run {
    my ($self, $project, $opts) = @_;

    local $ENV{RELEASE_TESTING} = 1;
    my $work_dir = $project->work_dir();
    $work_dir->dist_test;
}

1;

