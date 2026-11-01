#!/bin/zsh
# Prints the height of the MacBook notch area in points, rounded up; 0 when no screen
# has a notch. Its height in points changes with the display resolution, so sketchybarrc
# measures it instead of hard-coding it.

osascript -l JavaScript -e '
  ObjC.import("AppKit");
  var screens = $.NSScreen.screens;
  var tallest = 0;
  for (var i = 0; i < screens.count; i++) {
    tallest = Math.max(tallest, screens.objectAtIndex(i).safeAreaInsets.top);
  }
  Math.ceil(tallest);
'
