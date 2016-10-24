package Snow::Lua::SyntaxStringer;
use strict;
use warnings;

use feature 'say';

use Carp;




sub new {
	my ($class, %opts) = @_;
	my $self = bless {}, $class;
	return $self
}



sub to_string {
	my ($self, $syntax_tree) = @_;

	$self->{syntax_tree} = $syntax_tree;
	return $self->to_string_block($self->{syntax_tree});
}

sub to_string_block {
	my ($self, $block) = @_;

	my $text = '';
	foreach my $statement (@$block) {
		$text .= $self->to_string_statement($statement) . "\n";
	}

	return $text . "\n";
}

sub to_string_statement {
	my ($self, $statement) = @_;

	if ($statement->{type} eq 'empty_statement') {
		return ";"
	} elsif ($statement->{type} eq 'break_statement') {
		return "break"
	} elsif ($statement->{type} eq 'goto_statement') {
		return "goto $statement->{identifier}"
	} else {
		die "unimplemented statement type $statement->{type}";
	}
}



1;
