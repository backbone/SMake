#!/usr/bin/perl -w
# Code has been taken from this two webpages:
# http://bytes.com/topic/python/answers/155853-stripping-c-style-comments-using-python-regexp
# http://collectns.blogspot.com/2011/05/perl-script-to-remove-comments-from-c.html

$/ = undef;   # no line delimiter
$_ = <>;   # read entire file

s! ((['"]) (?: \\. | .)*? \2) | # skip quoted strings
   /\* .*? \*/ |  # delete C comments
   // [^\n\r]*   # delete C++ comments
 ! $1 || ' '   # change comments to a single space
 !xseg;    # ignore white space, treat as single line
    # evaluate result, repeat globally
print;
