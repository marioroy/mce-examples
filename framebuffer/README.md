
### Parallel Graphics::Framebuffer demonstrations

Copy the MCE demonstrations to the [Graphics::Framebuffer](https://metacpan.org/pod/Graphics::Framebuffer) examples folder and run from there.

```
 mcechnl_primitives.pl  - based on threaded_primitives.pl [1]
 mcehobo_primitives.pl  - based on threaded_primitives.pl [1]
 mcehobo_slideshow.pl   - based on threaded_slidshow.pl   [2]
```

### How to enable the framebuffer on CentOS 7.

The Graphics::Framebuffer module requires the framebuffer to work.
This is how I enabled the framebuffer inside a CentOS 7 virtual machine.

```
 Perform steps as root:

 1. systemctl set-default multi-user.target

 2. append vga=0x317 to GRUB_CMDLINE_LINUX line in /etc/default/grub.conf

 3. grub2-mkconfig -o /boot/grub2/grub.cfg

 4. add the user to the 'video' group in /etc/group

    video:x:39:mario

 5. reboot

 Perform as user:

 6. id

    uid=1000(mario) gid=1000(mario) groups=1000(mario),39(video)

    ensure in video group (if not yet rebooted, log out and back in)
```

### References

1. ** Richard Kelsch.
   https://metacpan.org/pod/Graphics::Framebuffer v6.32
   examples dir: threaded_primitives.pl

2. ** Richard Kelsch.
   https://metacpan.org/pod/Graphics::Framebuffer v6.32
   examples dir: threaded_slideshow.pl

