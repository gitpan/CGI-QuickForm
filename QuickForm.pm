package CGI::QuickForm ; # Documented at the __END__.

# $Id: QuickForm.pm,v 1.9 1999/09/21 22:20:15 root Exp root $

require 5.004 ;

use strict ;

use CGI qw( :standard :html3 ) ;
#use CGI::Carp qw( fatalsToBrowser ) ;

use vars qw( 
            $VERSION @ISA @EXPORT 
            $REQUIRED $INVALID
            %Translate 
            ) ;

$VERSION = '1.21' ; 

use Exporter() ;

@ISA    = qw( Exporter ) ;

@EXPORT = qw( show_form ) ;

my %Record ;


sub show_form {
    %Record = (
        -LANGUAGE    => 'en',         # Language to use for default messages
        -BUTTONLABEL => 'Submit',     # Default submit button text
        -TITLE       => 'Quick Form', # Default page title and heading
        -HEADER      => undef,      
        -FOOTER      => undef,
        -ACCEPT      => \&_on_valid_form,
        -VALIDATE    => undef,      # Call this to validate entire record
        -SIZE        => undef,
        -MAXLENGTH   => undef,
        -ROWS        => undef,
        -COLUMNS     => undef,
        -FIELDS      => [ { -LABEL => 'No Fields Specified' } ],
        @_,
        ) ;

    # Backward compatibility.
    $Record{-LANGUAGE} = 'en' if $Record{-LANGUAGE} eq 'english' ;

    $Record{-REQUIRED} = 0 ; # Assume no fields are required.

    my $i = 0 ;
    foreach my $fieldref ( @{$Record{-FIELDS}} ) {
        my %field = %$fieldref ;
        # We have to write back to the original data, $fieldref only points to
        # a copy.
        $Record{-FIELDS}[$i]{-LABEL} = $field{-name}  unless $field{-LABEL} ;
        $Record{-FIELDS}[$i]{-name}  = $field{-LABEL} unless $field{-name} ;
        $Record{-FIELDS}[$i]{-TYPE}  = 'textfield'    unless $field{-TYPE} ;
        $Record{-REQUIRED}           = 1              if $field{-REQUIRED} ;
        if( $Record{-FIELDS}[$i]{-TYPE} eq 'textfield' ) { 
            if( $Record{-SIZE} and not $field{-size} ) {
                $Record{-FIELDS}[$i]{-size} = $Record{-SIZE} ;
            }
            if( $Record{-MAXLENGTH} and not $field{-maxlength} ) {
                $Record{-FIELDS}[$i]{-maxlength} = $Record{-MAXLENGTH} ;
            }
        }
        elsif( $Record{-FIELDS}[$i]{-TYPE} eq 'textarea' ) { 
            if( $Record{-ROWS} and not $field{-rows} ) {
                $Record{-FIELDS}[$i]{-rows} = $Record{-ROWS} ;
            }
            if( $Record{-COLUMNS} and not $field{-columns} ) {
                $Record{-FIELDS}[$i]{-columns} = $Record{-COLUMNS} ;
            }
        }
        $i++ ;
    }

    if( param() ) {
        &_check_form ;
    }
    else {
        &_show_form ;
    }
}


sub _check_form {

    $Record{-INVALID} = 0 ;
    my %Field ;

    my $i = 0 ;
    foreach my $fieldref ( @{$Record{-FIELDS}} ) {
        my %field = %$fieldref ;
        # We have to write back to the original data, $fieldref only points to
        # a copy.
        $Record{-FIELDS}[$i]{-INVALID} = 1, $Record{-INVALID}++
        if ( $field{-REQUIRED} and not param( $field{-name} ) ) or
           ( defined $field{-VALIDATE} and not
             &{$field{-VALIDATE}}( param( $field{-name} ) ) ) ;
        $Field{$field{-name}} = param( $field{-name} ) ;
        $i++ ;
    }

    if( not $Record{-INVALID} and defined $Record{-VALIDATE} ) {
        # If all the individual parts are valid, check that the record as a
        # whole is valid. The parameters are presented in a name=>value hash.
        $Record{-INVALID} = not &{$Record{-VALIDATE}}( %Field ) ;
    }

    if( $Record{-INVALID} ) {
        &_show_form ;
    }
    else {
        &{$Record{-ACCEPT}} ;
    }
}


sub _show_form {

    my $invalid = delete $Record{-INVALID} ;

    if( $Record{-HEADER} ) {
        print $Record{-HEADER} ;
    }
    else {
        print 
            header,
            start_html( $Record{-TITLE} ),
            h3( $Record{-TITLE} ),
            p( $Translate{$Record{-LANGUAGE}}{-INTRO} ),
            ;
    }

    print $Translate{$Record{-LANGUAGE}}{-REQUIRED}   if $Record{-REQUIRED} ;
    print " $Translate{$Record{-LANGUAGE}}{-INVALID}" if $invalid ;

    print start_form, qq{<TABLE BORDER="0">} ;

    foreach my $fieldref ( @{$Record{-FIELDS}} ) {
        my %field    = %$fieldref ;
        my $required = delete $field{-REQUIRED} ;
        $required    = $required ? $REQUIRED : '' ;
        my $invalid  = delete $field{-INVALID} ;
        $invalid     = $invalid ? $INVALID : '' ;
        print "<TR><TD>$field{-LABEL}$required$invalid</TD><TD>" ;
        delete $field{-LABEL} ;
        delete $field{-VALIDATE} ;
        my $type     = delete $field{-TYPE} ;
        no strict "refs" ;
        print &{$type}( %field ) ;
        print "</TD></TR>" ;
    }

    print "</TABLE>", submit( $Record{-BUTTONLABEL} ), end_form ; 

    if( $Record{-FOOTER} ) {
        print $Record{-FOOTER} ;
    }
    else {
        print hr, end_html ;
    }
}


sub _on_valid_form {

    # This is included for completeness - if you don't supply your own your
    # form will simply throw away the user's data!

    print
        header,
        start_html( $Record{-TITLE} ),
        h3( $Record{-TITLE} ),
        p( "You must define your own &amp;on_valid_form subroutine, otherwise " .
           "the data will simply be thrown away." ),
        end_html,
        ;
}


BEGIN {

    $REQUIRED = '<B><FONT COLOR="BLUE">+</FONT></B>' ;
    $INVALID  = '<B><FONT COLOR="RED">*</FONT></B>' ;

    %Translate = (
        'de' => {
            -INTRO    => "Tragen Sie bitte die Informationen ein.",
            -REQUIRED => "Die Dateneingabe Felder, die mit $REQUIRED " .
                         "gekennzeichnet werden, werden angefordert.",
            -INVALID  => "Die Dateneingabe Felder, die mit gekennzeichnet " .
                         "werden $INVALID enthalten Sie Fehler oder seien " .
                         "Sie leer.",
            },
         'en' => {
            -INTRO    => "Please enter the information.",
            -REQUIRED => "Data entry fields marked with $REQUIRED are required.",
            -INVALID  => "Data entry fields marked with $INVALID contain errors " .
                         "or are empty.",
            },
         'fr' => {
            -INTRO    => "Veuillez &eacute;crire l'information.",
            -REQUIRED => "Des zones de saisie de donn&eacute;es " .
                         "identifi&eacute;es par " .
                         "$REQUIRED sont exig&eacute;es.",
            -INVALID  => "Des zones de saisie de données identifi&eacute;es par " .
                         "$INVALID contenez les erreurs ou soyez vide.",
            },
        ) ;
}


1 ;


__END__

=head1 NAME

CGI::QuickForm - Perl module to provide quick CGI forms. 

=head1 SYNOPSIS

    # Minimal example. (Insecure no error checking.) 

    #!/usr/bin/perl -w
    use strict ;
    use CGI qw( :standard :html3 ) ;
    use CGI::QuickForm ;

    show_form(
        -ACCEPT => \&on_valid_form, # You must supply this subroutine.
        -TITLE  => 'Test Form',
        -FIELDS => [
            { -LABEL => 'Name', },  # Default field type is textfield.
            { -LABEL => 'Age',  },  # Stored in param( 'Age' ).
        ],
    ) ;

    sub on_valid_form {
        my $name = param( 'Name' ) ;
        my $age  = param( 'Age' ) ;
        open PEOPLE, ">>people.tab" ;
        print "$name\t$age\n" ;
        close PEOPLE ;
        print header, start_html( 'Test Form Acceptance' ),
            h3( 'Test Form Data Accepted' ),
            p( "Thank you $name for your data." ), end_html ;
    }


    # All QuickForm options

    #!/usr/bin/perl -w
    use strict ;
    use CGI qw( :standard :html3 ) ;
    use CGI::QuickForm ;

    show_form(
        -ACCEPT      => \&on_valid_form, 
        -BUTTONLABEL => 'Submit',
        -FOOTER      => undef,
        -HEADER      => undef,      
        -LANGUAGE    => 'en',
        -TITLE       => 'Test Form',
        -VALIDATE    => undef,       # Set this to validate the entire record
        -SIZE        => undef,
        -MAXLENGTH   => undef,
        -ROWS        => undef,
        -COLUMNS     => undef,
        -FIELDS      => [            
            { 
                -LABEL     => 'Name', 
                -REQUIRED  => undef,
                -TYPE      => 'textfield',
                -VALIDATE  => undef, # Set this to validate the field
                # Lowercase options are those supplied by CGI.pm
                -name      => undef, # Defaults to -LABEL's value.
                -default   => undef,
                -size      => 30,
                -maxlength => undef,
            },
            { 
                -LABEL     => 'Address', 
                -REQUIRED  => undef,
                -TYPE      => 'textarea',
                -VALIDATE  => undef,
                -name      => undef, # Defaults to -LABEL's value.
                -default   => undef,
                -rows      => 3,
                -columns   => 40,
            },
            { 
                -LABEL     => 'Password', 
                -REQUIRED  => undef,
                -TYPE      => 'password_field',
                -VALIDATE  => undef,
                -name      => undef, # Defaults to -LABEL's value.
                -value     => undef,
                -size      => 10,
                -maxlength => undef,
            },
            { 
                -LABEL     => 'Hair colour', 
                -REQUIRED  => undef,
                -TYPE      => 'scrolling_list',
                -VALIDATE  => undef,
                -name      => undef, # Defaults to -LABEL's value.
                -values    => [ qw( Red Black Brown Grey White ) ],
                -size      => 1,
                -multiples => undef,
            },
            { 
                -LABEL     => 'Worst Sport', 
                -REQUIRED  => undef,
                -TYPE      => 'radio_group',
                -VALIDATE  => undef,
                -name      => undef, # Defaults to -LABEL's value.
                -values    => [ qw( Boxing Cricket Golf ) ], 
                -default   => 'Golf',
                -size      => undef,
                -multiples => undef,
            },
            # Any other CGI.pm field can be used in the same way.
        ],
    ) ;
 

=head1 DESCRIPTION

C<show_form>, provides a quick and simple mechanism for providing on-line CGI
forms.

When C<show_form> executes it presents the form with the fields requested.
As you can see from the minimal example at the beginning of the synopsis it
will default everything it possibly can to get you up and running as quickly
as possible.

If you have specified any validation it will validate when the user presses
the submit button. If there is an error it will re-present the form with the
erroneous fields marked and with all the data entered in tact. This is
repeated as often as needed. Once the user has corrected all errors and the
data is valid then your C<&on_valid_form> subroutine will be called so that
you can process the valid data in any way you wish.

=head2 QuickForm form-level (record-level) options

C<-ACCEPT> Required subroutine reference. This is a reference to the
subroutine to execute when the form is successfully completed, i.e. once all
the fields and the whole record are valid (either because no validation was
requested or because every validation subroutine called returned true). The
parameters are accessible via C<CGI.pm>, so your C<&on_valid_form> may look
something like this:

    sub on_valid_form {
        my $first_param  = param( 'first' ) ;
        my $second_param = param( 'second' ) ;
        my $third_param  = param( 'third' ) ;

        # Process, e.g. send an email or write a record to a file or database.
        # Give the user a thank you.
    }

C<-BUTTONLABEL> Optional string. This is the label that appears on the submit
button. It defaults to 'Submit', but may be any string.

C<-FOOTER> Optional string. This is used to present any text following the
form and if used it must include everything up to and including final
"</HTML>", e.g.:

    my $footer = p( "Thank's for your efforts." ) .
                 h6( "Copyright (c) 1999 Summer plc" ) . end_html ;

    show_form(
        -FOOTER => $footer,
        # etc

C<-HEADER> Optional string. This is used to present your own title and text
before the form proper. If you use this it must include everything from
"Content-type: text/html" onwards. For example:

    my $header = header . start_html( "This is my Title" ) .
                 h2( "My new Form" ) . p( "Please answer the questions!" ) ;

    show_form(
        -HEADER => $header,
        # etc

C<-LANGUAGE> Optional string. This option accepts 'en' (english), 'de'
(german) and 'fr' (french) - the translations were done by Babelfish.
('english' is also supported for backward compatibility.) If people provide me
with translations I will add other languages. This is used for the
presentation of messages to the user, e.g.:

    Please enter the information.
    Fields marked with + are required.
    Fields marked with * contain errors or are empty.

C<-TITLE> Required string (unless you use C<-HEADER>). This is used as the
form's title and as a header on the form's page - unless you use the
C<-HEADER> option (see above) in which case this option is ignored.

C<-VALIDATE> Optional subroutine reference. This routine is called after each
individual field has been validated. It is given the fields in a name=>value
hash and must return true if the record as a whole is valid, false otherwise.
Typically it may have this structure:

    sub valid_record {
        my %field = @_ ;
        my $valid = 1 ;
        # Do some multi-field validation, e.g.
        # if( $field{'colour'} eq 'blue' and
        #     $field{'make'} eq 'estate' ) {
        #   $valid = 0 ; # No blue estates available.
        # }
        # etc.
        $valid ; # Return the valid variable which may now be false.
    }

C<-COLUMNS> Optional integer. If set then any C<-TYPE =E<gt> textarea> will
have a C<-columns> set to this value unless an explicit C<-columns> is given.

C<-MAXLENGTH> Optional integer. If set then any C<-TYPE =E<gt> textfield> will
have a C<-maxlength> set to this value unless an explicit C<-maxlength> is given.

C<-ROWS> Optional integer. If set then any C<-TYPE =E<gt> textarea> will
have a C<-rows> set to this value unless an explicit C<-rows> is given.

C<-SIZE> Optional integer. If set then any C<-TYPE =E<gt> textfield> will
have a C<-size> set to this value unless an explicit C<-size> is given. For
example:

     show_form(
        -ACCEPT => \&on_valid_form, # You must supply this subroutine.
        -TITLE  => 'Test Form',
        -SIZE   => 50,
        -FIELDS => [
            { -LABEL => 'Name', },  
            { -LABEL => 'Age',  }, 
        ],
    ) ;
    # Both the fields will be textfields because that is the default and both
    # will have a -size of 50.


    show_form(
        -ACCEPT    => \&on_valid_form, # You must supply this subroutine.
        -TITLE     => 'Test Form',
        -SIZE      => 50,
        -MAXLENGTH => 70,
        -FIELDS => [
            { -LABEL => 'Name', },  
            { -LABEL => 'Age',  }, 
            { 
                -LABEL => 'Country',  
                -size  => 20,
            }, 
        ],
    ) ;
    # All three fields will be textfields. Name and Age will have a -size of
    # 50 but Country will have a -size of 20. All three will have a -maxlength
    # of 70.
 
C<-FIELDS> Required array reference. This is an array of hashes; there must
be at least one. The fields are displayed in the order given. The options
available in each field hash are covered in the next section.

=head2 QuickForm field-level options

C<-LABEL> Required string. This is the display label for the field. It is
also used as the field's name if no C<-name> option is used.

C<-REQUIRED> Optional boolean. Default is false. If set to true the field
must contain something. Should only be used with text fields. It is ignored if
C<-VALIDATE> is given since C<-VALIDATE> overrides (see later).

C<-TYPE> Optional string. Default is C<textfield>. May be any field supported
by C<CGI.pm>.

C<-VALIDATE> Optional subroutine reference. If specified this subroutine will
be called when the user presses the submit button; its argument will be the
value of the field; it must return true if the field is valid false otherwise.
Its typical structure may be:

    sub valid_national_insurance {
        my $ni = shift ;
    
        $ni = uc $ni ;
        ( $ni =~ /^[A-Z]{2}\d{7}[A-Z]$/o ) ? 1 : 0 ;
    }

=head2 CGI.pm field-level options

All the other options passed in the hash should be the lowercase options
supported by C<CGI.pm> for the particular field type. For example for a
C<-TYPE> of C<textfield> the options currently supported are C<-name>,
C<-default>, C<-size> and C<-maxlength>; you may use any, all or none of them
since C<CGI.pm> always provides sensible defaults. See "All QuickForm options"
in the SYNOPSIS above for examples of the most common field types.

=head2 EXAMPLE #1: Using a form to generate email 

This program is provided as an example of QuickForm's capabilities, it is not a
production-quality program: it has no error checking and is I<not> secure.

    #!/usr/bin/perl -w
    use strict ;
    use CGI qw( :standard :html3 ) ;
    use CGI::QuickForm ;

    show_form(
        -TITLE  => 'Test Form',
        -ACCEPT => \&on_valid_form, 
        -FIELDS => [
            {
                -LABEL    => 'Forename',
                -REQUIRED => 1,
            },
            {
                -LABEL    => 'Surname',
                -REQUIRED => 1,
            },
            { -LABEL => 'Age', },
            {
                -LABEL    => 'Sex',
                -TYPE     => 'radio_group',
                '-values' => [ qw( Female Male ) ],
            },
        ],
    ) ;

    # This subroutine will only be called if the name fields contain at
    # least one character.
    sub on_valid_form {
        my $forename = param( 'Forename' ) ;
        my $surname  = param( 'Surname' ) ;
        my $age      = param( 'Age' ) ;
        open MAIL, "|/usr/lib/sendmail -t" ; 
        print MAIL "From: test\@localhost\n" .
                   "To: user\@localhost\n" .
                   "Subject: Quick Form Email Test\n\n" .
                   "Name: $forename $surname\n" .
                   "Age:  $age\n" ;
        print header, start_html( 'Test Form Data Accepted' ),
            h3( 'Test Form Data Accepted' ),
            p( "Thank you $forename for your data." ), end_html ;
    }

=head2 EXAMPLE #2: Appending data to a file

This program is provided as an example of QuickForm's capabilities, it is not a
production-quality program: it has no error checking and is I<not> secure.

    #!/usr/bin/perl -w

    use strict ;
    use CGI qw( :standard :html3 ) ;
    use CGI::QuickForm ;

    show_form(
        -TITLE     => 'Test Form',
        -ACCEPT    => \&on_valid_form, 
        -VALIDATE  => \&valid_form,
        -SIZE      => 40,
        -MAXLENGTH => 60,
        -FIELDS => [
            {
                -LABEL     => 'Forename',
                -VALIDATE  => \&valid_name,
            },
            {
                -LABEL     => 'Surname',
                -VALIDATE  => \&valid_name,
            },
            {
                -LABEL     => 'Age',
                # &mk_valid_number generates a subroutine (a closure) and
                # returns a reference to that subroutine.
                -VALIDATE  => &mk_valid_number( 3, 130 ), 
                -size      => 10,
                -maxlength => 3,
            },
        ],
    ) ;

    # This will only be called if all the validation routines return true. 
    sub on_valid_form {
        my $forename = param( 'Forename' ) ;
        my $surname  = param( 'Surname' ) ;
        my $age      = param( 'Age' ) ;
        open FILE, ">>namedata.tab" ;
        print FILE "$surname\t$forename\t$age\n" ;
        close FILE ;
        print header, start_html( 'Test Form Data Accepted' ),
            h3( 'Test Form Data Accepted' ),
            p( "Thank you $forename for your data." ), end_html ;
    }

    # This is called to validate the entire form (record).
    # Use a routine like this if there are relationships between fields that
    # must be tested.
    sub valid_form {
        my %rec   = @_ ;
        my $valid = 1 ;
        # We don't allow (perfectly valid!) names like 'John John'.
        $valid    = 0 if lc $surname eq lc $forename ;
        $valid ;
    }

    sub valid_name {
        my $name  = shift ;
        my $valid = 1 ;
        $valid    = 0 if $name !~ /^\w{2,}$/o ;
        $valid ;
    }

    sub mk_valid_number {
        my( $min, $max ) = @_ ;
        sub { $min <= $_[0] and $_[0] <= $max } ;
    }


=head1 BUGS

None that have come to light (yet).

=head1 AUTHOR

Mark Summerfield. I can be contacted as <summer@chest.ac.uk> -
please include the word 'quickform' in the subject line.

=head1 COPYRIGHT

Copyright (c) Mark Summerfield 1999. All Rights Reserved.

This module may be used/distributed/modified under the LGPL.

=cut

