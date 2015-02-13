# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

/bin/sh -c "xrandr --output VGA1 --right-of DP2"
/bin/sh -c "feh --bg-fill /home/albert/Downloads/mandelbrot_fractal_by_dusanpavlicek-d41d9vv.jpg"
/bin/sh -c "/usr/bin/compton -b --config /home/albert/.i3/compton.conf"
