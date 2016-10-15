package Snow::Lua::TokenParser;
use strict;
use warnings;

use feature 'say';

use Sugar::IO::File;




sub new {
	my ($class, %opts) = @_;
	my $self = bless {}, $class;

	if (defined $opts{file}) {
		$self->parse_file($opts{file});
	} elsif (defined $opts{text}) {
		$self->parse($opts{text});
	}

	return $self;
}

sub parse_file {
	my ($self, $filepath) = @_;

	$self->{filepath} = $filepath;
	
	my $text = Sugar::IO::File->new($filepath)->read;
	return $self->parse($text)
}


sub parse {
	my ($self, $text) = @_;

	say "got text: $text";
}



1;
