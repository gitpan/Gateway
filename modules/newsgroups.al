# newsgroups.al -- Logic to build Newsgroups header.  -*- perl -*-
# $Id: newsgroups.al,v 0.7 1997/10/24 06:11:11 eagle Exp $
#
# Copyright 1997 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.  This is a News::Gateway module and
# requires News::Gateway to be used.

# @@ Interface:  ['group']

package News::Gateway;

############################################################################
# Option settings
############################################################################

# We take one optional argument, the newsgroup this instance of the gateway
# is associated with.  If this argument is present, then the rewrite fails
# if it builds the Newsgroups header from the To and Cc headers and the
# instance group isn't the first group on the resulting list.
#
# This is designed to handle cases where multiple e-mail addresses forward
# to the same program and result in a crosspost.  We don't want to crosspost
# multiple messages between the groups, just one, and the one message that
# will go through under this scheme is the one sent to the address that's
# first in the list of addresses in the To and Cc headers.
#
# Note that in this case, it will be necessary to set the "main" group
# differently depending on what address the mail message arrived via.  In
# other words, in a mail to news setup, each separate address will need to
# pass a command-line argument to the script specifying which address the
# message came through, and the script will have to pass that along to this
# module.
sub newsgroups_init {
    my $self = shift;
    $$self{newsgroups}{main} = shift;
}


############################################################################
# Configuration directives
############################################################################

# Takes a pattern in the form /<regex>/ and transforms it into an anonymous
# sub that takes one argument and returns true in a scalar context if the
# regex matches that argument and false otherwise.  In an array context, the
# anonymous sub returns the list of substrings matched by parens, just like
# with a normal match, so this can potentially be used to extract newsgroups
# out of an address eventually.  This is not currently implemented in the
# rest of this module.  Returns a ref to the anonymous sub.
sub newsgroups_glob {
    my ($self, $regex) = @_;
    $regex = substr ($regex, 1, -1);
    my $glob = eval "sub { \$_[0] =~ /$regex/ }";
    if ($@) { $self->error ("Invalid regex /$regex/: $@") }
    $glob;
}

# We take four forms of group directives designating which groups we are
# allowed to crosspost to:
#
#    group <newsgroup> [<address> | /<pattern>/]
#    group /<pattern>/
#    group <file> /<pattern>/
#
# The first adds just that particular group and associates any address found
# in the To or Cc headers that matches <address> or <pattern> with that
# group.  If there is no Newsgroups header in the post, one will be
# constructed if possible from the addresses in the To and Cc headers and
# these associations.  The second allows crossposts from all groups matching
# <pattern> and the third allows crossposts to all groups listed in the file
# <file> that match <pattern>.
sub newsgroups_conf {
    my ($self, @args);
    ($self, undef, @args) = @_;

    # If we haven't already initialized our data structure, do so now.
    # groups is a hash with each group to which crossposting is allowed
    # entered as a key.  addresses is a hash associating literal addresses
    # with groups.  patterns and grouplist are parallel arrays; patterns are
    # anonymous pattern match subs associated with the corresponding group
    # in grouplist.  Finally, masks are anonymous pattern match subs
    # specifying newsgroups to which we can crosspost.
    unless (exists $$self{newsgroups}{groups}) {
        $$self{newsgroups}{groups}    = {};
        $$self{newsgroups}{addresses} = {};
        $$self{newsgroups}{patterns}  = [];
        $$self{newsgroups}{grouplist} = [];
        $$self{newsgroups}{masks}     = [];
    }

    # Now we have to figure out what sort of argument we've been given.  If
    # the first argument ends with a /, we assume it's a pattern.
    # Otherwise, if the first argument starts with a /, we assume it's a
    # file containing a list of groups.  If neither of those is true, but
    # the second argument begins with a /, we assume it's a single newsgroup
    # associated with an address pattern.  Finally, if none of the above are
    # true, we assume it's a newsgroup, possibly associated with a literal
    # address.
    if ($args[0] =~ m%/$%) {
        my $glob = $self->newsgroups_glob ($args[0]);
        push (@{$$self{newsgroups}{masks}}, $glob);
    } elsif ($args[0] =~ m%^/%) {
        my $groups = $$self{newsgroups}{groups};
        my $glob = $self->newsgroups_glob ($args[1]);
        open (GROUPS, "$args[0]")
            or $self->error ("Can't open group file $args[0]: $!");
        local $_;
        while (<GROUPS>) {
            my ($group) = split (' ', $_);
            $$self{newsgroups}{groups}{$_} = 1 if &$glob ($group);
        }
        close GROUPS;
    } elsif (index ($args[1], '/') == 0) {
        my $group = $args[0];
        my $glob = $self->newsgroups_glob (lc $args[1]);
        push (@{$$self{newsgroups}{patterns}}, $glob);
        push (@{$$self{newsgroups}{grouplist}}, $group);
        $$self{newsgroups}{groups}{$group} = 1;
    } elsif ($args[1]) {
        my $group = $args[0];
        $$self{newsgroups}{addresses}{lc $args[1]} = $group;
        $$self{newsgroups}{groups}{$group} = 1;
    } else {
        $$self{newsgroups}{groups}{$args[0]} = 1;
    }
}


############################################################################
# Post checks
############################################################################

# Make sure that we're allowed to crosspost to all the groups that we're
# crossposting to.  If the Newsgroups header doesn't exist and we have any
# patterns or addresses recorded, attempt to build one.
sub newsgroups_mesg {
    my $self = shift;
    my @groups = split (/,/, $$self{article}->header ('newsgroups'));
    if (@groups) {
      GROUP:
        for (@groups) {
            next if $$self{newsgroups}{groups}{$_};
            my $mask;
            for $mask (@{$$self{newsgroups}{masks}}) {
                next GROUP if &$mask ($_);
            }
            return "Invalid crossposted group $_";
        }
    } else {
        my $addresses = join (',', $$self{article}->header ('to'),
                              $$self{article}->header ('cc'));
        my @addresses = split (/(?:\s*,\s*)+/, $addresses);
        for (@addresses) {
            my ($address) = /<(\S+)>/;
            ($address) = split (' ', $_) unless $address;
            my $group = $$self{newsgroups}{addresses}{lc $address};
            if ($group) {
                push (@groups, $group);
            } else {
                my $patterns = $$self{newsgroups}{patterns};
                my $grouplist = $$self{newsgroups}{grouplist};
                for ($group = 0; $group < @$patterns; $group++) {
                    if (&{$$patterns[$group]} ($address)) {
                        push (@groups, $$grouplist[$group]);
                        last;
                    }
                }
            }
        }
        if (@groups) {
            my $main = $$self{newsgroups}{main};
            if ($main && $main ne $groups[0]) {
                if (grep { $_ eq $main } @groups) {
                    return 'Not primary instance';
                } else {
                    $$self{article}->set_headers (newsgroups => $main);
                }
            } else {
                my $groups = join (',', @groups);
                $$self{article}->set_headers (newsgroups => $groups);
            }
        }
    }
    undef;
}

1;
