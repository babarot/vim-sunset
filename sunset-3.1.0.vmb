" Vimball Archiver by Charles E. Campbell, Jr., Ph.D.
UseVimball
finish
plugin/sunset.vim	[[[1
237
" sunset.vim - Automatically set background on local sunrise/sunset time.
"
"  Maintainer: Alastair Touw <alastair@touw.me.uk>
"     Website: https://github.com/amdt/sunset
"     License: Distributed under the same terms as Vim. See ':help license'.
"     Version: 3.1.0
" Last Change: 2015-02-28
"       Usage: See 'doc/sunset.txt' or ':help sunset' if installed.
"
" Sunset follows the Semantic Versioning specification (http://semver.org).
"
" GetLatestVimScripts: 4277 22933 :AutoInstall: Sunset

let s:save_cpo = &cpo
set cpo&vim

" Clean up 'cpoptions' wherever this script should be terminated.
function! s:restore_cpoptions()
  let &cpo = s:save_cpo
  unlet s:save_cpo
endfunction

if exists('g:loaded_sunset')
  call s:restore_cpoptions()
  finish
endif
let g:loaded_sunset = 1

scriptencoding utf-8

let s:errors = []

if v:version < 703
  call add(s:errors, 'Requires Vim 7.3')
endif

if !has('float')
  call add(s:errors, 'Requires Vim be compiled with +float support.')
endif

if !exists('*strftime')
  call add(s:errors, 'Requires a system with strftime()')
endif

" Get the utc offset from the time zone offset
if !exists('g:sunset_utc_offset')
    let g:sunset_utc_offset = str2nr(strftime("%z")[:2])
endif

let s:required_options = ['g:sunset_latitude',
    \ 'g:sunset_longitude',
    \ 'g:sunset_utc_offset']

for option in s:required_options
  if exists(option)
    call filter(s:required_options, 'v:val != option')
  endif
endfor

if !empty(s:required_options)
  for option in s:required_options
    call add(s:errors, printf('%s missing! See '':help %s'' for more details.',
        \ option, option))
  endfor
endif

if !empty(s:errors)
  for error in s:errors
    echoerr error
  endfor
  call s:restore_cpoptions()
  finish
endif

let s:PI = 3.14159265359
let s:ZENITH = 90
let s:SUNRISE = 1
let s:SUNSET = 0
let s:CIVIL_TWILIGHT_DURATION = 30
lockvar s:PI
lockvar s:ZENITH
lockvar s:SUNRISE
lockvar s:SUNSET
lockvar s:CIVIL_TWILIGHT_DURATION

let s:DAYTIME_CHECKED = 0
let s:NIGHTTIME_CHECKED = 0

function! s:hours_and_minutes_to_minutes(hours, minutes)
  return (a:hours * 60) + a:minutes
endfunction

function! s:daytimep(current_time)
  if a:current_time <= (s:SUNRISE_TIME - (s:CIVIL_TWILIGHT_DURATION / 2))
      \ || a:current_time >= (s:SUNSET_TIME + (s:CIVIL_TWILIGHT_DURATION / 2))
    return 0
  else
    return 1
  endif
endfunction

" This algorithm for finding the local sunrise and sunset times published
" in the Almanac for Computers, 1990, by the Nautical Almanac Office of the
" United States Naval Observatory, as detailed
" here: http://williams.best.vwh.net/sunrise_sunset_algorithm.htm
function! s:calculate(sunrisep)
  function! s:degrees_to_radians(degrees)
    return (s:PI / 180) * a:degrees
  endfunction

  function! s:radians_to_degrees(radians)
    return (180 / s:PI) * a:radians
  endfunction

  function! s:minutes_from_decimal(number)
    return float2nr(60.0 / 100 * (a:number - floor(a:number)) * 100)
  endfunction

  " 1. First calculate the day of the year
  let l:day_of_year = strftime('%j')

  " 2. Convert the longitude to hour value and calculate an approximate time
  let l:longitude_hour = g:sunset_longitude / 15

  let l:n = a:sunrisep ? 6 : 18
  let l:approximate_time = l:day_of_year + ((l:n - l:longitude_hour) / 24)

  " 3. Calculate the Sun's mean anomaly
  let l:mean_anomaly = (0.9856 * l:approximate_time) - 3.289

  " 4. Calculate the Sun's true longitude
  let l:true_longitude = l:mean_anomaly
      \ + (1.916 * sin(s:degrees_to_radians(l:mean_anomaly)))
      \ + (0.020 * sin(s:degrees_to_radians(2)
      \ * s:degrees_to_radians(l:mean_anomaly)))
      \ + 282.634

  if l:true_longitude < 0
    let l:true_longitude = l:true_longitude + 360
  elseif l:true_longitude >= 360
    let l:true_longitude = l:true_longitude - 360
  endif

  " 5a. Calculate the Sun's right ascension
  let l:right_ascension = s:radians_to_degrees(atan(0.91764
      \ * tan(s:degrees_to_radians(l:true_longitude))))

  if l:right_ascension < 0
    let l:right_ascension = l:right_ascension + 360
  elseif l:right_ascension >= 360
    let l:right_ascension = l:right_ascension - 360
  endif

  " 5b. Right ascension value needs to be in the same quadrant as
  " l:true_longitude
  let l:true_longitude_quadrant = (floor(l:true_longitude / 90)) * 90
  let l:right_ascension_quadrant = (floor(l:right_ascension / 90)) * 90
  let l:right_ascension = l:right_ascension
      \ + (l:true_longitude_quadrant - l:right_ascension_quadrant)

  " 5c. Right ascension value needs to be converted into hours
  let l:right_ascension = l:right_ascension / 15

  " 6. Calculate the Sun's declination
  let l:sin_declination = 0.39782 * sin(s:degrees_to_radians(l:true_longitude))

  let l:cos_declination = cos(asin(s:degrees_to_radians(l:sin_declination)))

  " 7a. Calculate the Sun's local hour angle
  let l:cos_hour_angle = (cos(s:degrees_to_radians(s:ZENITH))
      \ - (l:sin_declination * sin(s:degrees_to_radians(g:sunset_latitude))))
      \ / (l:cos_declination * cos(s:degrees_to_radians(g:sunset_latitude)))

  " 7b. Finish calculating H and convert into hours
  if a:sunrisep
    let l:hour = 360 - s:radians_to_degrees(acos(l:cos_hour_angle))
  else
    let l:hour = s:radians_to_degrees(acos(l:cos_hour_angle))
  endif

  let l:hour = l:hour / 15

  " 8. Calculate local mean time of rising/setting
  let l:mean_time = l:hour
      \ + l:right_ascension
      \ - (0.06571 * l:approximate_time)
      \ - 6.622

  " 9. Adjust back to UTC
  let l:universal_time = l:mean_time - l:longitude_hour

  " 10. Convert l:universal_time value to local time zone of latitude/longitude
  let l:local_time = l:universal_time + g:sunset_utc_offset

  if l:local_time < 0
    let l:local_time = l:local_time + 24
  elseif l:local_time >= 24
    let l:local_time = l:local_time - 24
  endif

  return s:hours_and_minutes_to_minutes(float2nr(l:local_time),
      \ s:minutes_from_decimal(l:local_time))
endfunction

function! s:sunset()
  if s:daytimep(s:hours_and_minutes_to_minutes(strftime('%H'), strftime('%M')))
    if s:DAYTIME_CHECKED != 1
      if exists('*Sunset_daytime_callback')
        call Sunset_daytime_callback()
      else
        set background=light
      endif

      let s:DAYTIME_CHECKED = 1
      let s:NIGHTTIME_CHECKED = 0
    endif
  else
    if s:NIGHTTIME_CHECKED != 1
      if exists('*Sunset_nighttime_callback')
        call Sunset_nighttime_callback()
      else
        set background=dark
      endif

      let s:NIGHTTIME_CHECKED = 1
      let s:DAYTIME_CHECKED = 0
    endif
  endif
endfunction

let s:SUNRISE_TIME = s:calculate(s:SUNRISE)
let s:SUNSET_TIME = s:calculate(s:SUNSET)
call s:sunset()

autocmd CursorHold * nested call s:sunset()

call s:restore_cpoptions()
doc/sunset.txt	[[[1
321
*sunset.txt*        Automatically set background on local sunrise/sunset time.

FRONT MATTER                                           *sunset-front-matter*

     Maintainer: Alastair Touw <alastair@touw.me.uk>
        License: Distributed under the same terms as Vim. See |license|.
        Version: 3.1.0
    Last Change: 2015-02-28

INTRODUCTION AND USAGE                    *sunset* *sunset-introduction-usage*

Sunset automatically sets 'background' when the sun rises and sets, and also
when you start Vim. When the sun is up, or rises, it’ll
‘set background=light’. When the sun is down, or sets,
it’ll ‘set background=dark’.

Sunset can also change your |colorscheme|, your Powerline theme, or do
anything else you can think of. See |'Sunset_daytime_callback()'| and
|'Sunset_nighttime_callback()'| for details.

So as not to interrupt you, Sunset waits for four seconds after you’ve pressed
a key or left insert mode (ie. on the |CursorHold| event) before changing the
background. If you change your background during the day or night, it’ll
respect that.

You must set some options in your `.vimrc` for Sunset to work, so
please read on to |sunset-configuration| for details.

CONTRIBUTIONS                                         *sunset-contributions*

If you feel that Sunset can be improved, pull requests and issues are
appreciated and humbly requested, on GitHub at: https://github.com/amdt/sunset

CONTENTS                                                   *sunset-contents*

      i. Front Matter . . . . . . . . . . . . . . . .  |sunset-front-matter|
     ii. Introduction & Usage . . . . . . . . .  |sunset-introduction-usage|
    iii. Contributions  . . . . . . . . . . . . . . . |sunset-contributions|
     iv. Contents . . . . . . . . . . . . . . . . . . . .  |sunset-contents|
      1. Installation . . . . . . . . . . . . . . . .  |sunset-installation|
          a) With a Plugin Manager  . . |sunset-installation-plugin-manager|
          b) Using Vimball  . . . . . . . . .  |sunset-installation-vimball|
          c) Manually . . . . . . . . . . . . . |sunset-installation-manual|
      2. Requirements . . . . . . . . . . . . . . . .  |sunset-requirements|
      3. Configuration (required) . . . . .  |sunset-configuration-required|
          a) ‘g:sunset_latitude’ &  . . . . . . . . . .  |'sunset_latitude'|
             ‘g:sunset_longitude’ . . . . . . . . . . . |'sunset_longitude'|
          b) ‘g:sunset_utc_offset’  . . . . . . . . .  |'sunset_utc_offset'|
      4. Configuration (optional) . . . . .  |sunset-configuration-optional|
          a) ‘g:loaded_sunset’  . . . . . . . . . . . . .  |'loaded_sunset'|
          b) ‘Sunset_daytime_callback()’ &     |'Sunset_daytime_callback()'|
             ‘Sunset_nighttime_callback()’   |'Sunset_nighttime_callback()'|
      5. A Reminder on Privacy  . . . . . . . . . . . . . . |sunset-privacy|
      6. Version History  . . . . . . . . . . . . . |sunset-version-history|
      7. Known Issues . . . . . . . . . . . . . . . .  |sunset-known-issues|
      8. License  . . . . . . . . . . . . . . . . . . . . . |sunset-license|
      9. Credits  . . . . . . . . . . . . . . . . . . . . . |sunset-credits|

INSTALLATION                                           *sunset-installation*

With a Plugin Manager:                  *sunset-installation-plugin-manager*

Vundle: ~

If you don’t already have a preferred manager, I recommend installing Vundle
(https://github.com/gmarik/vundle). Once done, add the declaration for Sunset
to your `.vimrc`:
>
    Bundle 'amdt/sunset'
<
And install:
>
    :BundleInstall
<
Pathogen: ~

If you’re using Pathogen, simply extract the archive to `$HOME/.vim/bundle` or
better yet, clone the Git repository. In a UNIX shell, for example:
>
    cd ~/.vim/bundle
    git clone git://github.com/amdt/sunset.git
<
Using Vimball:                                 *sunset-installation-vimball*

Open the Vimball with Vim. For example, from a UNIX shell you might run:
>
    vim sunset.vba
<
Once loaded in Vim, run the following two commands:
>
    :so %
    :q
<
Manually:                                       *sunset-installation-manual*

Copy the files in the included zip archive into your 'runtimepath' as per the
following figure. The directory tree for Sunset is on the left, and the
resulting tree in your own home directory on the right:

    /doc                         :    `$HOME/.vim/doc`
        sunset.txt               :        sunset.txt
    /plugin                      :    `$HOME/.vim/plugin`
        sunset.vim               :        sunset.vim
    CONTRIBUTING.markdown        :
    README.markdown              :

Place `sunset.txt` under `$HOME/.vim/doc` and `sunset.vim` under
`$HOME/.vim/plugin` where `$HOME` is the location of your `.vim` directory.
You can find this by typing ‘|:echo| |$HOME|’. You can safely discard of
`README.markdown` and `CONTRIBUTING.markdown`.

REQUIREMENTS                                           *sunset-requirements*

    * Vim 7.3.
    * Vim compiled with |+float| support. Use |:version| to check if this
      feature is available in your build.
    * A system with |strftime()|, with the following format options:
        - %j returns the current day of the year.
        - %H returns the current hour of the day in 24-hour time.
        - %M returns the current minute of the hour.

Note: If your system’s |strftime()| differs, please open an issue on the
GitHub page at https://github.com/amdt/sunset/issues with details.

Recommended: ~

    * A |colorscheme| with both light and dark variants, such as Solarized
      (https://github.com/altercation/vim-colors-solarized) or Hemisu
      (https://github.com/noahfrederick/Hemisu).

CONFIGURATION (REQUIRED)                     *sunset-configuration-required*
                                                      *sunset_configuration*

'g:sunset_latitude' & 'g:sunset_longitude'               *'sunset_latitude'*
                                                        *'sunset_longitude'*

Note: If you push your dotfiles to (for example) GitHub, please
see |sunset-privacy|.

The latitude and longitude of your location in decimal. Values North and East
must be positive values, those South and West must be negative.

London, for example, lies at 51 degrees, 30 minutes North; and 7 minutes West.

In decimal, this is 51.5 degrees North, 0.1167 degrees West.

If you lived in London, you might set these options as follows:
>
    let g:sunset_latitude = 51.5
    let g:sunset_longitude = -0.1167
<
If you lived in Tokyo (35 degrees, 40 minutes and 12 seconds North; 139
degrees, 46 minutes and 12 seconds East), you might set these options
as follows:
>
    let g:sunset_latitude = 35.67
    let g:sunset_longitude = 139.8
<
Note: Don’t forget, negative values South and West.

CONFIGURATION (OPTIONAL)                     *sunset-configuration-optional*

'g:sunset_utc_offset'                                  *'sunset_utc_offset'*

Sunset gets the local timezone from your system.  You can override this by
setting the difference in hours between your timezone and Coordinated
Universal Time (UTC).

For example:
>
    let g:sunset_utc_offset = 0 " London
    let g:sunset_utc_offset = 1 " London (British Summer Time)
    let g:sunset_utc_offset = 9 " Tokyo
<
Note: Sunset does not handle any daylight savings civil times.

'g:loaded_sunset'                                          *'loaded_sunset'*

Set to a non-0 value to disable Sunset, for example:
>
    let g:loaded_sunset = 1
<

'Sunset_daytime_callback()' &                  *'Sunset_daytime_callback()'*
'Sunset_nighttime_callback()'                *'Sunset_nighttime_callback()'*

These two callbacks can be used to override Sunset’s behaviour by adding your
own. If you define either of these callbacks, Sunset’s default behaviour of
setting 'background' will be ignored, and your function will be called
instead.

For example, perhaps you want to use one |colorscheme| during the day, and
another at night:
>
    function! Sunset_daytime_callback()
        colorscheme Hemisu
    endfunction

    function! Sunset_nighttime_callback()
        colorscheme Solarized
    endfunction
<

You could change the theme used by Powerline*:
>
    function! Sunset_daytime_callback()
        if exists(':PowerlineReloadColorscheme')
            let g:Powerline_colorscheme = 'solarizedLight'
            PowerlineReloadColorscheme
        endif
    endfunction

    function! Sunset_nighttime_callback()
        if exists(':PowerlineReloadColorscheme')
            let g:Powerline_colorscheme = 'solarizedDark'
            PowerlineReloadColorscheme
        endif
    endfunction
>

* Powerline is ‘the ultimate vim statusline utility’. It’s very cool; you
  should check it out: https://github.com/Lokaltog/vim-powerline

A REMINDER ON PRIVACY                                       *sunset-privacy*

For those of us who publish our dotfiles on (for example) GitHub, please take
this as a gentle reminder that out of habit you might be about to publish your
whereabouts to the greater public. If this concerns you, using the location of
your nearest large city might suffice; Sunset will be plenty accurate enough.

VERSION HISTORY                                     *sunset-version-history*

Sunset follows the Semantic Versioning specification (http://semver.org).

3.1.0 (Sun Feb 27, 2015) ~

    - Made 'g:sunset_utc_offset' optional
      (thanks to 'andreax79': https://github.com/amdt/sunset/pull/11)
    - Fixed an issue that caused a 'E122' error with the 'restore_cpoptions'
      function

3.0.0 (Sun Feb 22, 2015) ~

    - Fixed an issue where |cpoptions| may not be restored when the script
      finishes early
    - Updated the function names for the |'Sunset_daytime_callback()'| and
      |'Sunset_nighttime_callback()'| callbacks to match changes to the VimL
      interpreter (https://github.com/amdt/sunset/issues/9)

2.0.1 (Thu May 8, 2014) ~

    - Fixed an issue where versions of Vim greater than 7.4.260 would not
      allow this script to run. (https://github.com/amdt/sunset/issues/8)

2.0.0 (Sat Jan 12, 2013) ~

    - Sunset now switches your background (or calls your callbacks) mid-way
      through Civil Twilight time.
    - Note: Sunset 2.0.0 breaks compatibility with previous versions of
      Sunset for users of the `sunset_callback()` callback.
      |'sunset_daytime_callback()'| and |'sunset_nighttime_callback()'| are
      unaffected.

1.2.1 (Thu Nov 22, 2012) ~

    - Fix table of contents numbering in documentation.

1.2.0 (Mon Nov 5, 2012) ~

    - |GetLatestVimScripts|-compatible.
    - New behaviour with |'sunset_daytime_callback()'|
      and |'sunset_nighttime_callback()'|.
    - `sunset_callback()` has been deprecated and will be removed in the next
      release.

1.1.0 (Sun Oct 28, 2012) ~

    - Added `sunset_callback()`.
        Courtesy of GitHub user ‘delphinus35’
        (https://github.com/amdt/sunset/pull/1)

1.0.3 (Sat Oct 20, 2012) ~

    - Improved requirements checking.
    - Rewrote documentation.

1.0.1 & 1.0.2 (Thu Oct 18, 2012) ~

    - Corrected typos in documentation.

1.0.0 (Thu Oct 18, 2012) ~

    - Initial release.

KNOWN ISSUES                                           *sunset-known-issues*

For known issues (and to report your own), please see the issue tracker on
GitHub: https://github.com/amdt/sunset/issues

LICENSE                                                     *sunset-license*

Sunset is distributed under the same terms as Vim itself. See |license|
for details.

CREDITS                                                     *sunset-credits*

Sunset uses an algorithm for finding the local sunrise and sunset times
published in the Almanac for Computers, 1990, by the Nautical Almanac Office
of the United States Naval Observatory, as
detailed here: http://williams.best.vwh.net/sunrise_sunset_algorithm.htm

Special thanks: ~

    * Gueorgui Tcherednitchenko --- Whose tweet
      (http://twitter.com/gueorgui/statuses/250765514975113216)
      inspired the development of this plugin.
    * Nick Rogers --- Whose testing helped define Sunset’s requirements.

                                    * * *

vim:tw=78:ft=help:norl:
