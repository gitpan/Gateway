# config.al -- Configuration file parsing.  -*- perl -*-
# $Id: config.al,v 0.1 1997/12/30 16:45:20 eagle Exp $
#
# Copyright 1997 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.  This is a News::Gateway module and
# requires News::Gateway to be used.

package News::Gateway;

############################################################################
# Methods
############################################################################

# Parses a single line, splitting it on whitespace, and returns the
# resulting array.  Double quotes are supported for arguments that have
# embedded whitespace, and backslashes inside double quotes escape the next
# character (whatever it is).  Any text outside of double quotes is
# automatically lowercased (to support directives in either case), but
# anything inside quotes is left alone.  We can't use Text::ParseWords
# because it's too smart for its own good.
sub config_parse {
    my ($self, $line) = @_;
    my (@args, $snippet);
    while ($line ne '') {
        $line =~ s/^\s+//;
        $snippet = '';
        while ($line !~ /^\s/ && $line ne '') {
            if (index ($line, '"') == 0) {
                $line =~ s/^\"(([^\"\\]|\\.)+)\"//
                    or $self->error ("Parse error in '$line'");
                my $tmp = $1;
                $tmp =~ s/\\(.)/$1/g;
                $snippet .= $tmp;
            } else {
                $line =~ s/^([^\"\s]+)//;
                $snippet .= lc $1;
            }
        }
        push (@args, $snippet);
    }
    @args;
}

# Parses a single configuration line, breaking up the arguments using
# parse_line and then passing them on to the registered callback for that
# directive.  If no callback is registered, we error, which should hopefully
# give us the right error message in all cases.
sub config_line {
    my ($self, $line) = @_;
    my @line = $self->config_parse ($line);
    my $method = $$self{confhooks}{$line[0]};
    unless (defined $method) {
        $self->error ("Unknown configuration directive $line[0]");
    }
    $self->$method (@line);
}

# Reads in a configuration file, taking either a scalar or a reference to a
# file glob or file handle.  Blank lines and lines beginning with # are
# ignored.  Each valid directive is passed to parse_config_line for
# processing (this separation is so that other programs can call
# read_config_line separately and just pass it a line of text).  A line
# ending in a backslash is considered to be continued on the next line.
sub config_file {
    my ($self, $config) = @_;
    unless (ref $config) {
        open (CONFIG, $config)
            or $self->error ("Cannot open file $config: $!");
        $config = \*CONFIG;
    }
    local $_;
    while (<$config>) {
        next if /^\s*\#/;
        next if /^\s*$/;
        s/^\s+//;
        s/\s+$//;
        while (/\\$/) {
            my $next = <$config>;
            $next =~ s/^\s+/ /;
            $next =~ s/\s+$//;
            s/\\$/ $next/;
        }
        $self->config_line ($_);
    }
}

1;
