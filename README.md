# emocchi

A Discord bot that posts images you register to it as an alternative to custom server emoji for those who don't want to pay

## How it works

This bot is a tiny side project I hacked together in a few hours.  Bear that in mind as you read on.

The bot uses the [discord.py](https://discordpy.readthedocs.io/en/stable/index.html) library to talk to Discord.
It handles a few simple commands that let you:

1. Register a "macro"
2. Delete a macro
3. List registered macros

A "macro" is a special keyword that the bot will recognize. When it sees a "macro invokation" in a message, it will
reply with that image.

Example:

```
You: !reg cute-wink https://somewebsite.com/images/cute-wink.jpg

You: Hey, friends! >cute-wink<

Bot: [posts the cute-wink.jpg image]

*later*

You: !del cute-wink

Bot: [removes the cute-wink macro and image]
```

It's that simple.  As you can see, the syntax to invoke a macro is `>[macro name]<`.

The bot also has a certain... ahem... bent... to it.  This is for, uh, flavour. Yes. Flavour!

At any rate, when you register a macro, you give it the name of the macro you want to reference in the future
and a link to an image to reply to that macro with.  The bot downloads the image to an `images/` directory and stores
a mapping from `cute-wink -> images/cute-wink.jpg` in a dictionary.  It saves this dictionary to `macros.json` every
time you make a change.

## Running

### Prerequisites

This bot has a few external dependencies.  First, it runs with Python 3 and requires the `requests` and `discord`
libraries be installed.

```bash
pip3 install -U requests discord
```

### Go~!

Once you have [created a Discord bot](https://discordpy.readthedocs.io/en/stable/discord.html),
you will have the token you need to authenticate the bot to Discord.  This token is provided
to the running code via an environment variable.

```bash
BOT_KEY="<your key>" python3 emocchi.py
```
