# /usr/bin/perl

use File::Find::Rule;
use File::Copy "cp";
use File::Copy::Recursive qw(rcopy pathempty);
use File::Compare;
use List::MoreUtils "uniq";
use Switch;
use Stat::lsMode;
use warnings;

$HIDDEN_REPO_DIR = ".repo";
$COPIES_DIR = "$HIDDEN_REPO_DIR/copies";
@UNCREATED_REPO_COMMANDS = qw/init help/;
@CREATED_REPO_COMMANDS = qw/copy restore remove log/;
$command = $ARGV[0];
unless ($command) {
  $command = "";
}

# validate command
if ( grep( /^$command$/, @UNCREATED_REPO_COMMANDS ) ) {
  switch ( $command ) {
    case "init"		{ init_repo(); }
    case "help"		{ print_help_message(); }
  }
} # ( grep( /^$command$/, @UNCREATED_REPO_COMMANDS ) )
elsif ( grep( /^$command$/, @CREATED_REPO_COMMANDS ) ) {
  # check if repo directory exist, to work on repo
  if (-d $HIDDEN_REPO_DIR) {
    switch ($command) {
      case "copy"		{ make_copy(); }
      case "restore"   { revert_if_possible(); }
      case "remove" { remove_path(); }
      case "log"		{ log_list(); }
    }
  }
  else { # if (-d $HIDDEN_REPO_DIR)
    print "First create repository with \"perl repo init\"\n"
  }
}
else { # ( grep( /^$command$/, @CREATED_REPO_COMMANDS ) )
  print  "$command: command not found\n".
          "If you need help type \"perl repo.pl help\"\n";
}
## init function
sub init_repo {
  log_message("Init repo");
  unless(-e $HIDDEN_REPO_DIR) {
    eval {
      mkdir $HIDDEN_REPO_DIR, 0755 or die "INIT ERROR";
      mkdir $COPIES_DIR, 0755 or die "INIT ERROR";
      open $_, ">$HIDDEN_REPO_DIR/log" or die "INIT ERROR";
    };
    if ($@) {
      print "Can't create new repository\n";
      rmdir $COPIES_DIR;
      rmdir $HIDDEN_REPO_DIR;
    }
  }
  else{
    print "Can't create new repository!\n".
          "Repository already exist.\n";
  }
}

## copy functions
sub make_copy {
  if ( scalar @ARGV < 3 or ( scalar @ARGV < 5 and "$ARGV[-2]" eq "-m" ) ){
    log_message("Creating copy");
    my $new_dir = '';
    eval {
      $new_dir = create_dir_for_copy();
      my $to_copy = $ARGV[1];
      save_available($to_copy, $new_dir);
      rcopy($to_copy, "$new_dir/$to_copy");
    };
    if ($@) {
      print "Can't create copy\n";
      rmdir $new_dir;
    }
    else {
      create_message($new_dir)
    }

  }
  else {
    print "Invalid number of arguments.
Save files in this way:
copy [path] [-m \"message\"]\n";
  }
}

sub create_dir_for_copy {
  my $copy_id = count_copy_id();
  my $new_dir_name = "$COPIES_DIR/$copy_id";
  mkdir $new_dir_name, 0755 or die "COPY ERROR";
  return $new_dir_name;
}

sub count_copy_id {
  my @copies_list = sort(glob("$COPIES_DIR/*"));
  my $last_dir = $copies_list[-1];
  $last_dir =~ s/$COPIES_DIR\///;
  my $copy_id = sprintf("%04d", $last_dir + 1);
  return $copy_id;
}

sub save_available {
  my $to_copy = $_[0];
  my $copy_dir = $_[1];
  my @paths = generate_available_list($to_copy);
  save_available_to_file("$copy_dir/.available", @paths)
}

sub save_available_to_file {
  $save_path = shift @_;
  @paths = @_;
  open(my $fh, '>', $save_path) or die "COPY ERROR";
  foreach my $path (@paths) {
    print $fh "$path\n";
  }
  close $fh;
}

sub generate_available_list {
  $to_copy_path = $_[0];
  $last_available_list_file = get_last_copy_file(".available");

  my @paths = ();
  if (-d $to_copy_path){
    push @paths, File::Find::Rule->in($to_copy_path);
  }
  elsif (-e $to_copy_path) {
    push @paths, File::Find::Rule->name($to_copy_path)->in(".");
  }
  else {
    print "$to_copy_path: not exist\n";
    die "COPY ERROR";
  }
  open(my $fh, '<', $last_available_list_file);
  while(my $row = <$fh>){
    $row =~ s/^\s+|\s+$//g;         # trim whitespaces
    push @paths, $row;
  }
  close $fh;
  return grep /\S/, uniq(@paths);
}

sub get_last_copy_file {
  my $file = $_[0];
  my @all_copies = sort(File::Find::Rule->file->name($file)->in($COPIES_DIR));
  return $all_copies[-1];
}

sub create_message {
  $msg_file = "$_[0]" . "/.msg";
  open(my $fh, ">$msg_file");
  if ("$ARGV[-2]" eq "-m") {
    print $fh "$ARGV[-1]\n";
  }
}

## remove funtions
sub remove_path {
  $last_available_list_file = get_last_copy_file(".available");
  $to_remove_path = $ARGV[1];

  my @paths_to_remove = ();
  my @paths = ();
  if (-d $to_remove_path){
    push @paths_to_remove, File::Find::Rule->in($to_remove_path);
  }
  elsif (-e $to_remove_path) {
    push @paths_to_remove, File::Find::Rule->name($to_remove_path)->in(".");
  }
  else {
    print "Can't remove \'$to_remove_path\': not exist\n";
    die "REMOVE ERROR";
  }

  @new_available_list = generate_new_available($last_available_list_file, @paths_to_remove);
  if (pathempty($to_remove_path) eq 2 ){
    unlink $to_remove_path;
  }
  else {
    rmdir $to_remove_path;
  }
  save_available_to_file($last_available_list_file, @new_available_list);
}

sub generate_new_available {
  my @paths = ();
  my $last_available_list_file = shift @_;
  my @all_paths_to_remove = @_;

  open(my $fh, '<', $last_available_list_file);
  while(my $row = <$fh>){
    $row =~ s/^\s+|\s+$//g;         # trim whitespaces
    push @paths, $row;
  }
  close $fh;

  my %lookup;
  my @result;
  @lookup{@all_paths_to_remove} = ();
  foreach my $elem (@paths) {
    push(@result, $elem) unless exists $lookup{$elem};
  }
  return return grep /\S/, @result;
}

## help function
sub print_help_message {
  print "repo - script to creating and managing simple file reposiory

Usage: perl repo command [options]

Commands:
  init                              - create new repository
  save [path] [-m \"message\"]      - make copies of files
  remove [path]                     - remove files from last copy
  log  [path]                       - log informations about all copies of file / directory
  restore [id]                         - restore to saved state of repository
";
}

## log function
sub log_list {
  $log_type = $ARGV[1];
  switch ( $log_type ) {
    case "copies"		{ log_copies() }
    case "id"   		{ log_id(); }
    else	          {      print "Unknown command. Possible commands:
  copies  - list all copies
  id      - list info about files in specified copy\n";
    }
  }
}

sub log_copies {
  foreach my $msg_file (sort(File::Find::Rule->name(".msg")->in($COPIES_DIR))) {
      print get_id($msg_file) . " - \"" . read_message($msg_file) . "\"\n";
  }
}

sub get_id {
  my $last_dir = $_[0];
  $last_dir =~ s/$COPIES_DIR\///;
  $last_dir =~ s/\/\.msg//;
  return $last_dir;
}

sub read_message() {
  my $msg_file = $_[0];
  my $msg;
  open my $fh, "<$msg_file";
  $msg = <$fh>;
  unless ($msg) {
    $msg = "";
  }
  $msg =~ s/^\s+|\s+$//g;
  return $msg;
}

sub log_id() {
  my $id = $ARGV[2];
  my $valid_id = validate_id($id);
  if ($valid_id) {
    @list_to_log = find_paths_to_avaliable_files($id);
    print "Mode\t\tLast modification\t\tSize(Kb)\tName\n";
    print "----------------------------------------------------------------------\n";
    for my $path (@list_to_log) {
      @attrs = stat($path);
      $mode = file_mode($path);
      $last_mod = localtime($attrs[10]);
      $size = sprintf("%.2f", $attrs[7] / 1024.0);
      $path =~ s/$COPIES_DIR\/\d{4}\///;
      print "$mode\t$last_mod\t$size\t\t$path\n";
    }
  }
}

sub validate_id {
  $id = $_[0];
  return (scalar File::Find::Rule->name($id)->maxdepth(1)->in($COPIES_DIR) eq 1)
}

sub find_paths_to_avaliable_files {
  my $id = $_[0];
  my $path_to_avaliable = "$COPIES_DIR/$id/\.available";
  my @avaliable_list = load_avaliable_to_list($path_to_avaliable);
  my @paths_to_avaliable = ();
  for $path (@avaliable_list) {
    $founded_path = find_path_to_copy($path, $id);
    if ($founded_path ne ""){
      push @paths_to_avaliable, find_path_to_copy($path, $id);
    }
  }
  return @paths_to_avaliable;
}

sub load_avaliable_to_list {
  my $path_to_avaliable = $_[0];
  my @paths;
  open(my $fh, "<$path_to_avaliable");
  while(my $row = <$fh>){
    $row =~ s/^\s+|\s+$//g;         # trim white spaces
    push @paths, $row;
  }
  close $fh;
  return @paths;
}

sub find_path_to_copy {
  my $path_to_find = $_[0];
  my $id = $_[1];
  for my $copy_dir (find_older_copies($id)) {
    if (-e "$copy_dir/$path_to_find") {
      return "$copy_dir/$path_to_find";
    }
    unless (avaliable_yet($copy_dir, $path_to_find)) {
      last;
    }
  }
  return "";
}

sub find_older_copies {
    my $id = $_[0];
    my $last_path = "$COPIES_DIR/$id";
    my @all_copies = sort(File::Find::Rule->mindepth(1)->maxdepth(1)->in($COPIES_DIR));
    return sort {$b cmp $a} grep { ("$_" cmp $last_path) < 1 } @all_copies;
}

sub avaliable_yet {
  my $copy_dir = $_[0];
  my $to_find = $_[1];
  my $path_to_available = "$copy_dir/\.available";
  my @avaliable_list = load_avaliable_to_list($path_to_available);
  return grep( /^$to_find$/, @avaliable_list );
}

## restore functions
sub revert_if_possible {
  my $id = $ARGV[1];
  my $if_valid_id = validate_id($id);
  my $is_changes_saved = validate_changes();
  if ($if_valid_id and $is_changes_saved) {
    my @last_available_files = find_paths_to_avaliable_files($id);
    for $path_to_copy (@last_available_files) {
      my $original_file = $path_to_copy;
      $original_file =~ s/$COPIES_DIR\/\d{4}\///;
      cp($path_to_copy, $original_file);
    }
  }
  else {
    print "Firstly save changes!"
  }
}

sub validate_changes {
  my $last_copy_available_file = get_last_copy_file(".available");
  my $last_id = extract_id($last_copy_available_file);
  my @last_available_files = find_paths_to_avaliable_files($last_id);
  for $path_to_copy (@last_available_files) {
    my $original_file = $path_to_copy;
    $original_file =~ s/$COPIES_DIR\/\d{4}\///;
    if ( -f $path_to_copy and
         -e $original_file and
         compare($original_file, $path_to_copy) != 0) {
           print $original_file;
      return 0;
    }
  }
  return 1;
}

sub extract_id {
  $id = $_[0];
  $id =~ s/$COPIES_DIR\///;
  return substr $id, 0, 4;
}

## general functions
sub log_message {
  print("LOG: " . shift . "\n");
}
