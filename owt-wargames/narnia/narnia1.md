# narnia1

Ok so this was already interesting, because if we do not pay enough attention to the specifics of the systems *and* of the executables, we may loose a lot of time trying the wrong solutions.
Again, I will try to not give you the solution immediatly, just walk towards it step by step with a logical method to analyze the situation.

## Execute the software
Again, I would always recommend to try the executable before looking at the code. In this case, the executable prints the following sentence:
`Give me something to execute at the env-variable EGG`
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
- We are assigning something directly to `ret`: remember that this is a *pointer* to something, so to match our types, we need the `getenv()` function to give us a pointer... and it does! The documentation states that _"t finds a match by the name we provided. If it finds a match, it returns a pointer to the C string that contains the value of that environment variable."_. Ok nice, so we get a pointer back, to a C string containing the real content of the env-var. Nice, we have our type match.
We then call the `ret()` function. Since this is a pointer to a function, we can do this and the compiler is happy about it because we told him that `ret` would be a function, so the `()` operator will do its job.
- Ok but... how do we set something (useful to us, I would say) to the EGG variable? This is some Linux basics stuff, let's look at it!

## Environment Variables
In Linux we have this variables which are part of our... environment, yes lol
They are usually uppercase words that contains some values (numbers, strings, etc...) and that the OS uses to perform actions of different types. For example, try to execute `echo $HOME`, you would see that it displays the path to your home folder. The `HOME` env-var is something that is attached to our user environment, so it is accessible anytime, anywhere.
But the environment can also be our terminal session! Let's try this command `export EGG=boiled`... no output mmm... ok let's print it now `echo $EGG`... It's boiled!
Now try closing the terminal and starting one again, and print the EGG variable... Who stole our egg?!
This means that we can set our env-vars whit the `export` command and we can safely forget them when we close our terminal. If you want to know more, [here](https://wiki.archlinux.org/title/Environment_variables) could be a good place to look.

## What should be in our EGG?

