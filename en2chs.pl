#!/usr/bin/perl 

use strict;
use warnings;

my $robot = Translater->new;
my $words = $robot->en2chs( $ARGV[0] );
print $words if ($words);

#
# Class Translator
#
package Translater;

use strict;
use warnings;
use LWP::UserAgent;
use HTML::TokeParser;
use URI::Escape;
use Carp qw(confess);
use IO::Scalar;

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->_init;
    return $self;
}

sub _init {
    my $self = shift;
    $self->{browser} = LWP::UserAgent->new;
    $self->{browser}->timeout(60);
    $self->{browser}->env_proxy;
    $self->{_url} = "http://dict.youdao.com/search?q=";
}

sub en2chs {
    my ( $self, $word ) = @_;
    my $buffer;

    $word = uri_escape($word);
    my $response = $self->{browser}->get( $self->{_url} . $word );
    confess "Cannot connect to Youdao " . $self->{browser}->status_line
      unless ( $response->is_success );
    my $content = $response->content;

    $self->{_io} = IO::Scalar->new( \$buffer );
    $self->_parse_html( \$content );
    return $buffer;
}

sub _parse_html {
    my ( $self, $ctxt_ref ) = @_;

    my $stream = HTML::TokeParser->new($ctxt_ref);
    while ( my $token = $stream->get_token ) {
        if (    $token->[0] eq 'S'
            and $token->[1] eq 'div'
            and exists $token->[2]{id}
            and $token->[2]{id} eq 'phrsListTab' )
        {
            $self->_get_close_mean( $stream, $token );
        }
    }
}

#
# 1.  get n./vt./vi.
# 2.  get the number of the translation
# 3.  get the translation words
#
sub _get_close_mean {
    my ( $self, $stream, $token ) = @_;
    while ( $token = $stream->get_token ) {
        if ( $token->[0] eq "S" and $token->[1] eq "ul" )
        {
            while ( $token = $stream->get_token ) {
                return if ( $token->[0] eq "E" and $token->[1] eq "ul" );

                if ( $token->[0] eq "S" and $token->[1] eq "li" ) {
                    $token = $stream->get_token;
                    $self->{_io}->print("$token->[1]\n");
                }
            }
        }
    }
}

