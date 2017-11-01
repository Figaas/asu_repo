# /usr/bin/perl

use Switch;
use File::Copy::Recursive qw(rcopy fcopy dircopy dirmove fmove);

$HIDDEN_REPO_DIR = ".repo";
$COPIES_DIR = "$HIDDEN_REPO_DIR/copies";
@REPO_COMMANDS_UNCREATED = qw/init help/;
@REPO_COMMANDS_CREATED = qw/copy back log/;
$COMMAND = $ARGV[0];

# validate command
if ( grep( /^$COMMAND$/, @REPO_COMMANDS_UNCREATED ) ) {
  switch ( $COMMAND ) {
    case "init"		{ init_repo(); }
    case "help"		{ print_help_message(); }
  }
}
elsif ( grep( /^$COMMAND$/, @REPO_COMMANDS_CREATED ) ) {
  # check if repo directory exist, to work on repo
  if (-d $HIDDEN_REPO_DIR) {
    switch ($COMMAND) {
      case "copy"		{ make_copy(@ARGV[1..2]); }
      case "back"   { revert_repo_state(); }
      case "log"		{ print "log"; }
    }
  }
  else {
    print "First create repository with \"perl repo init\"\n"
  }
}
else {
  print  "$COMMAND: command not found\n".
          "If you need help type \"perl repo.pl help\"\n";
}

sub init_repo {
  log_message("Init repo");
  unless(-e $HIDDEN_REPO_DIR) {
    mkdir $HIDDEN_REPO_DIR, 0755;
    mkdir $COPIES_DIR, 0755;
    open LOG, ">$HIDDEN_REPO_DIR/log";
  }
  else{
    print "Can't create new repository.\n".
          "Probably, repository already exist or you haven't permissions to create it.\n";
  }
}

sub make_copy {
  if ( scalar @ARGV < 4 ){
    log_message("Copy creating");
    $new_dir = make_dir_for_copy();
    $to_copy = @ARGV[1];
    print "$new_dir \n$to_copy\n";
    rcopy($to_copy, "$new_dir/$to_copy");
  }
  else {
    print "Invalid number of arguments.
    You should save your files in this way:
    save [path] [message]\n";
  }
}

sub make_dir_for_copy {
  $copy_id = count_copy_id();
  $new_dir_name = "$COPIES_DIR/$copy_id";
  mkdir $new_dir_name, 0755;
  return $new_dir_name;
}

sub count_copy_id {
  my @copies_list = sort(glob("$COPIES_DIR/*"));
  $last_dir = @copies_list[-1];
  $last_dir =~ s/$COPIES_DIR\///;
  $copy_id = sprintf("%03d", $last_dir + 1);
  return $copy_id;
}

sub print_help_message {
  print "repo - script to creating and managing simple file reposiory

Usage: perl repo command [options]

Commands:
  init                   - create new repository
  save [path] [message]  - make copies of files
  back [id]              - back to saved state of repository
  log  [path]            - log informations about all copies of file / directory
";
}

sub log_message {
  print("LOG: " . shift . "\n");
}
print dircopy("asd", ".repo/copies/001/asd");
