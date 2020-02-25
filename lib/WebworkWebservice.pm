#!/user/bin/perl -w

# initialize SOAP interface as well

use JSON;
use WebworkSOAP;
use WebworkSOAP::WSDL;
use WeBWorK::FakeRequest;

BEGIN {
    $main::VERSION = "2.4.9";
    use Cwd;
	use WeBWorK::PG::Local;

	use constant MP2 => ( exists $ENV{MOD_PERL_API_VERSION} and $ENV{MOD_PERL_API_VERSION} >= 2 );

###############################################################################
# Configuration -- set to top webwork directory (webwork2) (set in webwork.apache2-config)
# Configuration -- set server name
###############################################################################

    our $webwork_directory = $WeBWorK::Constants::WEBWORK_DIRECTORY; #'/opt/webwork/webwork2';
	print "WebworkWebservice: webwork_directory set to ", $WeBWorK::Constants::WEBWORK_DIRECTORY,
	      " via \$WeBWorK::Constants::WEBWORK_DIRECTORY set in webwork.apache2-config\n";

	$WebworkWebservice::HOST_NAME     = 'localhost'; # Apache->server->server_hostname;
	$WebworkWebservice::HOST_PORT     = '80';        # Apache->server->port;

###############################################################################

	eval "use lib '$webwork_directory/lib'"; die $@ if $@;
	eval "use WeBWorK::CourseEnvironment"; die $@ if $@;
 	my $seed_ce = new WeBWorK::CourseEnvironment({ webwork_dir => $webwork_directory });
 	die "Can't create seed course environment for webwork in $webwork_directory" unless ref($seed_ce);
 	my $webwork_url = $seed_ce->{webwork_url};
 	my $pg_dir = $seed_ce->{pg_dir};
 	eval "use lib '$pg_dir/lib'"; die $@ if $@;
    
	$WebworkWebservice::WW_DIRECTORY = $webwork_directory;
	$WebworkWebservice::PG_DIRECTORY = $pg_dir;
	$WebworkWebservice::SeedCE       = $seed_ce;
	
###############################################################################

	$WebworkWebservice::SITE_PASSWORD      = 'xmluser';     # default password
	$WebworkWebservice::COURSENAME         = 'the-course-should-be-determined-at-run-time';       # default course
}


use strict;
use warnings;
use WeBWorK::Localize;


our  $UNIT_TESTS_ON    = 0;

# error formatting


###############################################################################
###############################################################################

package WebworkWebservice;
=head1 NAME

	WebworkWebservice

=head1 SYNPOSIS

	This is an umbrella namespace.  There is no WebworkService object
 
=head1 DESCRIPTION

	WebworkXMLRPC  FakeRequest
	
The WebworkXMLRPC object receives a webservice request.  With the help of FakeRequest it 
authenticates and authorizes the request 
and then dispatches it to the appropriate WebworkWebservice subroutine to respond.

	WebworkClient

The WebworkClient object contains methods that format a webservice request to be sent to a server running
webworkXMLRPC.  WebworkClient also contains methods for formatting the reply returned by webservice.

	WebworkWebservice::RenderProblem;
	WebworkWebservice::LibraryActions;
	WebworkWebservice::MathTranslators;
	WebworkWebservice::SetActions;
	WebworkWebservice::CourseActions;

Each of these files contains subroutines that respond to the specific request commands sent to the webservice. 

	renderViaXMLRPC
	instructorXMLHandler
	
These passthrough handlers receive HTML requests generated by HTML forms or javaScripts, 
translate them into xmlrpc requests and
send them to a (local) webservice running webworkXMLRPC.
	
=cut

=head2 WebworkWebservice Utility methods

	pretty_print_rh($rh)   # returns text (not HTML) describing the structure of $rh

=cut

sub pretty_print_rh { 
    shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
	my $rh = shift;
	my $indent = shift || 0;

	my $out = "";
	return $out if $indent>10;
	my $type = ref($rh);

	if (defined($type) and $type) {
		$out .= " type = $type; ";
	} elsif (not defined($rh) ) {
		$out .= " type = scalar; ";
	}
	if ( ref($rh) =~/HASH/ or "$rh" =~/HASH/ ) {
	    $out .= "{\n";
	    $indent++;
 		foreach my $key (sort keys %{$rh})  {
 			$out .= "  "x$indent."$key => " . pretty_print_rh( $rh->{$key}, $indent ) . "\n";
 		}
 		$indent--;
 		$out .= "\n"."  "x$indent."}\n";

 	} elsif (ref($rh)  =~  /ARRAY/ or "$rh" =~/ARRAY/) {
 	    $out .= " ( ";
 		foreach my $elem ( @{$rh} )  {
 		 	$out .= pretty_print_rh($elem, $indent);
 		
 		}
 		$out .=  " ) \n";
	} elsif ( ref($rh) =~ /SCALAR/ ) {
		$out .= "scalar reference ". ${$rh};
	} elsif ( ref($rh) =~/Base64/ ) {
		$out .= "base64 reference " .$$rh;
	} else {
		$out .=  $rh;
	}
	
	return $out." ";
}


use WebworkWebservice::RenderProblem;
use WebworkWebservice::LibraryActions;
use WebworkWebservice::MathTranslators;
use WebworkWebservice::SetActions;
use WebworkWebservice::CourseActions;

###############################################################################

=head1 NAME

	WebworkXMLRPC	

=head1 SYNPOSIS

 	$self = $class->initiate_session($request_input);
 	
 	$class is "WebworkXMLRPC".  
 
Both $class and $request_input are determined by the Apache::XMLRPC::Lite module which dispatches the original
webservice request.  The Apache::XMLRPC::Lite module in turn is called from Apache according to the dictates
of the <xmlrpc> snippet in webwork.apache2-config.

The $request_input hash includes a command which the WebworkXMLRPC object uses to dispatch the 
request to WebworkWebservice routines which do the actual work.
 	
=head1 DESCRIPTION

WebworkXMLRPC is the workhorse dispatcher for the WeBWorK webservice.  It was originally written 
before object orientation was available in perl.  While it has been rewritten several times since 
then its structure is still a little unusual in an effort to maintain backwards compatibility
as long as that is necessary.

=head2 initiate_session   (constructor equivalent to new)

	$webworkXMLRPC = WebworkXMLRPC->initiate_session($request_input)

This is equivalent to a "new" command for WebworkXMLRPC.  It checks authentication and authorization of the
webservice request using information provided by the $request_input.  It does this using 
the specialized authentication module Authen::XMLRPC.

=head2 do 

	$webworkXMLRPC->do 

This command receives the output returned by the various WebworkWebservice subroutines and 
insures that the formatting is appropriate to pass on to Apache::XMLRPC::Lite which creates
the XMLRPC response to the webservice call.

=head2 r 

	$webworkXMLRPC->r 

Returns the FakeRequest object contained in $webworkXMLRPC.

=cut


package WebworkXMLRPC;
use base qw(WebworkWebservice); 
use WeBWorK::Utils qw(runtime_use writeTimingLogEntry);
use WeBWorK::Debug;
use JSON;
use Digest::SHA qw(sha256_hex);
use Encode qw(encode);


###########################################################################
#  authentication and authorization
###########################################################################

sub initiate_session {    # close to being a "new" subroutine
	my ($invocant, @args) = @_;
	my $class = ref $invocant || $invocant;
	######### trace commands ######
 	    my @caller = caller(1);  # caller data
 	    my $calling_function = $caller[3];
    ###############################
	
	my $rh_input     = $args[0];
###########################################################################
# identify course 
###########################################################################

my $debug_message1 = join("",
	"WebworkWebservice.pm ",
	__LINE__,
	" initiate_session called from $calling_function\n",
	" site_password  is ",
	( defined($rh_input->{site_password}) ? $rh_input->{site_password} : "was not provided" ),
	"\n",
	" course_password  is ",
	( defined($rh_input->{course_password}) ? $rh_input->{course_password} : "was not provided" ),
	"\n",
	" courseID  is ",
	( defined($rh_input->{courseID}) ? $rh_input->{courseID} : "was not provided" ),
	"\n",
	" userID  is ",
	( defined($rh_input->{userID}) ? $rh_input->{userID} : "was not provided" ),
	"\n",
	" session_key  is ",
	( defined($rh_input->{session_key}) ? $rh_input->{session_key} : "was not provided" ),
	"\n",
	" key  is ",
	( defined($rh_input->{key}) ? $rh_input->{key} : "was not provided" ),
	"\n",
	" internal_WW2_secret is ",
	( defined($rh_input->{internal_WW2_secret}) ? $rh_input->{internal_WW2_secret} : "was not provided" ),
	"\n" );

if ($UNIT_TESTS_ON) {
	print STDERR $debug_message1;
}
debug( $debug_message1 );

my $desired_level = "proctor_quiz_login"; # usually level 2

# Until something better is coded, the INITIAL call to WebworkWebservice.pm
# to process an LTI authenticated html2xml call uses the "internal_WW2_secret"
# to authenticate the connection. This is instead of providing a fixed
# password for embedded problems, but it really does not validate that the
# data which the original LTI connection provided and verified was not
# tampered with before it arrives at lib/WebworkWebservice.pm.
#
# A safer solution would need to provide a digital signature for some additional
# input parameter which encodes the "protected" fields from the initial
# connection and then we can verify the digital signature AND that the
# "protected" fields for which we have a digital signature match the "signed"
# values. A JSON object may be a good method to encode the "protected" fields,
# and a course level shared secret could be used to calculate the digital
# signature.

my $hadValid_internal_WW2_secret = 0;
$rh_input->{had_Valid_internal_WW2_secret} = 0;

if ( defined( $rh_input->{internal_WW2_secret} ) ) {
	if ( $rh_input->{internal_WW2_secret} eq "TemporaryApproachSetSomeServerSecretHere" ) { # Ideally should be a course-dependent value
		$hadValid_internal_WW2_secret = 1;
		debug("Saw calling_function = $calling_function and valid internal_WW2_secret");
		warn "Saw calling_function = $calling_function and valid internal_WW2_secret" if ($UNIT_TESTS_ON);
		$rh_input->{had_Valid_internal_WW2_secret} = 1;
	} else {
		# BAD - we have an invalid value for internal_WW2_secret
		$hadValid_internal_WW2_secret = 0;
		debug("Saw calling_function = $calling_function and INVALID internal_WW2_secret");
		warn "Saw calling_function = $calling_function and INVALID internal_WW2_secret" if ($UNIT_TESTS_ON);
	}
	# Remove the value now
	delete( $rh_input->{internal_WW2_secret} );
}

# Add settings for sessionDataHash based authentication, if relevant
my $use_sessionDataHash = 0;

if ( ( $calling_function =~ /enderProblem/ )            &&   # If the action is renderProblem
     ( defined( $rh_input->{courseID} ) )               &&   # AND we have a courseID
     ( $rh_input->{courseID} =~ /daemon/ )              &&   # AND the courseID includes daemon as a substring
     ( ! defined( $rh_input->{course_password} )             # AND we were NOT sent a course_password to use for authentication
       || $rh_input->{course_password} eq ""     )      &&   #
     ( $hadValid_internal_WW2_secret                         # AND we EITHER had the valid internal_WW2_secret (for initial LTI connection)
       || (    defined( $rh_input->{oauth_consumer_key} )    #        OR     have "LTI" data (we cannot assume that lis_outcome_service_url is provided!)
            && defined( $rh_input->{session_key} )      ) )  #                    AND a session_key
   ) { #
	# We probably want to set $use_sessionDataHash

	if ( $hadValid_internal_WW2_secret ) {
		# Case 1 = just after initial LTI connection
		$use_sessionDataHash = 1;
		debug("permitted for renderProblem by original LTI authorization - valid internal_WW2_secret");
		warn "Saw calling_function = $calling_function and valid internal_WW2_secret" if ($UNIT_TESTS_ON);
		$desired_level = "permitted for renderProblem by original LTI authorization";
	} else {
		# Case 2 - NOT an initial connection
		$use_sessionDataHash = 1;
		$desired_level = "testing based on sessionDataHash linked session_key";
		debug("Trying to validate using sessionDataHash approach");
		warn "Trying to validate using sessionDataHash approach" if ($UNIT_TESTS_ON);
	}
}


my $sessionDataHash = "";

if ( $use_sessionDataHash ) {
	my @ToInclude = qw( userID
			    courseID
			    oauth_consumer_key
			    oauth_signature_method
			    lis_outcome_service_url
			    lis_result_sourcedid
			    problemSeed
			    psvn
			    problemUUID
			    sourceFilePath
			    problemSource
			    pathToProblemFile );
	my $key1;
	my @sessionDataToHash;

	foreach $key1 ( @ToInclude ) {
		push ( @sessionDataToHash, $key1 );
		if ( defined( $rh_input->{$key1} ) ) {
			push( @sessionDataToHash, $rh_input->{$key1} );
		} else {
			warn "$key1 was not provided in the input data or is undefined.";
			push( @sessionDataToHash, "" );
		}
	}

	my $sessionDataToHash = join("@@@",@sessionDataToHash);
	warn "Set sessionDataToHash to |$sessionDataToHash|";

	# sha256_hex cannot handle wide-Unicode characters, but can handle UTF-8, so encode first.
	$sessionDataHash = sha256_hex( encode("UTF-8", $sessionDataToHash) );

	# We want to use the sessionDataHash for the authentication process
	# and it will be added to the userID in the "user" field of the keys
	# table so that multiple html2xml sessions can work in parallel.

	$rh_input->{use_sessionDataHash} = 1;
	$rh_input->{sessionDataHash} = $sessionDataHash;
}

# create fake version of Apache::Request object
# This abstracts some of the work that used to be done by the webworkXMLRPC object
# It also allows WeBWorK::FakeRequest to inherit cleanly from WeBWorK::Request
# The $fake_r value returned actually contains subroutines that the WebworkWebservice packages
# need to operate.  It may be possible to pass $fake_r instead of $self in those routines.
 
my $fake_r = WeBWorK::FakeRequest->new($rh_input, 'xmlrpc_module'); # need to specify authentication module
my $authen = $fake_r->authen;
my $authz  = $fake_r->authz;

# Create WebworkXMLRPC object
	
	my $self = {
		courseName	=>  $rh_input ->{courseID},
		user_id		=>  $rh_input ->{userID},
		password    =>  $rh_input ->{course_password},  #should this be course_password?
		session_key =>  $rh_input ->{session_key},
		fake_r      =>  $fake_r,
	};	
	$self = bless $self, $class;
	my $debug_message2 = join("",
		"WebworkWebservice.pm ",
		__LINE__,
		" initiate data:\n",
		"class type is ",   $class,       "\n",
		"Self has type ",   ref($self),   "\n",
		"authen has type ", ref($authen), "\n",
		"authz  has type ", ref($authz),  "\n" );
	if ($UNIT_TESTS_ON) {
		print STDERR $debug_message2 ;
	}
	debug( $debug_message2 );
	
	die "Please use 'course_password' instead of 'password' as the key for submitting
		passwords to this webservice\n" 
	  if exists($rh_input ->{password}) and not exists($rh_input ->{course_password});
#   we need to trick some of the methods within the webwork framework 
#   since we are not coming in with a standard apache request
#   FIXME:  can/should we change this????
#
#   We are borrowing tricks from the AuthenWeBWorK.pm module
#
# 	
	
	# now, here's the problem... WeBWorK::Authen looks at $r->params directly, whereas we
	# need to look at $user and $sent_pw. this is a perfect opportunity for a mixin, i think.
	my $authenOK;
	my $courseName 	= $rh_input->{courseID};
	my $user_id     = $rh_input->{user_id};
	my $session_key = $rh_input->{session_key};
	eval {
		no warnings 'redefine';
# 		local *WeBWorK::Authen::get_credentials   = \&WebworkXMLRPC::get_credentials;
# 		local *WeBWorK::Authen::maybe_send_cookie = \&WebworkXMLRPC::noop;
# 		local *WeBWorK::Authen::maybe_kill_cookie = \&WebworkXMLRPC::noop;
# 		local *WeBWorK::Authen::set_params        = \&WebworkXMLRPC::noop;
# 		local *WeBWorK::Authen::write_log_entry   = \&WebworkXMLRPC::noop; # maybe fix this to log interactions FIXME
		$authenOK = $authen->verify;
	} or do {
		my $e;
		if (Exception::Class->caught('WeBWorK::DB::Ex::TableMissing')) {
			# was asked to authenticate into a non-existent course
			die SOAP::Fault
				->faultcode('404')
				->faultstring("WebworkWebservice: Course |$courseName| not found.")
		}
		# this next bit is a Hack to catch errors when the session key has timed out
		# and an error message which is approximately 
		# "invoked with WeBWorK::FakeRequest object with no `r' key"
		if ($e = Exception::Class->caught() and $e =~/object\s+with\s+no\s+.r.\s+key/ ) {
			# was asked to authenticate into a non-existent course
			die SOAP::Fault
				->faultcode('404')
				->faultstring("WebworkWebservice: Can't authenticate -- session may have timed out.")
		}
		die "Webservice.pm: Error when trying to authenticate. $e\n";
	};
###########################################################################
# security check -- check that the user is in fact at least a proctor in the course
# for TYPICAL uses, except renderProblem which has additional permitted uses.
###########################################################################

	if ( $hadValid_internal_WW2_secret && ( ! $authenOK ) ) {
		# If we have this - we want to treat the connection as authenticated
		# but for some reason it failed to authenticate... we will try to
		# hack it to pass, but this is probably broken as the session_key
		# will probably not exist
		$authenOK = 1;
		warn "HACK - we saw the internal_WW2_secret and are pretending the connection authenticated.";
		debug("HACK - we saw the internal_WW2_secret and are pretending the connection authenticated.");
	}

	$self->{authenOK}  = $authenOK;

	# For renderProblem, we allow lower level access if...
	#   we set $use_sessionDataHash to 1 above
	#   AND were then successfully authenticated.
	# (This is only possible for renderProblem.)
	if ( $use_sessionDataHash == 1 ) {

		# If we authenticated when use_sessionDataHash == 1 then
		# either this is the initial LTI connection, so we need to
		# trust the parameters (and we saved them)
		# or we are in a followup connection and were able to
		# validate a key linked to the sessionDataHash.

		$self->{authzOK} = 1;

	} else {

		# Standard behavior

		$self->{authzOK} = $authz->hasPermissions($self->{user_id}, $desired_level);

	}
	
	# Update the credentials -- in particular the session_key may have changed.
 	$self->{session_key} = $authen->{session_key};

	my $debug_message3 = join("",
		"WebworkWebservice.pm ",
		__LINE__,
		" authentication for ",
		$self->{user_id},
		" in course ",
		$self->{courseName},
		" is = ",
		$self->{authenOK},
		"\n",
		"authorization as >= $desired_level for ",
		$self->{user_id},
		" is ",
		$self->{authzOK},
		"\n",
		" authentication contains ",
		format_hash_ref($authen),
		"\n",
		"self has new data \n",
		format_hash_ref($self),
		"\n" );
	if ($UNIT_TESTS_ON) {
		print STDERR $debug_message3 ;
	}
	debug( $debug_message3 );

 # Is there a way to transmit a number as well as a message?
 # Could be useful for handling errors.
 	debug("initialize webworkXMLRPC object in: ", format_hash_ref($rh_input),"\n") if $UNIT_TESTS_ON;
 	debug("fake_r :", format_hash_ref($fake_r),"\n") if $UNIT_TESTS_ON;

	my $msg1 = "";
	if ( $use_sessionDataHash > 0 ) {
		$msg1 = "using the sessionDataHash approach";
	} elsif ( defined( $session_key ) ) {
		$msg1 = "with key $session_key";
	} else {
		$msg1 = "with provided data, NO session_key was provided.";
	}

	die "Could not authenticate user $user_id $msg1"  unless $self->{authenOK};
 	die "User $user_id does not have sufficient privileges in this course $courseName" unless $self->{authzOK};
 	return $self;
}



sub do {   # process and return result
           # make sure that credentials are returned
           # for every call
           # $result -> xmlrpcCall(command, in);
           # $result->return_object->{foo} is defined for foo = courseID userID and session_key
	my $self = shift;
	my $result = shift;
	
    $result->{session_key}  = $self->{session_key};
    $result->{userID}       = $self->{user_id};
    $result->{courseID}     = $self->{courseName};
    debug("output is ", format_hash_ref($result), "\n" ) if $UNIT_TESTS_ON;
	return($result);
}

sub r {
	my $self = shift;
	return $self->{fake_r};
}

#  Main section
#  respond to xmlrpc requests
#  Add routines for handling errors if the authentication fails 
#  or if the authorization is not appropriate.

=head2 WebworkWebservice commands

These subroutines are called directly by Apache::XMLRPC::Lite which provides
the arguments 

	$class   (always "WebworkXMLRPC" for this dispatcher)
	$in      a hash containing arguments needed for 
		authentication, authorization and for processing the request.

Each subroutine creates a webworkXMLRPC object  which performs authentication
and authorization checks.  It then calls the eponymous WebworkWebservice subroutine
to process the request.  The output of the WebworkWebservice subroutine is
passed through the WebworkXMLRPC::do() method and 
returned to Apache::XMLRPC::Lite which
sends a response to the original webservice request.


These are the commands that the WebworkWebservice will respond to. 
		

=over 4

=cut

=item searchLib

=cut

sub searchLib {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    #warn "\n incoming request to listLib:  class is ",ref($self) if $UNIT_TESTS_ON ;
  	return $self->do( WebworkWebservice::LibraryActions::searchLib($self, $in) );
}

=item listLib

=cut

sub listLib {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    #warn "\n incoming request to listLib:  class is ",ref($self) if $UNIT_TESTS_ON ;
  	return $self->do( WebworkWebservice::LibraryActions::listLib($self, $in) );
}

=item listLibraries

=cut

sub listLibraries {     # returns a list of libraries for the default course
	my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    #warn "incoming request to listLibraries:  class is ",ref($self) if $UNIT_TESTS_ON ;
  	return $self->do( WebworkWebservice::LibraryActions::listLibraries($self, $in) );
}

=item getProblemDirectories

=cut

sub getProblemDirectories {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::LibraryActions::getProblemDirectories($self,$in));
}

=item buildBrowseTree

=cut

sub buildBrowseTree {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::LibraryActions::buildBrowseTree($self,$in));
}	

=item loadBrowseTree

=cut

sub loadBrowseTree {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::LibraryActions::loadBrowseTree($self,$in));
}	

=item loadLocalLibraryTree

=cut

sub loadLocalLibraryTree {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::LibraryActions::loadLocalLibraryTree($self,$in));
}

=item getLocalProblems

=cut

sub getLocalProblems {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::LibraryActions::getLocalProblems($self,$in));	
}

=item getProblemTags

=cut

sub getProblemTags {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
		return $self->do( WebworkWebservice::LibraryActions::getProblemTags($self, $in) );
}

=item setProblemTags

=cut

sub setProblemTags {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
		return $self->do( WebworkWebservice::LibraryActions::setProblemTags($self, $in) );
}

=item assignSetToUsers

=cut

sub assignSetToUsers {
  my $class = shift;
  my $in = shift;
  my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::assignSetToUsers($self,$in));
}

=item listSets

=cut

sub listSets {
  my $class = shift;
  my $in = shift;
  my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::listLocalSets($self));
}

=item listSetProblems

=cut

sub listSetProblems {
	my $class = shift;
  	my $in = shift;
  	my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::listLocalSetProblems($self, $in));
}

=item createNewSet

=cut

sub createNewSet{
	my $class = shift;
  	my $in = shift;
  	my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::createNewSet($self, $in));
}

=item deleteProblemSet

=cut

sub deleteProblemSet{
	my $class = shift;
  	my $in = shift;
  	my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::deleteProblemSet($self, $in));
}

=item reorderProblems

=cut

sub reorderProblems{
	my $class = shift;
  	my $in = shift;
  	my $self = $class->initiate_session($in);
   	return $self->do(WebworkWebservice::SetActions::reorderProblems($self, $in));
}

=item addProblem

=cut

sub addProblem {
	my $class = shift;
  	my $in = shift;
  	my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::addProblem($self, $in));
}

=item deleteProblem

=cut

sub deleteProblem{
	my $class = shift;
  	my $in = shift;
  	my $self = $class->initiate_session($in);
  	return $self->do(WebworkWebservice::SetActions::deleteProblem($self, $in));
}

=item renderProblem

=cut

sub renderProblem {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);

    return $self->do( WebworkWebservice::RenderProblem::renderProblem($self,$in) ); 
}

=item updateProblem

=cut

sub updateProblem {
	my ($class,$in) = @_;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::SetActions::updateProblem($self,$in));
}

=item saveProblem

=cut

sub saveProblem {
	my ($class,$in) = @_;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::LibraryActions::saveProblem($self,$in));
}

=item readFile

=cut

sub readFile {
    my $class = shift;
    my $in   = shift;
    my $self = $class->initiate_session($in);
  	return $self->do( WebworkWebservice::LibraryActions::readFile($self,$in) );
}

=item tex2pdf

=cut

sub tex2pdf {
    my $class = shift;
    my $in    = shift;
    my $self  = $class->initiate_session($in);
  	return $self->do( WebworkWebservice::MathTranslators::tex2pdf($self,$in) );
}

=item createCourse

=cut

# Expecting a hash $in composed of the usual auth credentials
# plus the params specific to this function
#{
#	'userID' => 'admin',	# these are the usual 
#	'password' => 'admin',	# auth credentials
#	'courseID' => 'admin',	# used to initiate a
#	'session_key' => 'key',	# session.
#	"name": "TEST100-100",  # This will be the new course's id
#}
# Note that we log into the admin course to create courses.
sub createCourse {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::create($self, $in));
}

=item listUsers

=cut

sub listUsers{
    my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::listUsers($self, $in));

}

=item addUser

=cut

# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual 
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"firstname": "John", 
#	"lastname": "Smith", 
#	"id": "The Doctor",			# required
#	"email": "doctor@tardis",
#	"studentid": 87492466, 
#	"userpassword": "password",	# defaults to studentid if empty
#								# if studentid also empty, then no password
#	"permission": "professor",	# valid values from %userRoles in defaults.config
#								# defaults to student if empty
#}
# This user will be added to courseID
sub addUser {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::addUser($self, $in));
}

=item dropUser

=cut

# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual 
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"id": "BFYM942", 
#}
sub dropUser {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::dropUser($self, $in));
}

=item deleteUser

=cut

# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual 
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"id": "BFYM942", 
#}
sub deleteUser {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::deleteUser($self, $in));
}

=item editUser

=cut

# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"studentid": 87492466,
#	"firstname": "John",
#	"lastname": "Smith",
#	"id": "The Doctor",			# required
#	"email": "doctor@tardis",
#
#	"permission": "professor",	# valid values from %userRoles in defaults.config
#								# defaults to student if empty
#   status: 'Enrolled, audit, proctor, drop
#   section
#   recitation
#   comment
#}
sub editUser {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do(WebworkWebservice::CourseActions::editUser($self, $in));
}

=item changeUserPassword

=cut
# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"studentid": 87492466,
#	"new_password": "password"
#}



sub changeUserPassword{
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do(WebworkWebservice::CourseActions::changeUserPassword($self, $in));
}

=item sendEmail

=cut

# Expecting a hash $in composed of
#{
#	'userID' => 'admin',		# these are the usual
#	'password' => 'admin',		# auth credentials
#	'courseID' => 'Math',		# used to initiate a
#	'session_key' => 'key',		# session.
#	"studentid": 87492466,
#	"effectiveUser": "eUser"
#}



sub sendEmail{
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do(WebworkWebservice::CourseActions::sendEmail($self, $in));
}

=item getSets

=cut

sub getSets {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do(WebworkWebservice::SetActions::getSets($self, $in));
}

=item getUserSets

=cut

sub getUserSets {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do(WebworkWebservice::SetActions::getUserSets($self, $in));
}

=item saveUserSets

=cut

sub saveUserSets {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do(WebworkWebservice::SetActions::saveUserSets($self, $in));
}

=item getSet

=cut

sub getSet {
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do(WebworkWebservice::SetActions::getSet($self, $in));
}

=item updateSetProperties

=cut

sub updateSetProperties{
    my $class = shift;
    my $in = shift;
    my $self = $class->initiate_session($in);
    return $self->do(WebworkWebservice::SetActions::updateSetProperties($self, $in));
}

=item updateUserSet

=cut

sub updateUserSet {
	my $class = shift;
	my $in = shift; 
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::SetActions::updateUserSet($self,$in));
}

=item unassignSetFromUsers

=cut

sub unassignSetFromUsers {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::SetActions::unassignSetFromUsers($self,$in));
}

=item listSetUsers

=cut

sub listSetUsers {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::SetActions::listSetUsers($self,$in));
}

=item getCourseSettings

=cut

sub getCourseSettings {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::getCourseSettings($self,$in));	
}

=item updateSetting

=cut

sub updateSetting {
	my $class = shift;
	my $in = shift;
	my $self = $class->initiate_session($in);
	return $self->do(WebworkWebservice::CourseActions::updateSetting($self,$in));	
}



=back



=head2 Pass through methods which access the data in the FakeRequest object

	ce
	db
	params
	authz
	authen
	maketext 

=cut

sub ce {
	my $self = shift;
	debug("use ce") if $UNIT_TESTS_ON;
	$self->{fake_r}->{ce};
}
sub db {
	my $self = shift;
	$self->{fake_r}->{db};
}
sub param {    # imitate get behavior of the request object params method
	my $self =shift;
	my $param = shift;
	my $out = $self->{fake_r}->param($param);
	debug("use param $param => $out") if $UNIT_TESTS_ON;
	$out;
}
sub authz {
	my $self = shift;
	debug("use authz ")  if $UNIT_TESTS_ON;
	$self->{fake_r}->{authz};
}
sub authen {
	my $self = shift;
	debug("use authen ")  if $UNIT_TESTS_ON;
	$self->{fake_r}->{authen};
}
sub maketext {
	my $self = shift;
	#$self->{language_handle}->maketext(@_);
	debug("use maketext")  if $UNIT_TESTS_ON;
	&{ $self->{fake_r}->{language_handle} }(@_);
}


=head2 WebworkXMLRPC Utility methods

	format_hash_ref
	
=cut


sub format_hash_ref {
	my $hash = shift;
	my $out_str="";
	my $count =4;
	foreach my $key ( sort keys %$hash) {
		my $value = defined($hash->{$key})? $hash->{$key}:"--";
		$out_str.= " $key=>$value ";
		$count--;
		unless($count) { $out_str.="\n  ";$count =4;}
	}
	$out_str;
}


# -- SOAP::Lite -- guide.soaplite.com -- Copyright (C) 2001 Paul Kulchenko --
# test responses

# sub hi {   shift if UNIVERSAL::isa($_[0] => __PACKAGE__); # grabs class reference                 
#   return "hello, world";     
# }
# sub hello2 { shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
# 	#print "Receiving request for hello world\n";
# 	return "Hello world2";
# }
# sub bye {shift if UNIVERSAL::isa($_[0] => __PACKAGE__);  
# 	return "goodbye, sad cruel world";
# }
# 
# sub languages {shift if UNIVERSAL::isa($_[0] => __PACKAGE__);
# 	return ["Perl", "C", "sh"];   
# }                               
# 
# sub echo_self {
# 	my $self = shift;
# }
# 
# sub echo { 
#     return join("|",("begin ", WebworkWebservice::pretty_print_rh(\@_), " end") );
# }
# 
# sub pretty_print_rh {
# 	WebworkWebservice::pretty_print_rh(@_);
# }
# 

# 
# package Filter;
# # I believe that this used to handle the processing of xmlrpc message
# # possibly replaced by SOAP?
# 
# sub is_hash_ref {
# 	my $in =shift;
# 	my $save_SIG_die_trap = $SIG{__DIE__};
#     $SIG{__DIE__} = sub {CORE::die(@_) };
# 	my $out = eval{  %{   $in  }  };
# 	$out = ($@ eq '') ? 1 : 0;
# 	$@='';
# 	$SIG{__DIE__} = $save_SIG_die_trap;
# 	$out;
# }
# sub is_array_ref {
# 	my $in =shift;
# 	my $save_SIG_die_trap = $SIG{__DIE__};
#     $SIG{__DIE__} = sub {CORE::die(@_) };
# 	my $out = eval{  @{   $in  }  };
# 	$out = ($@ eq '') ? 1 : 0;
# 	$@='';
# 	$SIG{__DIE__} = $save_SIG_die_trap;
# 	$out;
# }
# sub filterObject {
# 
#     my $is_hash = 0;
#     my $is_array =0;
# 	my $obj = shift;
# 	#print "Enter filterObject ", ref($obj), "\n";
# 	my $type = ref($obj);
# 	unless ($type) {
# 		#print "leave filterObject with nothing\n";
# 		return($obj);
# 	}
# 
# 
# 	if ( is_hash_ref($obj)  ) {
# 	    #print "enter hash ", %{$obj},"\n";
# 	    my %obj_container= %{$obj};
# 		foreach my $key (keys %obj_container) {
# 			$obj_container{$key} = filterObject( $obj_container{$key} );
# 			#print $key, "  ",  ref($obj_container{$key}),"   ", $obj_container{$key}, "\n";
# 		}
# 		#print "leave filterObject with HASH\n";
# 		return( bless(\%obj_container,'HASH'));
# 	};
# 
# 
# 
# 	if ( is_array_ref($obj)  ) {
# 		#print "enter array ( ", @{$obj}," )\n";
# 		my @obj_container= @{$obj};
# 		foreach my $i (0..$#obj_container) {
# 			$obj_container[$i] = filterObject( $obj_container[$i] );
# 			#print "\[$i\]  ",  ref($obj_container[$i]),"   ", $obj_container[$i], "\n";
# 		}
# 		#print "leave filterObject with ARRAY\n";
# 		return( bless(\@obj_container,'ARRAY'));
# 	};
#     
# }
# 

1;
