package CGI::QuickForm ; # Documented at the __END__.

# $Id: QuickForm.pm,v 1.26 1999/12/01 20:51:10 root Exp root $

require 5.004 ;

use strict ;

use CGI qw( :standard :html3 ) ;
#use CGI::Carp qw( fatalsToBrowser ) ;

use vars qw( 
            $VERSION @ISA @EXPORT @EXPORT_OK
            $REQUIRED $INVALID
            %Translate 
            ) ;

$VERSION   = '1.60' ; 

use Exporter() ;

@ISA       = qw( Exporter ) ;

@EXPORT    = qw( show_form ) ;


# &colour is not documented because at some point it may be moved elsewhere.
@EXPORT_OK = qw( colour color ) ;
*color = \&colour ;
sub colour { qq{<SPAN style="color:$_[0]">$_[1]</SPAN>} }


my %Form ;


sub show_form {
    %Form = (
        -LANGUAGE         => 'en',         # Language to use for default messages
        -TITLE            => 'Quick Form', # Default page title and heading
        -HEADER           => undef,      
        -FOOTER           => undef,
        -ACCEPT           => \&_on_valid_form,
        -VALIDATE         => undef,        # Call this to validate entire form
        -SIZE             => undef,
        -MAXLENGTH        => undef,
        -ROWS             => undef,
        -COLUMNS          => undef,
        -BORDER           => 0,
        -CHECK            => 1,
        -STYLE_FIELDNAME  => '',
        -STYLE_FIELDVALUE => '',
        -STYLE_BUTTONS    => '',
        -STYLE_ROW        => '',
        -STYLE_DESC       => '',
        -STYLE_WHY        => '',
        -TABLE_OPTIONS    => '',
        -FIELDS           => [ { -LABEL => 'No Fields Specified' } ],
        -BUTTONS          => [ { -name  => 'Submit' } ], # Default button
        @_,
        ) ;

    # Backward compatibility.
    $Form{-LANGUAGE} = 'en' if $Form{-LANGUAGE} eq 'english' ;
    $Form{-BUTTONS}[0]{-name} = $Form{-BUTTONLABEL} if $Form{-BUTTONLABEL} ;

    $Form{-REQUIRED} = 0 ; # Assume no fields are required.

    foreach my $style ( qw( FIELDNAME FIELDVALUE BUTTONS DESC WHY ) ) {
        $Form{"-STYLE_$style"}  = qq{ $Form{"-STYLE_$style"}} 
        if $Form{"-STYLE_$style"} ;
    }

    $Form{-TABLE_OPTIONS} = " $Form{-TABLE_OPTIONS}" if $Form{-TABLE_OPTIONS} ;

    my $i = 0 ;
    foreach my $fieldref ( @{$Form{-FIELDS}} ) {
        my %field = %$fieldref ;
        # We have to write back to the original data, $fieldref only points to
        # a copy.
        $Form{-FIELDS}[$i]{-LABEL} = $field{-name}  unless $field{-LABEL} ;
        $Form{-FIELDS}[$i]{-name}  = $field{-LABEL} unless $field{-name} ;
        $Form{-FIELDS}[$i]{-TYPE}  = 'textfield'    unless $field{-TYPE} ;
        $Form{-REQUIRED}           = 1              if $field{-REQUIRED} ;
        if( $Form{-FIELDS}[$i]{-TYPE} eq 'textfield' ) { 
            if( $Form{-SIZE} and not $field{-size} ) {
                $Form{-FIELDS}[$i]{-size}      = $Form{-SIZE} ;
            }
            if( $Form{-MAXLENGTH} and not $field{-maxlength} ) {
                $Form{-FIELDS}[$i]{-maxlength} = $Form{-MAXLENGTH} ;
            }
        }
        elsif( $Form{-FIELDS}[$i]{-TYPE} eq 'textarea' ) { 
            if( $Form{-ROWS} and not $field{-rows} ) {
                $Form{-FIELDS}[$i]{-rows}      = $Form{-ROWS} ;
            }
            if( $Form{-COLUMNS} and not $field{-columns} ) {
                $Form{-FIELDS}[$i]{-columns}   = $Form{-COLUMNS} ;
            }
        }
        $i++ ;
    }

    if( $Form{-CHECK} and param() ) {
        &_check_form ;
    }
    else {
        &_show_form ;
    }
}


sub _check_form {

    $Form{-INVALID} = 0 ;
    my %Field ;

    my $i = 0 ;
    foreach my $fieldref ( @{$Form{-FIELDS}} ) {
        my %field = %$fieldref ;
        # We have to write back to the original data, $fieldref only points to
        # a copy.
        my( $valid, $why ) = defined $field{-VALIDATE} ?
                                  &{$field{-VALIDATE}}( param( $field{-name} ) ) :
                                  ( 1, '' ) ;
        $Form{-FIELDS}[$i]{-INVALID} = 1, 

        $Form{-FIELDS}[$i]{-WHY}     = 
        $valid ? undef : "<SPAN$Form{-STYLE_WHY}>$why</SPAN>", 

        $Form{-INVALID}++
        if ( $field{-REQUIRED} and not param( $field{-name} ) ) or not $valid ;

        $Field{$field{-name}} = param( $field{-name} ) ;
        $i++ ;
    }

    if( not $Form{-INVALID} and defined $Form{-VALIDATE} ) {
        # If all the individual parts are valid, check that the record as a
        # whole is valid. The parameters are presented in a name=>value hash.
        my( $valid, $why ) = &{$Form{-VALIDATE}}( %Field ) ;
        $Form{-INVALID}    = not $valid ;
        $Form{-WHY}        = $why ;
    }

    if( $Form{-INVALID} ) {
        &_show_form ;
    }
    else {
        # Clean any fields that have a clean routine specified.
        foreach my $fieldref ( @{$Form{-FIELDS}} ) {
            my %field = %$fieldref ;
            param( $field{-name}, &{$field{-CLEAN}}( param( $field{-name} ) ) )
            if defined $field{-CLEAN} ;
        }
        &{$Form{-ACCEPT}} ;
    }
}


sub _show_form {

    my $invalid = delete $Form{-INVALID} ;
    my $why     = delete $Form{-WHY} ;

    if( $Form{-HEADER} ) {
        print $Form{-HEADER} ;
    }
    else {
        print 
            header,
            start_html( $Form{-TITLE} ),
            h3( $Form{-TITLE} ),
            p( $Translate{$Form{-LANGUAGE}}{-INTRO} ),
            ;
    }

    print "<SPAN$Form{-STYLE_WHY}>$why</SPAN><BR>" if $invalid and defined $why ;
    print $Translate{$Form{-LANGUAGE}}{-REQUIRED}  if $Form{-REQUIRED} ;
    print " $Translate{$Form{-LANGUAGE}}{-INVALID}" 
    if $invalid and not defined $why ;

    print start_form, qq{<TABLE BORDER="$Form{-BORDER}"$Form{-TABLE_OPTIONS}>} ;

    my @hidden ;

    foreach my $fieldref ( @{$Form{-FIELDS}} ) {
        my %field    = %$fieldref ;
        my $type     = delete $field{-TYPE} ;
        push @hidden, $fieldref   if $type eq 'hidden' ;
        next if $type eq 'submit' or $type eq 'hidden' ;
        my $required = delete $field{-REQUIRED} ;
        $required    = $required ? $REQUIRED : '' ;
        my $invalid  = delete $field{-INVALID} ;
        $invalid     = $invalid ? $INVALID : '' ;
        my $why      = delete $field{-WHY} ;
        print qq{<TR$Form{-STYLE_ROW}><TD$Form{-STYLE_FIELDNAME}>} .
              qq{$field{-LABEL}$required$invalid} .
              qq{</TD><TD$Form{-STYLE_FIELDVALUE}>} ;
        print "<SPAN$Form{-STYLE_DESC}>$field{-DESC}</SPAN><BR>" if $field{-DESC} ;
        delete @field{-LABEL,-VALIDATE,-CLEAN,-SIZE,-MAXLENGTH,-ROWS,-COLUMNS} ;
        no strict "refs" ;
        local $^W = 0 ; # Switch off moans about undefined values.
        print &{$type}( %field ) ; 
        # Prefer to say why immediately after the field rather than in a
        # separate column.
        print " $why" if $invalid and defined $why ;
        print "</TD></TR>" ;
    }

    print "</TABLE><SPAN$Form{-STYLE_BUTTONS}>" ;

    foreach my $fieldref ( @{$Form{-BUTTONS}} ) {
        if( $fieldref->{-DEFAULTS} ) {
            print defaults( $fieldref->{-name} || 'Clear' ), " " ;
        }
        else {
            print submit( %$fieldref ), " " ;
        }
    }

    print "</SPAN>" ;

    foreach my $fieldref ( @hidden ) {
        my %field = %$fieldref ;
        delete @field{-LABEL,-VALIDATE,-CLEAN,-SIZE,-MAXLENGTH,-ROWS,-COLUMNS,
                      -TYPE,-REQUIRED,-INVALID,-WHY} ;
        print hidden( %field ) ;
    }

    print end_form ; 

    if( $Form{-FOOTER} ) {
        print $Form{-FOOTER} ;
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
        start_html( $Form{-TITLE} ),
        h3( $Form{-TITLE} ),
        p( "You must define your own &amp;on_valid_form subroutine, otherwise " .
           "the data will simply be thrown away." ),
        end_html,
        ;
}


BEGIN {

    $REQUIRED = '<SPAN style="font-weight:bold;color:BLUE">+</SPAN>' ;
    $INVALID  = '<SPAN style="font-weight:bold;color:RED">*</SPAN>' ;

    %Translate = (
         'cy' => {
            -INTRO    => "Cofnodwch y wybodaeth.",
            -REQUIRED => "Mae angen llenwi'r adrannau sydd wedi eu clustnodi " .
                         "gyda $REQUIRED.",
            -INVALID  => "Mae'r adrannau sydd wedi eu clustnodi gyda $INVALID " .
                         "yn cynnwys camgymeriadau neu yn wag.",
            },
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
            -INVALID  => "Des zones de saisie de donn�es identifi&eacute;es par " .
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
        -ACCEPT           => \&on_valid_form, 
        -BORDER           => 0,
        -FOOTER           => undef,
        -HEADER           => undef,      
        -LANGUAGE         => 'en',
        -TITLE            => 'Test Form',
        -VALIDATE         => undef,       # Set this to validate the entire record
        -SIZE             => undef,
        -MAXLENGTH        => undef,
        -ROWS             => undef,
        -COLUMNS          => undef,
        -CHECK            => 1,
        -STYLE_FIELDNAME  => '',
        -STYLE_FIELDVALUE => '',
        -STYLE_BUTTONS    => '',
        -STYLE_ROW        => '',
        -STYLE_WHY        => '',
        -TABLE_OPTIONS    => '',
        -FIELDS           => [            
            { 
                -LABEL     => 'Name', 
                -REQUIRED  => undef,
                -TYPE      => 'textfield',
                -VALIDATE  => undef, # Set this to validate the field
                -CLEAN     => undef, # Set this to clean up valid data
                -DESC      => undef,
                # Lowercase options are those supplied by CGI.pm
                -name      => undef, # Defaults to -LABEL's value.
                -default   => undef,
                -size      => 30,
                -maxlength => undef,
            },
            # For all others: same QuickForm options as above
            # and all CGI.pm options (which vary with -TYPE) available 
            { 
                -LABEL     => 'Address', 
                -TYPE      => 'textarea',
                -rows      => 3,
                -columns   => 40,
            },
            { 
                -LABEL     => 'Password', 
                -TYPE      => 'password_field',
            },
            { 
                -LABEL     => 'Hair colour', 
                -TYPE      => 'scrolling_list',
                '-values'  => [ qw( Red Black Brown Grey White ) ],
                -size      => 1,
                -multiples => undef,
            },
            { 
                -LABEL     => 'Worst Sport', 
                -TYPE      => 'radio_group',
                -values    => [ qw( Boxing Cricket Golf ) ], 
                -default   => 'Golf',
            },
            # Any other CGI.pm field can be used in the same way.
        ],
        -BUTTONS           => [
            { -name => 'Add'    },
            { -name => 'Edit'   },
            { -name => 'List'   },
            { -name => 'Remove' },
            { -name => 'Clear', -DEFAULTS => 1 },
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

C<-BORDER> Optional integer. This is the border width. Default is zero. You
would normally set this to 1 if you are using C<-DESC> to add textual
descriptions to your fields.

C<-BUTTONS> Optional array reference. This is an array of submit buttons. The
buttons appear at the bottom of the form, after all the fields. Each button is
defined as an anonymous hash, e.g.

    -BUTTONS    => [
        { -name => 'New'    },
        { -name => 'Update' },
        ],

although any other legitimate C<CGI.pm> options may also be given, e.g.

    -BUTTONS    => [
        { -name => 'New',    -value => 'BUTTON_NEW'    },
        { -name => 'Update', -value => 'BUTTON_UPDATE' },
        ],

If you want a button which resets the form to its default values then create
an entry like this:

    { -name => 'Clear', -DEFAULTS => 1 },

If no C<-BUTTONS> option array reference is given it will be created with
C<{ -name =E<lt> 'Submit' }> by default. Note that this option replaces the
C<-BUTTONLABEL> option. If C<-BUTTONLABEL> is used it will be converted into
the new form automatically so old scripts will I<not> be broken. However use
of C<-BUTTONS> is recommended for all new work. To see which button has been
pressed you might use code like this in your on_valid_form subroutine:

    if( param( 'New' ) ) {
        # New pressed
    }
    elsif( param( 'Update' ) ) {
        # Update pressed
    }
    # etc.

C<-CHECK> Optional boolean, default is true. When C<show_form> is called it
will check (i.e. do validation) providing there are parameters (i.e. the user
has filled in the form) I<and> if C<-CHECK> is true. This option would not
normally be used. However if you have links which call your form with some
parameters (e.g. default values), you will want the form to be displayed with
the defaults but I<without> any validation taking place in the first instance.
In this situation you would set C<-CHECK> to false. Thus we must cope with the
following scenarios: 
1. Form is called with no params - must display blank form and validate when
the user presses a button;
2. Form is called with params (e.g. by clicking a link we've provided) - must
display form with any defaults and I<not> validate until the user presses a
button;
3. Form is called with params (as the result of the user pressing a button) -
validation must take place.

To achieve the above we need to add an extra field=value pair to the URL we
provide and if that is present then skip validation. The field's name must
I<not> be one of the form's fields! e.g.

    # If it is to be called from one of our own URLs with something like
    # www.mysite.com/cgi-bin/myscript?colour=green&size=large
    # then we must add in the extra field=value and write the preceeding link
    # for example as:
    # www.mysite.com/cgi-bin/myscript?QFCHK=0&colour=green&size=large 
    # We then use query_string() to set -CHECK to 0 and show the form with the
    # defaults without validating - we'll validate when they press a button. 
    # If its been called as something like www.mysite.com/cgi-bin/myscript
    # then set -CHECK to 1 which gives us standard behaviour:
    # i.e. if there are params then show_form will validate; otherwise it will
    # show the blank form.
    show_form(
        -CHECK => ( query_string() =~ /QFCHK=0/o ? 0 : 1 ), 
        # etc
        ) ;

    # Or more verbosely:
    my $Check = 1 ;
    $Check    = 0 if query_string() =~ /QFCHK=0/o ; 
    show_form(
        -CHECK => $Check,
        # etc
        ) ;

Note that QuickForm discards any query string if it reinvokes itself because
of invalid data. This is useful because it means you can use the query string
to distinguish between a 'first time' call and subsequent calls as we do here
with -CHECK. However if you want a query string parameter to survive these
calls we must extract them and pass them ourselves, e.g. via a hidden field.

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

C<-LANGUAGE> Optional string. This option accepts 'en' (english), 'cy'
(welsh), 'de' (german) and 'fr' (french) - the French and German translations
were done by Babelfish. ('english' is also supported for backward
compatibility.) If people provide me with translations I will add other
languages. This is used for the presentation of messages to the user, e.g.:

    Please enter the information.
    Fields marked with + are required.
    Fields marked with * contain errors or are empty.

C<-TITLE> Required string (unless you use C<-HEADER>). This is used as the
form's title and as a header on the form's page - unless you use the
C<-HEADER> option (see above) in which case this option is ignored.

C<-VALIDATE> Optional subroutine reference. This routine is called after each
individual field has been validated. It is given the fields in a name=>value
hash. It should either return a simple true (valid) or false (invalid) or a
two element list, the first element being a true/false value and the second
value either an empty string or an (html) string which gives the reason why
the record is invalid.
Typically it may have this structure:

    sub valid_record {
        my %field = @_ ;
        my $valid = 1 ;
        # Do some multi-field validation, e.g.
        if( $field{'colour'} eq 'blue' and
            $field{'make'} eq 'estate' ) {
            $valid = 0 ; # No blue estates available.
        }
        # etc.
        $valid ; # Return the valid variable which may now be false.
    }

or now (preferred style):

    sub valid_record {
        my %field = @_ ;
        my $valid = 1 ;
        my $why   = '' ;
        # Do some multi-field validation, e.g.
        if( $field{'colour'} eq 'blue' and
            $field{'make'} eq 'estate' ) {
          $valid = 0 ; # No blue estates available.
          $why   = '<B><I>No blue estates available</I></B>' ;
        }
        # etc.
        ( $valid, $why ) ; 
    }

I<Both syntaxes work so no existing code need be changed.> If the record is
invalid the C<$why> element will be shown near the top of the form just before
the fields themselves, otherwise (i.e. if the record is valid) it will be
ignored.

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
            { 
                -LABEL => 'Name', 
                -CLEAN => \&cleanup, # You must supply this (see later).
            },  
            { -LABEL => 'Age',  }, 
            { 
                -LABEL => 'Country',  
                          # Here we upper case the country.
                -CLEAN => sub { local $_ = shift ; tr/a-z/A-Z/ ; $_ }, 
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

C<-CLEAN> Optional subroutine reference. If specified this subroutines will be
called for the relevant field if and only if the whole record is valid, i.e.
just before calling your C<on_valid_form> subroutine. It will receive a single
parameter (the value of the relevant param), and must return a new value. A
typical routine might clean up excess whitespace, e.g.:

    sub cleanup {
        local $_ = shift ; # This is the value of param( <fieldname> )

        tr/\t \n\r\f/ /s ; # Convert multiple whitespace to one space.
        s/^\s*//o ;        # Remove leading whitespace.
        s/\s*$//o ;        # Remove trailing whitespace.

        $_ ;
    }

C<-DESC> Optional string. This is a short piece of descriptive text which
appears above the field and is used to give the user a little guidance on what
they should choose or enter. Normally if you use these then you would set the
form-level C<-BORDER> option to 1 to help visually group the field and its
descriptive text.

C<-LABEL> Required string. This is the display label for the field. It is
also used as the field's name if no C<-name> option is used.

C<-REQUIRED> Optional boolean. Default is false. If set to true the field
must contain something. Should only be used with text fields. It is ignored if
C<-VALIDATE> is given since C<-VALIDATE> overrides (see later).

C<-TYPE> Optional string. Default is C<textfield>. May be any field supported
by C<CGI.pm>.

C<-VALIDATE> Optional subroutine reference. If specified this subroutine will
be called when the user presses the submit button; its argument will be the
value of the field. It should either return a simple true (valid) or false
(invalid) or a two element list, the first element being a true/false value
and the second value either an empty string or an (html) string which gives
the reason why the field is invalid.
Its typical structure may be:

    sub valid_national_insurance {
        my $ni = shift ;
    
        $ni = uc $ni ;
        ( $ni =~ /^[A-Z]{2}\d{7}[A-Z]$/o ) ? 1 : 0 ;
    }

or now (preferred style):

    sub valid_national_insurance {
        my $ni  = shift ;
        my $why = '<I>Should be 2 letters followed by 7 ' .
                  'digits then a letter</I>' ;
    
        $ni = uc $ni ;
        my $valid = ( $ni =~ /^[A-Z]{2}\d{7}[A-Z]$/o ) ? 1 : 0 ;

        ( $valid, $why ) ; 
    }

I<Both syntaxes work so no existing code need be changed.> If the field is
invalid the C<$why> element will be shown immediately to the right of the
field it refers to, otherwise (i.e. if the field is valid) it will be ignored.

=head2 CGI.pm field-level options

All the other options passed in the hash should be the lowercase options
supported by C<CGI.pm> for the particular field type. For example for a
C<-TYPE> of C<textfield> the options currently supported are C<-name>,
C<-default>, C<-size> and C<-maxlength>; you may use any, all or none of them
since C<CGI.pm> always provides sensible defaults. See "All QuickForm options"
in the SYNOPSIS above for examples of the most common field types.

=head2 Styles

If you wish to use a cascading style sheet with QuickForm then you need to set
the -HEADER option to include a <LINK> tag which includes a reference to your
stylesheet.

Whether you use a stylesheet for classes or in-line styles you can set the
class or style using the -STYLE_* options, e.g.

    -STYLE_FIELDNAME  => qq{style="font-size:12pt;margin:2em;"},
    -STYLE_FIELDVALUE => qq{class="mystyle.css"},
    -STYLE_BUTTONS    => qq{style="font-family:Helvetica;text-align:center;"},
    -STYLE_ROW        => qq{style="mystyle.css"},
    -STYLE_WHY        => qq{style="font-style:italic;color:red"},
    -STYLE_DESC       => qq{style="color:darkblue"},

For tables you can set options (because most browsers don't seem to support
styles in tables):

    -TABLE_OPTIONS    => qq{BGCOLOR="WHITE"},


See files, example3 (linux-help) and example5 (bicycle) for more examples.

You can of course also apply your own global styles to the existing tags in
the normal way.

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
                -CLEAN     => \&cleanup,    # (See earlier for definition.)
            },
            {
                -LABEL     => 'Surname',
                -VALIDATE  => \&valid_name,
                -CLEAN     => \&cleanup,    # (See earlier for definition.)
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
        my $why   = 'Not allowed to have identical forename and surname' ;
        $valid    = 0 if lc $surname eq lc $forename ;
        ( $valid, $why ) ; # $why is ignored if valid.
    }

    sub valid_name {
        my $name  = shift ;
        my $valid = 1 ;
        $valid    = 0 if $name !~ /^\w{2,}$/o ;
        ( $valid, 'Name must have at least 2 letters' ) ; 
    }

    sub mk_valid_number {
        my( $min, $max ) = @_ ;

        sub { 
            my $valid = $_[0] ? ( $min <= $_[0] and $_[0] <= $max ) : 1 ;
            ( $valid, "<I>Should be between $min and $max inclusive</I>" ) ; 
        } ;
    }

=head2 INTRODUCTORY ARTICLE

See http://www.perlpress.com/perl/quickform.html or
http://www.queenwood.fsnet.co.uk/perl/quickform.html

=head1 BUGS

Please don't use version 1.56, later or earlier versions are fine.

=head1 AUTHOR

Mark Summerfield. I can be contacted as <summer@perlpress.com> -
please include the word 'quickform' in the subject line.

See CHANGES for acknowledgements.

=head1 COPYRIGHT

Copyright (c) Mark Summerfield 1999. All Rights Reserved.

This module may be used/distributed/modified under the LGPL.

=cut

