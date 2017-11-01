# /usr/bin/perl

use Switch;
use File::Copy::Recursive qw(rcopy fcopy dircopy dirmove fmove);
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
