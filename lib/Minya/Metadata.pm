package Minya::Metadata;
use strict;
use warnings;
use utf8;
use Minya::Util qw(slurp);

use Moo;

has [qw(name version abstract perl_version author license)] => (
    is => 'lazy',
);

has source => (
    is => 'rw',
    required => 1,
);

no Moo;

# Taken from Module::Install::Metadata
sub _build_name {
    my ($self) = @_;

    if (
        slurp($self->source) =~ m/
        ^ \s*
        package \s*
        ([\w:]+)
        \s* ;
        /ixms
    ) {
        my ($name, $module_name) = ($1, $1);
        $name =~ s{::}{-}g;
        return wantarray ? ($name, $module_name) : $name;
    } else {
        die("Cannot determine name from @{[ $self->source ]}\n");
    }
}

sub _build_abstract {
    my ($self) = @_;
    require ExtUtils::MM_Unix;
    bless( { DISTNAME => $self->name }, 'ExtUtils::MM_Unix' )->parse_abstract($self->source);
}

sub _build_version {
    my ($self) = @_;
    require ExtUtils::MM_Unix;
    ExtUtils::MM_Unix->parse_version($self->source);
}


sub _extract_perl_version {
    if (
        $_[0] =~ m/
        ^\s*
        (?:use|require) \s*
        v?
        ([\d_\.]+)
        \s* ;
        /ixms
    ) {
        my $perl_version = $1;
        $perl_version =~ s{_}{}g;
        return $perl_version;
    } else {
        return;
    }
}
 
sub _build_perl_version {
    my ($self) = @_;

    my $perl_version = _extract_perl_version(slurp($self->source));
    if ($perl_version) {
        return $perl_version;
    } else {
        return;
    }
}

sub _build_author {
    my ($self) = @_;

    my $content = slurp($self->source);
    if ($content =~ m/
        =head \d \s+ (?:authors?)\b \s*
        ([^\n]*)
        |
        =head \d \s+ (?:licen[cs]e|licensing|copyright|legal)\b \s*
        .*? copyright .*? \d\d\d[\d.]+ \s* (?:\bby\b)? \s*
        ([^\n]*)
    /ixms) {
        my $author = $1 || $2;
 
        # XXX: ugly but should work anyway...
        if (eval "require Pod::Escapes; 1") { ## no critics.
            # Pod::Escapes has a mapping table.
            # It's in core of perl >= 5.9.3, and should be installed
            # as one of the Pod::Simple's prereqs, which is a prereq
            # of Pod::Text 3.x (see also below).
            $author =~ s{ E<( (\d+) | ([A-Za-z]+) )> }
            {
                defined $2
                ? chr($2)
                : defined $Pod::Escapes::Name2character_number{$1}
                ? chr($Pod::Escapes::Name2character_number{$1})
                : do {
                    warn "Unknown escape: E<$1>";
                    "E<$1>";
                };
            }gex;
        }
            ## no critic.
        elsif (eval "require Pod::Text; 1" && $Pod::Text::VERSION < 3) {
            # Pod::Text < 3.0 has yet another mapping table,
            # though the table name of 2.x and 1.x are different.
            # (1.x is in core of Perl < 5.6, 2.x is in core of
            # Perl < 5.9.3)
            my $mapping = ($Pod::Text::VERSION < 2)
                ? \%Pod::Text::HTML_Escapes
                : \%Pod::Text::ESCAPES;
            $author =~ s{ E<( (\d+) | ([A-Za-z]+) )> }
            {
                defined $2
                ? chr($2)
                : defined $mapping->{$1}
                ? $mapping->{$1}
                : do {
                    warn "Unknown escape: E<$1>";
                    "E<$1>";
                };
            }gex;
        }
        else {
            $author =~ s{E<lt>}{<}g;
            $author =~ s{E<gt>}{>}g;
        }
        return $author;
    } else {
        warn "Cannot determine author info from $_[0]\n";
        return;
    }
}


#Stolen from M::B
sub _extract_license {
    my $pod = shift;
    my $matched;
    return __extract_license(
        ($matched) = $pod =~ m/
            (=head \d \s+ L(?i:ICEN[CS]E|ICENSING)\b.*?)
            (=head \d.*|=cut.*|)\z
        /xms
    ) || __extract_license(
        ($matched) = $pod =~ m/
            (=head \d \s+ (?:C(?i:OPYRIGHTS?)|L(?i:EGAL))\b.*?)
            (=head \d.*|=cut.*|)\z
        /xms
    );
}
 
sub __extract_license {
    my $license_text = shift or return;
    my @phrases      = (
        '(?:under )?the same (?:terms|license) as (?:perl|the perl (?:\d )?programming language)' => 'Perl_5', 1,
        '(?:under )?the terms of (?:perl|the perl programming language) itself' => 'Perl_5', 1,
        'Artistic and GPL'                   => 'Perl_5',       1,
    );
    while ( my ($pattern, $license, $osi) = splice(@phrases, 0, 3) ) {
        $pattern =~ s#\s+#\\s+#gs;
        if ( $license_text =~ /\b$pattern\b/i ) {
            return $license;
        }
    }
    return '';
}

sub _build_license {
    my ($self) = @_;

    if (my $license = _extract_license(slurp($self->source))) {
        return $license;
    } else {
        warn "Cannot determine license info from $_[0]\n";
        return 'unknown';
    }
}

1;

