# mail.al -- Forward or reply to a submission.  -*- perl -*-
# $Id: mail.al,v 0.2 1997/09/15 02:48:34 eagle Exp $
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

# Actually bounces the message.  Don't do this except as a last resort.
sub mail_bounce {
    my ($self, $error) = @_;
    warn "$error\n";
    exit $FAILCODE;
}

# Used to handle some sort of fatal internal error.  This should *not* be
# used for errors in a post; rather, this is for local configuration errors,
# local system errors, and the like.  We attempt to generate a reply, giving
# them back their original message and the error message, and if we're
# unable to we bounce their message.
sub mail_error {
    my ($self, $error) = @_;
    my $article = $$self{article} or $self->mail_bounce ($error);
    my $to = $article->header ('reply-to') || $article->header ('from')
        or $self->mail_bounce ($error);
    my $reply = new News::Article;
    $reply->set_headers (to         => $to,
                         cc         => $$self{maintainer},
                         'reply-to' => $$self{maintainer},
                         subject    => 'failure notice',
                         precedence => 'junk');
    $reply->envelope ($$self{envelope}) if defined $$self{envelope};
    $reply->set_body (split (/\n/, <<"EOR"), '');
Hi.  I'm afraid that I was unable to post your message.  This is a fatal
error; I've given up.  A copy of this report is being sent to my
maintainer.  The error message I received was:

$error

--- Below this line is a copy of the message.
EOR
    $reply->add_body ("Return-Path: <$ENV{SENDER}>") if $ENV{SENDER};
    $reply->add_body (scalar ($$self{article}->rawheaders ()), '');
    $reply->add_body (scalar $$self{article}->body ());
    $reply->mail ();
    exit 0;
}

# Used to forward a message along to another address (probably a human
# moderator).  Takes the address to which to resend it as an argument.
# Returns true if sending the mail succeeded, false on failure.
sub mail_forward {
    my ($self, $address) = @_;
    $$self{article}->mail ($address);
}

# Generates a reply from a template in a file.  Takes the file name as an
# argument and then a list of sources of variables (either references to
# hashes or references to code).  In addition, the following variables will
# be made available to the template:
#
#   @BODY        The message body, possibly munged by previous modules.
#   @HEADERS     The current message headers.
#   @OLDHEADERS  The original message headers.
#   $SUBJECT     The original subject line.
#   $MAINTAINER  The maintainer of this gateway.
#
# Returns true if sending the mail succeeded, undef on failure.
sub mail_filereply {
    my $self = shift;
    my $filename = shift;
    my $article = $$self{article};
    my $source = {
        BODY       => scalar ($article->body ()),
        HEADERS    => [ $article->headers () ],
        OLDHEADERS => scalar ($article->rawheaders ()),
        SUBJECT    => $article->header ('subject'),
        MAINTAINER => $$self{maintainer}
    };
    my $reply = News::FormReply->new ($article, $filename, $source, @_)
        or $self->error ("Unable to generate reply from $filename");
    $reply->envelope ($$self{envelope}) if defined $$self{envelope};
    $reply->set_headers (precedence => 'junk');
    $reply->mail ();
}
    
1;
