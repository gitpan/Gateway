# mungeids.al -- Munge message IDs for better threading.  -*- perl -*-
# $Id: mungeids.al,v 0.2 1998/02/19 08:43:04 eagle Exp $
#
# Copyright 1998 by Russ Allbery <rra@stanford.edu>
# Based on code by Christopher Davis <ckd@loiosh.kei.com>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.  This is a News::Gateway module and
# requires News::Gateway to be used.

# @@ Interface:  []

package News::Gateway;

############################################################################
# Post rewrites
############################################################################

# Munge the Message-ID header and all message IDs in the References header
# to begin with the newsgroup name to which they were posted and a /.  This
# is so that the same message sent to multiple lists won't cause collisions,
# so that two gateways of the same list to different groups won't collide,
# and so that despite the fact that we're changing the incoming message IDs
# from what other people on the list will see, messages should hopefully
# still thread.
#
# Since the mailtonews module does magic with In-Reply-To to migrate things
# into References, it should run first; we don't deal with In-Reply-To here.
# We also want to already have the Newsgroups header.
sub mungeids_mesg {
    my $self = shift;

    # Figure out what prefix to use.
    my @prefix = split (/,/, $$self{article}->header ('newsgroups'));
    $prefix = join ('/', (sort @prefix), '');

    # Fix up the message ID, generating one if we don't have one.
    my $messageid = $$self{article}->header ('message-id');
    if ($messageid) {
        $messageid =~ s/^</<$prefix/;
        $$self{article}->set_headers ('message-id' => $messageid);
    } else {
        $$self{article}->add_message_id ($prefix);
    }

    # Munge all message IDs in the References header which weren't already
    # munged, if there is such a header.  Note that we have to then fold the
    # References header since there is often a line length limit on headers
    # in the news server.
    my $references = $$self{article}->header ('references');
    if ($references) {
        @references = split (' ', $references);
        my $length = 4;
        $references = '';
        for (@references) {
            s/^</<$prefix/ unless /^<$prefix/;
            $length += 1 + length $_;
            $references .= ($length < 72 ? ' ' : "\n\t") . $_;
            $length = length $_ if ($length >= 72);
        }
        $references =~ s/^\s+//;
        $$self{article}->set_headers (references => $references);
    }
    undef;
}

1;
