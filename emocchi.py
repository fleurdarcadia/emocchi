import json
import os
import shutil
import re

import discord
import requests

BOT_KEY = 'BOT_KEY' # env var

REGISTER_SYNTAX = '!reg'  # !reg <macro> <url>
REMOVE_SYNTAX = '!del'  # !del <macro>
LIST_SYNTAX = '!list'  # !list

MACRO_INVOKE = '>([\w_-]+)<' # >macro< or >some_convenient-macro<

IMAGES_PATH = './images'
MACROS_FILE = './macros.json'

class Emocchi(discord.Client):
    async def on_ready(self):
        self.MACRO_MAPPINGS = load_macros(MACROS_FILE)
        print(self.MACRO_MAPPINGS)
        print('READY, MASTER!')

    async def on_message(self, message):
        if message.content.startswith(REGISTER_SYNTAX):
            parts = [part for part in message.content.split(' ') if len(part) > 0]
            _, macro, url = parts[0:3]  # ["!reg", "<macro>", "<url>"]

            if macro in self.MACRO_MAPPINGS:
                await message.channel.send(f"It looks like there's already a {macro} macro, Master!! ><")
                return

            path = download_image(IMAGES_PATH, macro, url)
            if path is None:
                await message.channel.send(
                    "I'm sorry, Master... That doesn't look like an image file :pleading_face:",
                )
                return

            self.MACRO_MAPPINGS[macro] = path
            save_macros(MACROS_FILE, self.MACRO_MAPPINGS)

            await message.channel.send(f'I created the new {macro} macro just for you, Master~ <3')
            return

        if message.content.startswith(LIST_SYNTAX):
            macros_list = [f'  * {macro}' for macro in self.MACRO_MAPPINGS.keys()]
            response = 'Here are the macros I can serve you, Master:\n' + '\n'.join(macros_list)

            await message.channel.send(response)
            return

        if message.content.startswith(REMOVE_SYNTAX):
            parts = [part for part in message.content.split(' ') if len(part) > 0]
            _, macro = parts[0:2]  # ["!del", "<macro>"]

            if delete_macro(macro, self.MACRO_MAPPINGS):
                save_macros(MACROS_FILE, self.MACRO_MAPPINGS)
                await message.channel.send(f'As you command, Master! The {macro} is no more! ;)')
            else:
                await message.channel.send(f"I'm sorry, Master! I don't recognize a {macro} macro! D:")
            return

        match = re.search(MACRO_INVOKE, message.content)
        if match is not None:
            macro = match.group(1)
            if macro in self.MACRO_MAPPINGS:
                with open(self.MACRO_MAPPINGS[macro], 'rb') as image:
                    f = discord.File(image)
                    await message.channel.send('', file=f)


def download_image(path, name, url):
    image_data = requests.get(url).content

    tmp = f'{path}/{name}'
    with open(tmp, 'wb') as handler:
        handler.write(image_data)

    ext = imghdr.what(tmp)
    if ext is None:
        os.remove(tmp)
        return None

    actual = f'{path}/{name}.{ext}'
    shutil.move(tmp, actual)

    return actual


def load_macros(path):
    try:
        with open(path) as macros_file:
            return json.load(macros_file)
    except:
        return {}


def save_macros(path, macros_dict):
    with open(path, 'w') as macros_file:
        json.dump(macros_dict, macros_file)


def delete_macro(name, macros):
    if name not in macros:
        return False

    path = macros[name]
    try:
        os.remove(path)
        del macros[name]
    except:
        return False
    return True

if __name__ == '__main__':
    try:
        client = Emocchi()
        client.run(os.environ[BOT_KEY])
    except KeyboardInterrupt:
        print('\nSaving macros')
        print('\nExiting.')
