
### Parallel Graphics::Framebuffer demonstrations

Copy the MCE demonstrations to the [Graphics::Framebuffer](https://metacpan.org/pod/Graphics::Framebuffer) examples/multiprocessing folder and run from there.

```
 many_boxes.pl          - Draw many boxes using MCE::Hobo
 many_ellipses.pl       - Draw many ellipses using threads
 many_lines             - Draw many lines using MCE::Child
 mcechnl_primitives.pl  - Based on threaded_primitives.pl [1]
 mcehobo_primitives.pl  - Based on threaded_primitives.pl [1]
 mcehobo_slideshow.pl   - Based on threaded_slidshow.pl   [2]
```

### How to enable the Framebuffer in CentOS 7 and Ubuntu 18.04

The Graphics::Framebuffer module requires the framebuffer to work.
This may work for later versions (ie. CentOS 8), but not tested.

```
 Perform the following steps as root.

 1. Disable GUI (X server) when booting.
    systemctl set-default multi-user.target

 2. Add the user to the 'video' group in /etc/group.
    usermod -aG video YOUR_USERNAME

 3. Increase the resolution of the Framebuffer.

    CentOS
    a. append vga=0x317 to GRUB_CMDLINE_LINUX in /etc/default/grub
       note: must enter as hex-value

    b. grub2-mkconfig -o /boot/grub2/grub.cfg
       note: mount /boot if not mounted

    Ubuntu
    a. append vga=791 to GRUB_CMDLINUX_LINUX_DEFAULT in /etc/default/grub

    b. update-grub

 4. Reboot.

 5. Log in as yourself and ensure member of the video group.
    $ id

    uid=1000(YOUR_USERNAME) ...,39(video),...
```

### Install compiler, git, essential libs and Perlbrew (https://perlbrew.pl)

In a nutshell, this installs a compiler, git and essential libraries needed
to build Perl and modules.

```
 CentOS (replace yum with dnf if missing yum)

 $ sudo yum install gcc gcc-c++ make autoconf automake bison byacc flex git
 $ sudo yum install giflib-devel libjpeg-turbo-devel libpng-devel libtiff-devel
 $ sudo yum install freetype-devel

 $ curl -L https://install.perlbrew.pl | bash

 Ubuntu

 $ sudo apt-get install build-essential git
 $ sudo apt-get install libgif-dev libjpeg-dev libpng-dev libtiff-dev
 $ sudo apt-get install libfreetype6-dev

 $ wget -O - https://install.perlbrew.pl | bash
```

Append the following line to the end of your ~/.bash_profile and start a
new shell or log out and back in.

```
 source ~/perl5/perlbrew/etc/bashrc
```

Install Perl and afterwards switch to it. This becomes your default Perl.

```
 $ perlbrew install -n perl-5.30.1 -Dusethreads
 $ perlbrew clean

 $ perlbrew switch perl-5.30.1
```

Install the cpanm standalone executable and use that to install modules.

```
 $ perlbrew install-cpanm

 $ cpanm -n Inline::C Math::Bezier Math::Gradient File::Map Imager
 $ cpanm -n MCE::Shared Sereal::Encoder Sereal::Decoder
 $ cpanm -n Graphics::Framebuffer Sys::CPU
```

You're all set to run the examples on the Framebuffer Console.

```
 $ perldoc many_boxes.pl
 $ perldoc many_ellipses.pl
 $ perldoc many_lines.pl

 $ perldoc mcechnl_primitives.pl
 $ perldoc mcehobo_primitives.pl
 $ perldoc mcehobo_screenshow.pl
```

### References

1. ** Richard Kelsch.
   https://metacpan.org/pod/Graphics::Framebuffer v6.43
   examples/multiprocessing/threaded_primitives.pl

2. ** Richard Kelsch.
   https://metacpan.org/pod/Graphics::Framebuffer v6.43
   examples/multiprocessing/threaded_slideshow.pl

